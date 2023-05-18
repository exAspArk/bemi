# frozen_string_literal: true

class Bemi::Runner
  InvalidContext = Class.new(StandardError)
  InvalidInput = Class.new(StandardError)
  InvalidOutput = Class.new(StandardError)

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
      action_instance = Bemi::Storage.create_action!(action_name, workflow, input)
      action = action_class.new(workflow: workflow, input: input)

      begin
        action_instance.update!(status: Bemi::ActionInstance::STATUS_RUNNING, started_at: Time.current)

        action.perform_with_callbacks

        validate!(action.context, action_class.context_schema, InvalidContext)
        validate!(action.output, action_class.output_schema, InvalidOutput)
        action_instance.update!(
          status: Bemi::ActionInstance::STATUS_COMPLETED,
          finished_at: Time.current,
          context: action.context,
          output: action.output,
        )
      rescue StandardError => e
        action_instance.update!(
          status: Bemi::ActionInstance::STATUS_FAILED,
          finished_at: Time.current,
          context: action.context,
          logs: "#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}",
          rollback_output: action.rollback_output,
        )
        raise e
      end
    end

    private

    def validate!(values, schema, error_class)
      return if !values || !schema

      errors = Bemi::Validator.validate(values, schema)
      raise error_class, errors.first if errors.any?
    end
  end
end
