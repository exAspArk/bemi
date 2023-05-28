# frozen_string_literal: true

require 'forwardable'

class Bemi::Storage
  class << self
    extend Forwardable

    def_delegators :storage_class,
      # workflows
      :find_workflow_definition!,
      :upsert_workflow_definitions!,
      :create_workflow!,
      :find_workflow!,
      :find_and_lock_workflow!,
      :start_workflow!,
      :complete_workflow!,
      :fail_workflow!,
      :update_workflow_context!,
      :not_finished_workflow_ids,
      :not_finished_workflow_count,
      # steps
      :find_step!,
      :create_step!,
      :start_step!,
      :complete_step!,
      :fail_step!,
      :incomplete_step_names,
      :find_steps!,
      :set_retry_step!,
      :not_finished_step_count,
      # misc
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
