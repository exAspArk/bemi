# frozen_string_literal: true

require 'forwardable'

class Bemi::Storage
  class << self
    extend Forwardable

    def_delegators :storage_class,
      :find_workflow_definition!,
      :upsert_workflow_definitions!,
      :create_workflow!,
      :find_workflow!,
      :create_action!,
      :start_action!,
      :complete_action!,
      :fail_action!,
      :incomplete_action_names,
      :transaction

    private

    def storage_class
      @storage_class ||=
        if Bemi::Config.configuration.fetch(:storage_adapter) == Bemi::Config::STORAGE_ADAPTER_ACTIVE_RECORD
          require_relative 'storage/active_record'
          Bemi::Storage::ActiveRecord
        end
    end
  end
end
