# frozen_string_literal: true

require "bemi"
require 'active_job'

Dir.glob('spec/support/**/*.rb').each { |file| require "./#{file}" }

Bemi.configure do |config|
  config.storage_adapter = :active_record
  config.storage_parent_class = 'ActiveRecord::Base'
  config.background_job_adapter = :active_job
  config.background_job_parent_class = 'ActiveJob::Base'
end
Bemi::Registrator.sync_workflows!(Dir.glob('spec/fixtures/workflows/**/*.rb'))
Dir.glob('spec/fixtures/actions/**/*.rb').each { |file| require "./#{file}" }

ActiveJob::Base.queue_adapter = :test

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    Bemi::ApplicationRecord.connection.truncate(Bemi::WorkflowInstance.table_name)
    Bemi::ApplicationRecord.connection.truncate(Bemi::ActionInstance.table_name)
  end
end
