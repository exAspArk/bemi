# frozen_string_literal: true

require 'forwardable'

class Bemi::Storage
  ADAPTER_BY_NAME = {
    memory: Bemi::Adapters::Memory,
    # active_record: Bemi::Adapters::ActiveRecord,
  }.freeze

  class << self
    extend Forwardable

    def_delegators :adapter, :upsert_workflow_definitions!

    def adapter
      @adapter ||= ADAPTER_BY_NAME[Bemi::Config.configuration[:storage]]
    end
  end
end
