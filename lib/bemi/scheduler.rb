# frozen_string_literal: true

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
              perform_action_async!(action_name, workflow_id: workflow.id)
              next
            end

            action = actions_by_name[action_name].select(&:failed?).sort_by(&:retry_count).last
            next if !action

            if Bemi::Runner.action_can_retry?(action)
              retry_action_async!(action_name, workflow_id: workflow.id)
            end
          end
        end
      end
    end

    private

    def retry_action_async!(action_name, workflow_id:)

    end

    def perform_action_async!(action_name, workflow_id:)
      action_instance = Bemi::Storage.create_action!(action_name, workflow_id)
      Bemi::BackgroundJob.perform_async(action_instance.id)
    end
  end
end
