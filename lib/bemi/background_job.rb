# frozen_string_literal: true

require 'forwardable'

class Bemi::BackgroundJob
  class << self
    extend Forwardable

    def_delegators :background_job_class,
      :new,
      :set,
      :perform_later

    private

    def background_job_class
       @background_job_class ||=
        if Bemi::Config.configuration.fetch(:background_job_adapter) == Bemi::Config::BACKGROUND_JOB_ADAPTER_ACTIVE_JOB
          require_relative 'background_job/active_job'
          Bemi::ActionJob
        end
    end
  end
end
