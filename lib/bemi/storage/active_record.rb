# frozen_string_literal: true

require 'securerandom'
require 'active_record'

class Bemi::ApplicationRecord < Bemi::Config.configuration.fetch(:storage_parent_class).constantize
  self.abstract_class = true
  after_initialize :generate_uuid

  private

  def generate_uuid
    self.id = SecureRandom.uuid if id.nil?
  end
end

class Bemi::WorkflowDefinition < Bemi::ApplicationRecord
  self.table_name = 'bemi_workflow_definitions'
end

class Bemi::WorkflowInstance < Bemi::ApplicationRecord
  self.table_name = 'bemi_workflow_instances'
end

class Bemi::Storage::ActiveRecord
  class << self
    def upsert_workflow_definitions!(workflow_definitions)
      Bemi::WorkflowDefinition.upsert_all(
        workflow_definitions.map { |w| w.merge(id: SecureRandom.uuid) },
        unique_by: :name,
      )
    end

    def find_workflow_definition!(workflow_name)
      Bemi::WorkflowDefinition.find_by!(name: workflow_name.to_s)
    end

    def create_workflow!(workflow_definition, context)
      workflow = Bemi::WorkflowInstance.create!(
        name: workflow_definition.name,
        definition: workflow_definition.attributes,
        status: :pending,
        context: context,
      )

      workflow
    end
  end
end
