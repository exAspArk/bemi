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
            next if action_definition.fetch(:execution) == Bemi::Workflow::EXECUTION_SYNC

            action_name = action_definition.fetch(:name)
            next if Bemi::Runner.action_need_to_wait_for(workflow, action_name).any?

            actions = actions_by_name[action_name]
            if actions.nil?
              perform_action_async!(action_name, action_definition: action_definition, workflow_id: workflow.id)
              next
            end

            action = actions_by_name[action_name].select(&:failed?).sort_by(&:retry_count).last
            next if !action || !Bemi::Runner.action_can_retry?(action)

            retry_action_async!(action, action_definition: action_definition, workflow_id: workflow.id)
          end
        end
      end
    end

    private

    # TODO: concurrency

    def retry_action_async!(action, action_definition:, workflow_id:)
      options = enqueue_options(action_definition)

      retry_action = nil
      Bemi::Storage.transaction do
        retry_action = Bemi::Storage.create_action!(action.name, workflow_id, retry_count: action.retry_count + 1)
        Bemi::Storage.set_retry_action!(action, retry_action_id: retry_action.id)
      end

      Bemi::BackgroundJob.set(options).perform_later(retry_action.id)
    end

    def perform_action_async!(action_name, action_definition:, workflow_id:)
      options = enqueue_options(action_definition)
      action_instance = Bemi::Storage.create_action!(action_name, workflow_id)
      Bemi::BackgroundJob.set(options).perform_later(action_instance.id)
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
