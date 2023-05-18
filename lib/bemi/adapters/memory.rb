# frozen_string_literal: true

class Bemi::Adapters::Memory < Bemi::Adapters::Abstract
  class << self
    def upsert_workflow_definitions!(workflow_definitions)
      @workflow_definitions ||= {}

      workflow_definitions.each do |workflow_definition|
        @workflow_definitions[workflow_definition[:name]] = workflow_definition
      end
    end

    def find_workflow_definition!(workflow_name)
      @workflow_definitions[workflow_name.to_s]
    end
  end
end
