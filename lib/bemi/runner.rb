# frozen_string_literal: true

require 'digest'

class Bemi::Runner
  InvalidContext = Class.new(StandardError)
  InvalidInput = Class.new(StandardError)
  InvalidOutput = Class.new(StandardError)
  InvalidCustomErrors = Class.new(StandardError)
  WaitingForStepError = Class.new(StandardError)
  ConcurrencyError = Class.new(StandardError)

  class << self
    def perform_workflow(workflow_name, context:)
      workflow_definition = Bemi::Storage.find_workflow_definition!(workflow_name)
      validate!(context, workflow_definition.context_schema, InvalidContext)
      concurrency_key = concurrency_key_hash("#{workflow_name}-#{context.to_json}")

      limit = workflow_definition.concurrency&.fetch(:limit)
      if limit && limit <= Bemi::Storage.not_finished_workflow_count(concurrency_key)
        if workflow_definition.concurrency.fetch(:on_conflict) == Bemi::Workflow::ON_CONFLICT_RAISE
          raise ConcurrencyError, "Cannot run more than #{limit} '#{workflow_name}' workflows at a time"
        end
        return nil
      end

      Bemi::Storage.create_workflow!(workflow_definition, context: context, concurrency_key: concurrency_key)
    end

    def perform_step(step_name, workflow_id:, input:)
      step_class = Bemi::Registrator.find_step_class!(step_name)
      validate!(input, step_class.input_schema, InvalidInput)
      workflow = Bemi::Storage.find_workflow!(workflow_id)
      wait_for_step_names = step_need_to_wait_for(workflow, step_name)
      step = step_class.new(workflow: workflow, input: input)

      if wait_for_step_names.any?
        raise WaitingForStepError, "Waiting for steps: #{wait_for_step_names.map { |n| "'#{n}'" }.join(', ')}"
      end

      step_definition = workflow.definition.fetch(:steps).find { |a| a.fetch(:name) == step_name.to_s }
      concurrency_key = concurrency_key_hash(step.concurrency_key)
      concurrency_step = concurrency_step(step_definition, concurrency_key)
      if concurrency_step == Bemi::Step::ON_CONFLICT_RESCHEDULE
        Bemi::Storage.start_workflow!(workflow) if !workflow.running?
        return
      end

      step_instance = nil
      Bemi::Storage.transaction do
        step_instance = Bemi::Storage.create_step!(step_name, workflow_id: workflow.id, input: input, concurrency_key: concurrency_key)
        Bemi::Storage.start_step!(step_instance)
        Bemi::Storage.start_workflow!(workflow) if !workflow.running?
      end

      perform_step_with_validations!(step, step_instance)
    end

    def perform_created_step(step_id)
      step_instance = Bemi::Storage.find_step!(step_id)
      workflow = step_instance.workflow
      step_class = Bemi::Registrator.find_step_class!(step_instance.name)
      step = step_class.new(workflow: workflow)

      Bemi::Storage.transaction do
        Bemi::Storage.start_step!(step_instance)
        Bemi::Storage.start_workflow!(workflow) if !workflow.running?
      end

      perform_step_with_validations!(step, step_instance)
    end

    def workflow_completed_all_steps?(workflow)
      Bemi::Storage.incomplete_step_names(workflow.definition.fetch(:steps).map { |a| a.fetch(:name) }, workflow.id).empty?
    end

    def step_need_to_wait_for(workflow, step_name)
      wait_for_step_names = step_definition(workflow, step_name).fetch(:wait_for)
      return [] if wait_for_step_names.nil?

      Bemi::Storage.incomplete_step_names(wait_for_step_names, workflow.id)
    end

    def step_can_retry?(step_instance)
      retry_count = step_definition(step_instance.workflow, step_instance.name).fetch(:on_error)&.fetch(:retry) || 0
      retry_count > step_instance.retry_count
    end

    def concurrency_key_hash(value)
      Digest::SHA256.hexdigest(value.to_s)
    end

    def concurrency_step(step_definition, concurrency_key)
      limit = step_definition.dig(:concurrency, :limit)
      return if !limit || limit > Bemi::Storage.not_finished_step_count(concurrency_key)

      step_definition.fetch(:concurrency).fetch(:on_conflict)
    end

    private

    def perform_step_with_validations!(step, step_instance, input: nil)
      workflow = step.workflow
      step_class = step.class
      step.perform_with_around_wrappers
      validate!(step.context, step_class.context_schema, InvalidContext)
      validate!(step.output, step_class.output_schema, InvalidOutput)
      Bemi::Storage.transaction do
        Bemi::Storage.complete_step!(step_instance, context: step.context, output: step.output)
        Bemi::Storage.update_workflow_context!(workflow, context: step.workflow.context)
        Bemi::Storage.complete_workflow!(workflow) if workflow_completed_all_steps?(workflow)
      end
      step.output
    rescue StandardError => perform_error
      rollback_step(step_instance, step, perform_error)
      validate!(step.context, step_class.context_schema, InvalidContext)
      validate!(step.custom_errors, step_class.custom_errors_schema, InvalidCustomErrors)
      raise perform_error
    end

    def step_definition(workflow, step_name)
      workflow.definition.fetch(:steps).find { |a| a.fetch(:name) == step_name.to_s }
    end

    def rollback_step(step_instance, step, perform_error)
      perform_logs = "#{perform_error.class}: #{perform_error.message}\n#{perform_error.backtrace.join("\n")}"
      step.rollback_with_around_wrappers
      Bemi::Storage.transaction do
        Bemi::Storage.fail_workflow!(step_instance.workflow) if !step_can_retry?(step_instance)
        Bemi::Storage.update_workflow_context!(step.workflow, context: step.workflow.context)
        Bemi::Storage.fail_step!(step_instance, context: step.context, custom_errors: step.custom_errors, logs: perform_logs)
      end
    rescue StandardError => e
      rollback_logs = "#{perform_logs}\n\n#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
      Bemi::Storage.transaction do
        Bemi::Storage.fail_workflow!(step_instance.workflow) if !step_can_retry?(step_instance)
        Bemi::Storage.update_workflow_context!(step_instance.workflow, context: step.workflow.context)
        Bemi::Storage.fail_step!(step_instance, context: step.context, custom_errors: step.custom_errors, logs: rollback_logs)
      end
      raise e
    end

    def validate!(values, schema, error_class)
      return if !values || !schema

      errors = Bemi::Validator.validate(values, schema)
      raise error_class, errors.first if errors.any?
    end
  end
end
