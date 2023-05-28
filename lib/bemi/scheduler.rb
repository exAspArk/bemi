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

          step_definitions = workflow.definition.fetch(:steps)
          steps_by_name = Bemi::Storage.find_steps!(workflow.id).group_by(&:name)

          step_definitions.each do |step_definition|
            next if step_definition.fetch(:sync)

            step_name = step_definition.fetch(:name)
            next if Bemi::Runner.step_need_to_wait_for(workflow, step_name).any?

            steps = steps_by_name[step_name]
            if steps.nil?
              perform_step_async!(step_name, step_definition: step_definition, workflow: workflow)
              next
            end

            step = steps_by_name[step_name].select(&:failed?).sort_by(&:retry_count).last
            next if !step || !Bemi::Runner.step_can_retry?(step)

            retry_step_async!(step, step_definition: step_definition, workflow: workflow)
          end
        end
      end
    end

    private

    def retry_step_async!(step, step_definition:, workflow:)
      options = enqueue_options(step_definition)
      concurrency_key = concurrency_key(step.name, workflow: workflow)
      return if Bemi::Runner.concurrency_step(step_definition, concurrency_key) == Bemi::Step::ON_CONFLICT_RESCHEDULE

      retry_step = nil
      Bemi::Storage.transaction do
        retry_step = Bemi::Storage.create_step!(step.name, workflow_id: workflow.id, retry_count: step.retry_count + 1, concurrency_key: concurrency_key)
        Bemi::Storage.set_retry_step!(step, retry_step_id: retry_step.id)
      end

      Bemi::BackgroundJob.set(options).perform_later(retry_step.id)
    end

    def perform_step_async!(step_name, step_definition:, workflow:)
      options = enqueue_options(step_definition)
      concurrency_key = concurrency_key(step_name, workflow: workflow)
      return if Bemi::Runner.concurrency_step(step_definition, concurrency_key) == Bemi::Step::ON_CONFLICT_RESCHEDULE

      step_instance = Bemi::Storage.create_step!(step_name, workflow_id: workflow.id, concurrency_key: concurrency_key)
      Bemi::BackgroundJob.set(options).perform_later(step_instance.id)
    end

    def concurrency_key(step_name, workflow:)
      step_class = Bemi::Registrator.find_step_class!(step_name)
      step = step_class.new(workflow: workflow)
      Bemi::Runner.concurrency_key_hash(step.concurrency_key)
    end

    def enqueue_options(step_definition)
      options = { queue: step_definition.fetch(:async).fetch(:queue) }

      if delay = step_definition.dig(:async, :delay)
        options[:wait] = delay
      end

      if cron = step_definition.dig(:async, :cron)
        options[:wait_until] = Fugit::Cron.parse(cron).next_time
      end

      if priority = step_definition.dig(:async, :priority)
        options[:priority] = priority
      end

      options
    end
  end
end
