# frozen_string_literal: true

require 'fugit'

class Bemi::Scheduler
  class << self
    def daemonize

    end

    def run
      Bemi::Storage.not_finished_workflow_ids.shuffle.each do |workflow_id|
        Bemi::Storage.transaction do
          workflow = Bemi::Storage.find_and_lock_workflow!(workflow_id)
          next if workflow.finished?

          action_definitions = workflow.definition.fetch(:actions)
          actions_by_name = Bemi::Storage.find_actions!(workflow.id).group_by(&:name)

          action_definitions.each do |action_definition|
            next if action_definition.fetch(:sync)

            action_name = action_definition.fetch(:name)
            next if Bemi::Runner.action_need_to_wait_for(workflow, action_name).any?

            actions = actions_by_name[action_name]
            if actions.nil?
              perform_action_async!(action_name, action_definition: action_definition, workflow: workflow)
              next
            end

            action = actions_by_name[action_name].select(&:failed?).sort_by(&:retry_count).last
            next if !action || !Bemi::Runner.action_can_retry?(action)

            retry_action_async!(action, action_definition: action_definition, workflow: workflow)
          end
        end
      end
    end

    private

    def retry_action_async!(action, action_definition:, workflow:)
      options = enqueue_options(action_definition)
      concurrency_key = concurrency_key(action.name, workflow: workflow)
      return if Bemi::Runner.concurrency_action(action_definition, concurrency_key) == Bemi::Action::ON_CONFLICT_RESCHEDULE

      retry_action = nil
      Bemi::Storage.transaction do
        retry_action = Bemi::Storage.create_action!(action.name, workflow_id: workflow.id, retry_count: action.retry_count + 1, concurrency_key: concurrency_key)
        Bemi::Storage.set_retry_action!(action, retry_action_id: retry_action.id)
      end

      Bemi::BackgroundJob.set(options).perform_later(retry_action.id)
    end

    def perform_action_async!(action_name, action_definition:, workflow:)
      options = enqueue_options(action_definition)
      concurrency_key = concurrency_key(action_name, workflow: workflow)
      return if Bemi::Runner.concurrency_action(action_definition, concurrency_key) == Bemi::Action::ON_CONFLICT_RESCHEDULE

      action_instance = Bemi::Storage.create_action!(action_name, workflow_id: workflow.id, concurrency_key: concurrency_key)
      Bemi::BackgroundJob.set(options).perform_later(action_instance.id)
    end

    def concurrency_key(action_name, workflow:)
      action_class = Bemi::Registrator.find_action_class!(action_name)
      action = action_class.new(workflow: workflow)
      Bemi::Runner.concurrency_key_hash(action.concurrency_key)
    end

    def enqueue_options(action_definition)
      options = { queue: action_definition.fetch(:async).fetch(:queue) }

      if delay = action_definition.dig(:async, :delay)
        options[:wait] = delay
      end

      if cron = action_definition.dig(:async, :cron)
        options[:wait_until] = Fugit::Cron.parse(cron).next_time
      end

      if priority = action_definition.dig(:async, :priority)
        options[:priority] = priority
      end

      options
    end
  end
end
