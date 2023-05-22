# frozen_string_literal: true

require 'active_job'

class Bemi::ActionJob < Bemi::Config.configuration.fetch(:background_job_parent_class).constantize
  discard_on StandardError

  def perform(action_id)
    Bemi::Runner.perform_created_action(action_id)
  end
end
