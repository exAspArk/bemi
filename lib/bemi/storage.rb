# frozen_string_literal: true

require 'forwardable'

class Bemi::Storage
  class << self
    extend Forwardable

    def_delegators :storage_class,
      :find_workflow_definition!,
      :upsert_workflow_definitions!,
      :create_workflow!

    def migration
      require_relative 'storage/migrator'
      Bemi::Storage::Migrator.migration
    end

    private

    def storage_class
      @storage_class ||=
        if Bemi::Config.configuration.fetch(:storage_type) == :active_record
          require_relative 'storage/active_record'
          Bemi::Storage::ActiveRecord
        end
    end
  end
end
