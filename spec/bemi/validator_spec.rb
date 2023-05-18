# frozen_string_literal: true

RSpec.describe Bemi::Validator do
  describe '.validate' do
    it 'returns an error for enum values' do
      errors = Bemi::Validator.validate({ storage_type: 'mongoid', storage_parent_class: 'TestClass' }, Bemi::Config::CONFIGURATION_SCHEMA)
      expect(errors).to eq(["The field 'storage_type' value 'mongoid' did not match one of the following values: active_record"])
    end

    it 'returns an error for unsupported extra values' do
      errors = Bemi::Validator.validate({ storage_type: 'active_record', storage_parent_class: 'TestClass', foo: 'bar' }, Bemi::Config::CONFIGURATION_SCHEMA)
      expect(errors).to eq(["The field 'foo' is not supported"])
    end

    it 'returns an error for unsupported nested extra values' do
      errors = Bemi::Validator.validate({ async: { foo: 'bar' } }, Bemi::Workflow::ACTION_SCHEMA)
      expect(errors).to eq(["The field 'async' did not contain a required field of 'queue'", "The field 'foo' is not supported"])
    end
  end
end
