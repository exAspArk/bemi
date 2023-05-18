# frozen_string_literal: true

require 'forwardable'

class Bemi::Storage
  WorkflowNotFound = Class.new(StandardError)

  ADAPTER_BY_NAME = {
    memory: Bemi::Adapters::Memory,
    # active_record: Bemi::Adapters::ActiveRecord,
  }.freeze

  class << self
    def upsert_workflow_definitions!(workflow_definitions)
      adapter.upsert_workflow_definitions!(workflow_definitions)
    end

    def find_workflow_definition!(workflow_name)
      workflow_definition = adapter.find_workflow_definition!(workflow_name)
      raise Bemi::Storage::WorkflowNotFound, workflow_name if !workflow_definition

      workflow_definition
    end

    private

    def adapter
      @adapter ||= ADAPTER_BY_NAME[Bemi::Config.configuration[:storage]]
    end
  end
end
