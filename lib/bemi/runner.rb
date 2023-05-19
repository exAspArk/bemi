# frozen_string_literal: true

class Bemi::Runner
  InvalidContext = Class.new(StandardError)
  InvalidInput = Class.new(StandardError)
  InvalidOutput = Class.new(StandardError)
  InvalidCustomErrors = Class.new(StandardError)
  WaitingForActionError = Class.new(StandardError)

  class << self
    def perform_workflow(workflow_name, context:)
      workflow_definition = Bemi::Storage.find_workflow_definition!(workflow_name)
      validate!(context, workflow_definition.context_schema, InvalidContext)

      Bemi::Storage.create_workflow!(workflow_definition, context)
    end

    def perform_action(action_name, workflow_id:, input:)
      action_class = Bemi::Registrator.find_action_class!(action_name)
      validate!(input, action_class.input_schema, InvalidInput)
      workflow = Bemi::Storage.find_workflow!(workflow_id)
      ensure_can_perform_action!(workflow, action_name)

      action_instance = nil
      Bemi::Storage.transaction do
        action_instance = Bemi::Storage.create_action!(action_name, workflow.id, input)
        Bemi::Storage.start_action!(action_instance)
      end

      begin
        action = action_class.new(workflow: workflow, input: input)
        action.perform_with_around_wrappers
        validate!(action.context, action_class.context_schema, InvalidContext)
        validate!(action.output, action_class.output_schema, InvalidOutput)
        Bemi::Storage.complete_action!(action_instance, context: action.context, output: action.output)
        action.output
      rescue StandardError => perform_error
        rollback_action(action_instance, action, perform_error)
        validate!(action.context, action_class.context_schema, InvalidContext)
        validate!(action.custom_errors, action_class.custom_errors_schema, InvalidCustomErrors)
        raise perform_error
      end
    end

    private

    def ensure_can_perform_action!(workflow, action_name)
      wait_for_action_names = workflow.definition.fetch(:actions).find { |a| a.fetch(:name) == action_name.to_s }[:wait_for]
      return if wait_for_action_names.nil?

      incomplete_action_names = Bemi::Storage.incomplete_action_names(wait_for_action_names, workflow.id)
      return if incomplete_action_names.empty?

      raise WaitingForActionError, "Waiting for actions: #{incomplete_action_names.map { |n| "'#{n}'" }.join(', ')}"
    end

    def rollback_action(action_instance, action, perform_error)
      perform_logs = "#{perform_error.class}: #{perform_error.message}\n#{perform_error.backtrace.join("\n")}"
      action.rollback_with_around_wrappers
      Bemi::Storage.fail_action!(
        action_instance,
        context: action.context,
        custom_errors: action.custom_errors,
        logs: perform_logs,
      )
    rescue StandardError => e
      Bemi::Storage.fail_action!(
        action_instance,
        context: action.context,
        custom_errors: action.custom_errors,
        logs: "#{perform_logs}\n\n#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}",
      )
      raise e
    end

    def validate!(values, schema, error_class)
      return if !values || !schema

      errors = Bemi::Validator.validate(values, schema)
      raise error_class, errors.first if errors.any?
    end
  end
end
