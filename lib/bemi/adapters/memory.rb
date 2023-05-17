# frozen_string_literal: true

class Bemi::Adapters::Memory < Bemi::Adapters::Abstract
  class << self
    def upsert_workflow_definitions!(workflow_definitions)
      @workflow_definitions ||= {}

      workflow_definitions.each do |workflow_definition|
        @workflow_definitions[workflow_definition[:name]] = workflow_definition
      end
    end
  end
end
