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

# t.uuid :id, primary_key: true
# t.string :name, null: false, index: { unique: true }
# t.json :actions, null: false
# t.json :concurrency
# t.json :context_schema
class Bemi::WorkflowDefinition < Bemi::ApplicationRecord
  self.table_name = 'bemi_workflow_definitions'

  def actions
    self[:actions].deep_symbolize_keys
  end

  def concurrency
    self[:concurrency].deep_symbolize_keys
  end

  def context_schema
    self[:context_schema].deep_symbolize_keys
  end
end

# t.uuid :id, primary_key: true
# t.string :name, null: false, index: true
# t.json :definition, null: false
# t.string :status
# t.json :context
# t.timestamp :started_at
# t.timestamp :finished_at
class Bemi::WorkflowInstance < Bemi::ApplicationRecord
  self.table_name = 'bemi_workflow_instances'

  def definition
    self[:definition].deep_symbolize_keys
  end

  def context
    self[:context].deep_symbolize_keys
  end
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
