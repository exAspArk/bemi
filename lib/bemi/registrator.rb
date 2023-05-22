# frozen_string_literal: true

class Bemi::Registrator
  DuplicateWorkflowNameError = Class.new(StandardError)
  DuplicateActionNameError = Class.new(StandardError)
  NoActionFoundError = Class.new(StandardError)

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

    def add_action(action_name, action_class)
      @action_class_by_name ||= {}

      validate_action_name_uniqueness!(action_name)
      @action_class_by_name[action_name.to_s] = action_class
    end

    def find_action_class!(action_name)
      action_class = @action_class_by_name[action_name.to_s]
      raise NoActionFoundError, "Action '#{action_name}' is not found" if !action_class

      action_class
    end

    private

    def validate_workflow_name_uniqueness!(workflow_name)
      return if !@workflow_class_by_name[workflow_name]

      raise Bemi::Registrator::DuplicateWorkflowNameError, "Workflow '#{workflow_name}' is already registered"
    end

    def validate_action_name_uniqueness!(action_name)
      return if !@action_class_by_name[action_name.to_s]

      raise Bemi::Registrator::DuplicateActionNameError, "Action '#{action_name}' is already registered"
    end
  end
end
