# frozen_string_literal: true

require_relative 'bemi/modules/schemable'
require_relative 'bemi/step'
require_relative 'bemi/background_job'
require_relative 'bemi/config'
require_relative 'bemi/registrator'
require_relative 'bemi/runner'
require_relative 'bemi/scheduler'
require_relative 'bemi/storage'
require_relative 'bemi/validator'
require_relative 'bemi/version'
require_relative 'bemi/workflow'

class Bemi
  class << self
    def configure(&block)
      Bemi::Config.configure(&block)
    end

    def generate_migration
      require 'bemi/storage/migrator'
      Bemi::Storage::Migrator.migration
    end

    def perform_workflow(workflow_name, context: {})
      Bemi::Runner.perform_workflow(workflow_name, context: context)
    end

    def perform_step(step_name, workflow_id:, input: {})
      Bemi::Runner.perform_step(step_name, workflow_id: workflow_id, input: input)
    end
  end
end
