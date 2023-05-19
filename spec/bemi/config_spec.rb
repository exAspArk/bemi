# frozen_string_literal: true

RSpec.describe Bemi::Config do
  describe '.storage' do
    it 'raises an error if trying to set an invalid option' do
      expect {
        Bemi.configure { |config| config.storage_adapter = :invalid }
      }.to raise_error(Bemi::Config::InvalidConfigurationError, "The field 'storage_adapter' value 'invalid' did not match one of the following values: active_record")
    end
  end
end
