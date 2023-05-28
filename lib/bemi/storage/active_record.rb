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
# t.json :steps, null: false
# t.json :concurrency
# t.json :context_schema
class Bemi::WorkflowDefinition < Bemi::ApplicationRecord
  self.table_name = 'bemi_workflow_definitions'

  serialize :steps, CustomJsonSerializer
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
# t.uuid :retry_step_instance_id, index: true
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
class Bemi::StepInstance < Bemi::ApplicationRecord
  self.table_name = 'bemi_step_instances'

  STATE_PENDING = 'pending'
  STATE_RUNNING = 'running'
  STATE_COMPLETED = 'completed'
  STATE_FAILED = 'failed'
  STATE_CANCELED = 'canceled'

  scope :not_finished, -> { where(state: [STATE_PENDING, STATE_RUNNING]) }

  serialize :input, CustomJsonSerializer
  serialize :output, CustomJsonSerializer
  serialize :context, CustomJsonSerializer
  serialize :custom_errors, CustomJsonSerializer

  belongs_to :workflow, class_name: 'Bemi::WorkflowInstance', foreign_key: :workflow_instance_id
  belongs_to :retry_step, class_name: 'Bemi::StepInstance', foreign_key: :retry_step_instance_id, optional: true

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
      return if workflow_definitions.blank?

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

    def find_step!(id)
      Bemi::StepInstance.find(id)
    end

    def create_step!(step_name, workflow_id:, input: nil, retry_count: 0, concurrency_key: nil)
      Bemi::StepInstance.create!(
        name: step_name,
        state: Bemi::StepInstance::STATE_PENDING,
        workflow_instance_id: workflow_id,
        input: input,
        retry_count: retry_count,
        concurrency_key: concurrency_key,
      )
    end

    def start_step!(step)
      step.update!(state: Bemi::StepInstance::STATE_RUNNING, started_at: Time.current)
      step.workflow.update!(state: Bemi::WorkflowInstance::STATE_RUNNING) if step.workflow.pending?
    end

    def complete_step!(step, context:, output:)
      step.update!(
        state: Bemi::StepInstance::STATE_COMPLETED,
        finished_at: Time.current,
        context: context,
        output: output,
      )
    end

    def fail_step!(step, context:, custom_errors:, logs:, retry_step_id: nil)
      step.update!(
        state: Bemi::StepInstance::STATE_FAILED,
        finished_at: Time.current,
        custom_errors: custom_errors,
        context: context,
        logs: logs,
        retry_step_instance_id: retry_step_id,
      )
    end

    def set_retry_step!(step, retry_step_id:)
      step.update!(retry_step_instance_id: retry_step_id)
    end

    def find_steps!(workflow_id)
      Bemi::StepInstance.where(workflow_instance_id: workflow_id)
    end

    def not_finished_step_count(concurrency_key)
      Bemi::StepInstance.not_finished.where(concurrency_key: concurrency_key).count
    end

    def incomplete_step_names(step_names, workflow_id)
      completed_step_names = Bemi::StepInstance.where(name: step_names, workflow_instance_id: workflow_id, state: Bemi::StepInstance::STATE_COMPLETED).pluck(:name)
      step_names - completed_step_names
    end

    def transaction(&block)
      Bemi::ApplicationRecord.transaction(&block)
    end
  end
end
