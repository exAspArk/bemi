# frozen_string_literal: true

require 'active_job'

class Bemi::StepJob < Bemi::Config.configuration.fetch(:background_job_parent_class).constantize
  discard_on StandardError

  def perform(step_id)
    Bemi::Runner.perform_created_step(step_id)
  end
end
