# frozen_string_literal: true

module Bemi::Adapters
  class Abstract
    def upsert_workflow_definitions!(workflow_definitions)
      raise NotImplementedError
    end

    def find_workflow_definition!(workflow_name)
      raise NotImplementedError
    end
  end
end
