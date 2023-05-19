# frozen_string_literal: true

require "bemi"

Dir.glob('spec/support/**/*.rb').each { |file| require "./#{file}" }

Bemi.configure do |config|
  config.storage_adapter = :active_record
  config.storage_parent_class = 'ActiveRecord::Base'
end

Bemi::Registrator.sync_workflows!(Dir.glob('spec/fixtures/workflows/**/*.rb'))

Dir.glob('spec/fixtures/actions/**/*.rb').each { |file| require "./#{file}" }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
