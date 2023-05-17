# frozen_string_literal: true

Bemi::DuplicateWorkflowNameError = Class.new(StandardError)

class Bemi::Registrator
  class << self
    def add_workflow(workflow_name, workflow_class)
      @workflow_class_by_name ||= {}

      if @workflow_class_by_name[workflow_name]
        raise Bemi::DuplicateWorkflowNameError, "Workflow '#{workflow_name}' is already registered"
      end

      @workflow_class_by_name[workflow_name] = workflow_class
    end

    def sync_workflows!(file_pattern)
      Dir.glob(file_pattern).each { |file| require "./#{file}" }

      workflow_definitions = @workflow_class_by_name.map do |workflow_name, workflow_class|
        {
          name: workflow_name.to_s,
          actions: workflow_class.actions,
        }
      end

      Bemi::Storage.adapter.upsert_workflow_definitions!(workflow_definitions)

      workflow_definitions
    end
  end
end
