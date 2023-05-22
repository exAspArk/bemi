# frozen_string_literal: true

require 'securerandom'
require 'active_record'

class Bemi::ApplicationRecord < Bemi::Config.configuration.fetch(:storage_parent_class).constantize
  class CustomJsonSerializer
    class << self
      def dump(json)
        json
      end

      def load(json)
        if json.is_a?(Hash)
          json.deep_symbolize_keys
        elsif json.is_a?(Array)
          json.map(&:deep_symbolize_keys)
        else
          json
        end
      end
    end
  end

  self.abstract_class = true

  after_initialize :after_initialize_callback

  private

  def after_initialize_callback
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

  serialize :actions, CustomJsonSerializer
  serialize :concurrency, CustomJsonSerializer
  serialize :context_schema, CustomJsonSerializer
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
  STATE_CANCELED = 'canceled'

  serialize :definition, CustomJsonSerializer
  serialize :context, CustomJsonSerializer

  scope :not_finished, -> { where(state: [STATE_PENDING, STATE_RUNNING]) }

  def pending?
    state == STATE_PENDING
  end

  def running?
    state == STATE_RUNNING
  end

  def completed?
    state == STATE_COMPLETED
  end

  def failed?
    state == STATE_FAILED
  end

  def canceled?
    state == STATE_CANCELED
  end

  def finished?
    completed? || failed? || canceled?
  end

  private

  def after_initialize_callback
    super
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
  STATE_CANCELED = 'canceled'

  serialize :input, CustomJsonSerializer
  serialize :output, CustomJsonSerializer
  serialize :context, CustomJsonSerializer
  serialize :custom_errors, CustomJsonSerializer

  belongs_to :workflow, class_name: 'Bemi::WorkflowInstance', foreign_key: :workflow_instance_id
  belongs_to :retry_action, class_name: 'Bemi::ActionInstance', foreign_key: :retry_action_instance_id, optional: true

  def pending?
    state == STATE_PENDING
  end

  def running?
    state == STATE_RUNNING
  end

  def completed?
    state == STATE_COMPLETED
  end

  def failed?
    state == STATE_FAILED
  end

  def canceled?
    state == STATE_CANCELED
  end

  private

  def after_initialize_callback
    super
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

    def start_workflow!(workflow)
      workflow.update!(state: Bemi::WorkflowInstance::STATE_RUNNING, started_at: Time.current)
    end

    def fail_workflow!(workflow)
      workflow.update!(state: Bemi::WorkflowInstance::STATE_FAILED, finished_at: Time.current)
    end

    def complete_workflow!(workflow)
      workflow.update!(state: Bemi::WorkflowInstance::STATE_COMPLETED, finished_at: Time.current)
    end

    def find_workflow!(id)
      Bemi::WorkflowInstance.find(id)
    end

    def find_and_lock_workflow!(id)
      Bemi::WorkflowInstance.lock.find(id)
    end

    def update_workflow_context!(workflow, context:)
      workflow.update!(context: context)
    end

    def not_finished_workflow_ids
      Bemi::WorkflowInstance.not_finished.pluck(:id)
    end

    def not_finished_workflow_count(concurrency_key)
      Bemi::WorkflowInstance.not_finished.where(concurrency_key: concurrency_key).count
    end

    def find_action!(id)
      Bemi::ActionInstance.find(id)
    end

    def create_action!(action_name, workflow_id, input: nil, retry_count: 0)
      Bemi::ActionInstance.create!(
        name: action_name,
        state: Bemi::ActionInstance::STATE_PENDING,
        workflow_instance_id: workflow_id,
        input: input,
        retry_count: retry_count,
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

    def fail_action!(action, context:, custom_errors:, logs:, retry_action_id: nil)
      action.update!(
        state: Bemi::ActionInstance::STATE_FAILED,
        finished_at: Time.current,
        custom_errors: custom_errors,
        context: context,
        logs: logs,
        retry_action_instance_id: retry_action_id,
      )
    end

    def set_retry_action!(action, retry_action_id:)
      action.update!(retry_action_instance_id: retry_action_id)
    end

    def find_actions!(workflow_id)
      Bemi::ActionInstance.where(workflow_instance_id: workflow_id)
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
