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

  def deep_symbolize_attribute_keys(attribute)
    if self[attribute].is_a?(Hash)
      self[attribute].deep_symbolize_keys
    elsif self[attribute].is_a?(Array)
      self[attribute].map(&:deep_symbolize_keys)
    else
      self[attribute]
    end
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
    deep_symbolize_attribute_keys(:actions)
  end

  def concurrency
    deep_symbolize_attribute_keys(:concurrency)
  end

  def context_schema
    deep_symbolize_attribute_keys(:context_schema)
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

  STATUS_PENDING = 'pending'
  STATUS_RUNNING = 'running'
  STATUS_COMPLETED = 'completed'
  STATUS_FAILED = 'failed'
  STATUS_TIMED_OUT = 'timed_out'
  STATUS_CANCELED = 'canceled'

  after_initialize :set_default_status

  def pending?
    status == STATUS_PENDING
  end

  def definition
    deep_symbolize_attribute_keys(:definition)
  end

  def context
    deep_symbolize_attribute_keys(:context)
  end

  private

  def set_default_status
    self.status = STATUS_PENDING if status.nil?
  end
end

# t.uuid :id, primary_key: true
# t.string :name, null: false, index: true
# t.string :status, null: false, index: true
# t.uuid :workflow_instance_id, null: false, index: true
# t.uuid :retry_action_instance_id, index: true
# t.integer :retry_count, null: false, default: 0
# t.json :input
# t.json :output
# t.json :context
# t.json :custom_errors
# t.text :logs
# t.string :concurrency_key, index: true
# t.timestamp :run_at
# t.timestamp :started_at
# t.timestamp :finished_at
class Bemi::ActionInstance < Bemi::ApplicationRecord
  self.table_name = 'bemi_action_instances'

  STATUS_PENDING = 'pending'
  STATUS_RUNNING = 'running'
  STATUS_COMPLETED = 'completed'
  STATUS_FAILED = 'failed'
  STATUS_TIMED_OUT = 'timed_out'
  STATUS_CANCELED = 'canceled'

  belongs_to :workflow, class_name: 'Bemi::WorkflowInstance', foreign_key: :workflow_instance_id

  after_initialize :set_default_status

  def input
    deep_symbolize_attribute_keys(:input)
  end

  def output
    deep_symbolize_attribute_keys(:output)
  end

  def context
    deep_symbolize_attribute_keys(:context)
  end

  def custom_errors
    deep_symbolize_attribute_keys(:custom_errors)
  end

  private

  def set_default_status
    self.status = STATUS_PENDING if status.nil?
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
      Bemi::WorkflowInstance.create!(
        name: workflow_definition.name,
        definition: workflow_definition.attributes,
        status: :pending,
        context: context,
      )
    end

    def find_workflow!(id)
      Bemi::WorkflowInstance.find(id)
    end

    def create_action!(action_name, workflow, input)
      Bemi::ActionInstance.create!(
        name: action_name,
        status: :pending,
        workflow_instance_id: workflow.id,
        input: input,
      )
    end

    def start_action!(action)
      action.update!(status: Bemi::ActionInstance::STATUS_RUNNING, started_at: Time.current)
      action.workflow.update!(status: Bemi::WorkflowInstance::STATUS_RUNNING) if action.workflow.pending?
    end

    def complete_action!(action, context:, output:)
      action.update!(
        status: Bemi::ActionInstance::STATUS_COMPLETED,
        finished_at: Time.current,
        context: context,
        output: output,
      )
    end

    def fail_action!(action, context:, custom_errors:, logs:)
      action.update!(
        status: Bemi::ActionInstance::STATUS_FAILED,
        finished_at: Time.current,
        custom_errors: custom_errors,
        context: context,
        logs: logs,
      )
    end

    def transaction(&block)
      Bemi::ApplicationRecord.transaction(&block)
    end
  end
end
