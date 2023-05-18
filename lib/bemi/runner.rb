# frozen_string_literal: true

class Bemi::Runner
  InvalidContext = Class.new(StandardError)

  class << self
    def perform_workflow(workflow_name, context:)
      workflow_definition = Bemi::Storage.find_workflow_definition!(workflow_name)
      validate_context!(workflow_definition, context)
    end

    private

    def validate_context!(workflow_definition, context)
      return if !workflow_definition[:context_schema]

      errors = Bemi::Validator.validate(context, workflow_definition[:context_schema])
      raise InvalidContext, errors.first if errors.any?
    end
  end
end
