# frozen_string_literal: true

require 'active_record'

# SQLite limitations:
# - Doesn't automatically generate UUID primary keys
# - Doesn't support UUID column types

class Bemi::Storage::Migrator
  class << self
    def migration
      migration_class = Class.new(ActiveRecord::Migration[7.0])

      migration_class.class_eval do
        def up
          create_table :bemi_workflow_definitions, id: :uuid do |t|
            t.string :name, null: false, index: { unique: true }
            t.json :actions, null: false
            t.json :concurrency
            t.json :context_schema
            t.timestamps
          end

          create_table :bemi_workflow_instances, id: :uuid do |t|
            t.string :name, null: false, index: true
            t.json :definition, null: false
            t.string :state, null: false, index: true
            t.json :context
            t.timestamp :started_at
            t.timestamp :finished_at
            t.timestamps
          end

          create_table :bemi_action_instances, id: :uuid do |t|
            t.string :name, null: false, index: true
            t.string :state, null: false, index: true
            if connection.raw_connection.is_a?(SQLite3::Database)
              t.string :workflow_instance_id, null: false, index: true
              t.string :retry_action_instance_id, index: true
            else
              t.uuid :workflow_instance_id, null: false, index: true
              t.uuid :retry_action_instance_id, index: true
            end
            t.integer :retry_count, null: false, default: 0
            t.json :input
            t.json :output
            t.json :context
            t.json :custom_errors
            t.text :logs
            t.string :concurrency_key, index: true
            t.timestamp :run_at
            t.timestamp :started_at
            t.timestamp :finished_at
            t.timestamps
          end
        end

        def down
          drop_table :bemi_workflow_definitions, if_exists: true
          drop_table :bemi_workflow_instances, if_exists: true
          drop_table :bemi_action_instances, if_exists: true
        end
      end

      migration_class
    end
  end
end
