# frozen_string_literal: true

require 'active_job'

class Bemi::ActionJob < Bemi::Config.configuration.fetch(:background_job_parent_class).constantize
  def perform(action_id)
    Bemi::Runner.perform_created_action(action_id)
  end
end

class Bemi::BackgroundJob::ActiveJob
  class << self
    def perform_async(action_id)
      Bemi::ActionJob.perform_later(action_id)
    end
  end
end
