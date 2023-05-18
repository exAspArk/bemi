# frozen_string_literal: true

require "bemi"
require 'securerandom'

Bemi.configure do |config|
  config.storage = :memory
end

Bemi::Registrator.sync_workflows!(Dir.glob('spec/fixtures/workflows/*.rb'))

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
