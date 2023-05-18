# frozen_string_literal: true

require_relative 'bemi/config'
require_relative 'bemi/registrator'
require_relative 'bemi/runner'
require_relative 'bemi/storage'
require_relative 'bemi/validator'
require_relative 'bemi/version'
require_relative 'bemi/workflow'

class Bemi
  class << self
    def configure(&block)
      Bemi::Config.configure(&block)
    end

    def perform_workflow(workflow_name, context: {})
      Bemi::Runner.perform_workflow(workflow_name, context: context)
    end
  end
end
