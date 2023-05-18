# frozen_string_literal: true

RSpec.describe Bemi::Runner do
  describe '.perform_workflow' do
    it 'raises an error if the workflow does not exist' do
      expect {
        Bemi::Runner.perform_workflow(:foo, context: {})
      }.to raise_error(Bemi::Storage::WorkflowNotFound, 'foo')
    end

    it 'raises an error if the context is invalid' do
      expect {
        Bemi::Runner.perform_workflow(:sync_registration, context: {})
      }.to raise_error(Bemi::Runner::InvalidContext, "The value did not contain a required field of 'email'")
    end
  end
end
