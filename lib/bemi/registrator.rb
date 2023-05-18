# frozen_string_literal: true

class Bemi::Registrator
  DuplicateWorkflowNameError = Class.new(StandardError)

  class << self
    def add_workflow(workflow_name, workflow_class)
      @workflow_class_by_name ||= {}

      validate_workflow_name_uniqueness!(workflow_name)
      @workflow_class_by_name[workflow_name] = workflow_class
    end

    def sync_workflows!(files)
      files.each { |file| require "./#{file}" }

      workflow_definitions = @workflow_class_by_name.map do |workflow_name, workflow_class|
        {
          name: workflow_name.to_s,
          actions: workflow_class.actions,
          concurrency: workflow_class.concurrency_options,
        }
      end

      Bemi::Storage.adapter.upsert_workflow_definitions!(workflow_definitions)
      workflow_definitions
    end

    private

    def validate_workflow_name_uniqueness!(workflow_name)
      return if !@workflow_class_by_name[workflow_name]

      raise Bemi::Registrator::DuplicateWorkflowNameError, "Workflow '#{workflow_name}' is already registered"
    end
  end
end
