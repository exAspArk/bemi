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

    it "raises an error if an action definition doesn't specify 'sync' or 'async'" do
      workflow_class = Class.new(Bemi::Workflow)
      workflow_class.class_eval do
        name SecureRandom.hex

        def perform
          action :test_action, on_error: { retry: 1 }
        end
      end

      expect {
        workflow_class.actions
      }.to raise_error(Bemi::Workflow::InvalidActionDefinitionError, "Action 'test_action' must be either 'sync' or 'async'")
    end

    it 'raises an error if an action waits for an invalid action' do
      workflow_class = Class.new(Bemi::Workflow)
      workflow_class.class_eval do
        name SecureRandom.hex

        def perform
          action :test_action, async: true, wait_for: [:action1, :action2]
        end
      end

      expect {
        workflow_class.actions
      }.to raise_error(Bemi::Workflow::InvalidActionDefinitionError, "Action 'test_action' waits for unknown action names: 'action1', 'action2'")
    end
  end

  describe '.concurrency' do
    it 'raises an error if concurrency options are invalid' do
      workflow_class = Class.new(Bemi::Workflow)

      expect {
        workflow_class.concurrency({ limit: 0, on_conflict: 'give_up' })
      }.to raise_error(Bemi::Workflow::InvalidConcurrencyOptionError, "The field 'limit' did not have a minimum value of 1, inclusively")
    end
  end
end
