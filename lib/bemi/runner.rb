# frozen_string_literal: true

require 'digest'

class Bemi::Runner
  InvalidContext = Class.new(StandardError)
  InvalidInput = Class.new(StandardError)
  InvalidOutput = Class.new(StandardError)
  InvalidCustomErrors = Class.new(StandardError)
  WaitingForActionError = Class.new(StandardError)
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

    def perform_action(action_name, workflow_id:, input:)
      action_class = Bemi::Registrator.find_action_class!(action_name)
      validate!(input, action_class.input_schema, InvalidInput)
      workflow = Bemi::Storage.find_workflow!(workflow_id)
      wait_for_action_names = action_need_to_wait_for(workflow, action_name)
      action = action_class.new(workflow: workflow, input: input)

      if wait_for_action_names.any?
        raise WaitingForActionError, "Waiting for actions: #{wait_for_action_names.map { |n| "'#{n}'" }.join(', ')}"
      end

      action_definition = workflow.definition.fetch(:actions).find { |a| a.fetch(:name) == action_name.to_s }
      concurrency_key = concurrency_key_hash(action.concurrency_key)
      concurrency_action = concurrency_action(action_definition, concurrency_key)
      if concurrency_action == Bemi::Action::ON_CONFLICT_RESCHEDULE
        Bemi::Storage.start_workflow!(workflow) if !workflow.running?
        return
      end

      action_instance = nil
      Bemi::Storage.transaction do
        action_instance = Bemi::Storage.create_action!(action_name, workflow_id: workflow.id, input: input, concurrency_key: concurrency_key)
        Bemi::Storage.start_action!(action_instance)
        Bemi::Storage.start_workflow!(workflow) if !workflow.running?
      end

      perform_action_with_validations!(action, action_instance)
    end

    def perform_created_action(action_id)
      action_instance = Bemi::Storage.find_action!(action_id)
      workflow = action_instance.workflow
      action_class = Bemi::Registrator.find_action_class!(action_instance.name)
      action = action_class.new(workflow: workflow)

      Bemi::Storage.transaction do
        Bemi::Storage.start_action!(action_instance)
        Bemi::Storage.start_workflow!(workflow) if !workflow.running?
      end

      perform_action_with_validations!(action, action_instance)
    end

    def workflow_completed_all_actions?(workflow)
      Bemi::Storage.incomplete_action_names(workflow.definition.fetch(:actions).map { |a| a.fetch(:name) }, workflow.id).empty?
    end

    def action_need_to_wait_for(workflow, action_name)
      wait_for_action_names = action_definition(workflow, action_name).fetch(:wait_for)
      return [] if wait_for_action_names.nil?

      Bemi::Storage.incomplete_action_names(wait_for_action_names, workflow.id)
    end

    def action_can_retry?(action_instance)
      retry_count = action_definition(action_instance.workflow, action_instance.name).fetch(:on_error)&.fetch(:retry) || 0
      retry_count > action_instance.retry_count
    end

    def concurrency_key_hash(value)
      Digest::SHA256.hexdigest(value.to_s)
    end

    def concurrency_action(action_definition, concurrency_key)
      limit = action_definition.dig(:concurrency, :limit)
      return if !limit || limit > Bemi::Storage.not_finished_action_count(concurrency_key)

      action_definition.fetch(:concurrency).fetch(:on_conflict)
    end

    private

    def perform_action_with_validations!(action, action_instance, input: nil)
      workflow = action.workflow
      action_class = action.class
      action.perform_with_around_wrappers
      validate!(action.context, action_class.context_schema, InvalidContext)
      validate!(action.output, action_class.output_schema, InvalidOutput)
      Bemi::Storage.transaction do
        Bemi::Storage.complete_action!(action_instance, context: action.context, output: action.output)
        Bemi::Storage.update_workflow_context!(workflow, context: action.workflow.context)
        Bemi::Storage.complete_workflow!(workflow) if workflow_completed_all_actions?(workflow)
      end
      action.output
    rescue StandardError => perform_error
      rollback_action(action_instance, action, perform_error)
      validate!(action.context, action_class.context_schema, InvalidContext)
      validate!(action.custom_errors, action_class.custom_errors_schema, InvalidCustomErrors)
      raise perform_error
    end

    def action_definition(workflow, action_name)
      workflow.definition.fetch(:actions).find { |a| a.fetch(:name) == action_name.to_s }
    end

    def rollback_action(action_instance, action, perform_error)
      perform_logs = "#{perform_error.class}: #{perform_error.message}\n#{perform_error.backtrace.join("\n")}"
      action.rollback_with_around_wrappers
      Bemi::Storage.transaction do
        Bemi::Storage.fail_workflow!(action_instance.workflow) if !action_can_retry?(action_instance)
        Bemi::Storage.update_workflow_context!(action.workflow, context: action.workflow.context)
        Bemi::Storage.fail_action!(action_instance, context: action.context, custom_errors: action.custom_errors, logs: perform_logs)
      end
    rescue StandardError => e
      rollback_logs = "#{perform_logs}\n\n#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
      Bemi::Storage.transaction do
        Bemi::Storage.fail_workflow!(action_instance.workflow) if !action_can_retry?(action_instance)
        Bemi::Storage.update_workflow_context!(action_instance.workflow, context: action.workflow.context)
        Bemi::Storage.fail_action!(action_instance, context: action.context, custom_errors: action.custom_errors, logs: rollback_logs)
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
