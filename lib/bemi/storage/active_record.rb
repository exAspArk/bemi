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
# t.string :state
# t.json :context
# t.string :concurrency_key, index: true
# t.timestamp :started_at
# t.timestamp :finished_at
class Bemi::WorkflowInstance < Bemi::ApplicationRecord
  self.table_name = 'bemi_workflow_instances'

  STATE_PENDING = 'pending'
  STATE_RUNNING = 'running'
  STATE_COMPLETED = 'completed'
  STATE_FAILED = 'failed'
  STATE_TIMED_OUT = 'timed_out'
  STATE_CANCELED = 'canceled'

  after_initialize :set_default_status

  def pending?
    state == STATE_PENDING
  end

  def definition
    deep_symbolize_attribute_keys(:definition)
  end

  def context
    deep_symbolize_attribute_keys(:context)
  end

  private

  def set_default_status
    self.state = STATE_PENDING if state.nil?
  end
end

# t.uuid :id, primary_key: true
# t.string :name, null: false, index: true
# t.string :state, null: false, index: true
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

  STATE_PENDING = 'pending'
  STATE_RUNNING = 'running'
  STATE_COMPLETED = 'completed'
  STATE_FAILED = 'failed'
  STATE_TIMED_OUT = 'timed_out'
  STATE_CANCELED = 'canceled'

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
    self.state = STATE_PENDING if state.nil?
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

    def create_workflow!(workflow_definition, context:, concurrency_key:)
      Bemi::WorkflowInstance.create!(
        name: workflow_definition.name,
        definition: workflow_definition.attributes,
        state: Bemi::WorkflowInstance::STATE_PENDING,
        context: context,
        concurrency_key: concurrency_key,
      )
    end

    def find_workflow!(id)
      Bemi::WorkflowInstance.find(id)
    end

    def not_finished_workflow_count(concurrency_key)
      Bemi::WorkflowInstance.where(
        concurrency_key: concurrency_key,
        state: [Bemi::WorkflowInstance::STATE_RUNNING, Bemi::WorkflowInstance::STATE_PENDING],
      ).count
    end

    def create_action!(action_name, workflow_id, input)
      Bemi::ActionInstance.create!(
        name: action_name,
        state: Bemi::ActionInstance::STATE_PENDING,
        workflow_instance_id: workflow_id,
        input: input,
      )
    end

    def start_action!(action)
      action.update!(state: Bemi::ActionInstance::STATE_RUNNING, started_at: Time.current)
      action.workflow.update!(state: Bemi::WorkflowInstance::STATE_RUNNING) if action.workflow.pending?
    end

    def complete_action!(action, context:, output:)
      action.update!(
        state: Bemi::ActionInstance::STATE_COMPLETED,
        finished_at: Time.current,
        context: context,
        output: output,
      )
    end

    def fail_action!(action, context:, custom_errors:, logs:)
      action.update!(
        state: Bemi::ActionInstance::STATE_FAILED,
        finished_at: Time.current,
        custom_errors: custom_errors,
        context: context,
        logs: logs,
      )
    end

    def incomplete_action_names(action_names, workflow_id)
      completed_action_names = Bemi::ActionInstance.where(name: action_names, workflow_instance_id: workflow_id, state: Bemi::ActionInstance::STATE_COMPLETED).pluck(:name)
      action_names - completed_action_names
    end

    def transaction(&block)
      Bemi::ApplicationRecord.transaction(&block)
    end
  end
end
