# frozen_string_literal: true

RSpec.describe Bemi::Workflow do
  describe '.actions' do
    it 'returns a list of actions' do
      result = SyncRegistrationWorkflow.actions

      expect(result).to eq([
        {
          name: 'create_user',
          execution: 'sync',
          wait_for: [],
          async: {},
          on_error: {},
          concurrency: {},
          input_schema: {},
          output_schema: {},
        },
        {
          name: 'send_confirmation_email',
          execution: 'sync',
          wait_for: [],
          async: {},
          on_error: {},
          concurrency: {},
          input_schema: {},
          output_schema: {},
        },
        {
          name: 'confirm_email_address',
          execution: 'sync',
          wait_for: [],
          async: {},
          on_error: {},
          concurrency: {},
          input_schema: {},
          output_schema: {},
        },
      ])
    end
  end
end
