# frozen_string_literal: true

RSpec.describe Bemi::Config do
  describe '.storage' do
    it 'raises an error if trying to set an invalid option' do
      expect {
        Bemi.configure { |config| config.storage = :invalid }
      }.to raise_error(Bemi::Config::InvalidConfigurationError, "The field 'storage' value 'invalid' did not match one of the following values: memory, active_record")
    end
  end
end
