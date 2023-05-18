# frozen_string_literal: true

class Bemi::Registrator
  DuplicateWorkflowNameError = Class.new(StandardError)

  class << self
    def sync_workflows!(files)
      files.each { |file| require "./#{file}" }
      workflow_definitions = @workflow_class_by_name.values.map(&:definition)
      Bemi::Storage.upsert_workflow_definitions!(workflow_definitions)
      workflow_definitions
    end

    def add_workflow(workflow_name, workflow_class)
      @workflow_class_by_name ||= {}

      validate_workflow_name_uniqueness!(workflow_name)
      @workflow_class_by_name[workflow_name] = workflow_class
    end

    private

    def validate_workflow_name_uniqueness!(workflow_name)
      return if !@workflow_class_by_name[workflow_name]

      raise Bemi::Registrator::DuplicateWorkflowNameError, "Workflow '#{workflow_name}' is already registered"
    end
  end
end
