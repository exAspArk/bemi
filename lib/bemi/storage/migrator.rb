# frozen_string_literal: true

require 'active_record'

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
            t.string :status
            t.json :context
            t.timestamp :started_at
            t.timestamp :finished_at
            t.timestamps
          end
        end

        def down
          drop_table :bemi_workflow_definitions, if_exists: true
          drop_table :bemi_workflow_instances, if_exists: true
        end
      end

      migration_class
    end
  end
end
