# frozen_string_literal: true

RSpec.describe Bemi::Workflow do
  describe '.definition' do
    it 'returns a list of actions' do
      result = SyncRegistrationWorkflow.definition

      expect(result).to eq(
        name: 'sync_registration',
        actions: [
          { async: nil, concurrency: nil, execution:"sync", name: "create_user", on_error: nil, wait_for: nil },
          { async: nil, concurrency: nil, execution: "sync", name: "send_confirmation_email", on_error: nil, wait_for: nil },
          { async: nil, concurrency: nil, execution: "sync", name: "confirm_email_address", on_error: nil, wait_for: ['send_confirmation_email'] },
        ],
        concurrency: { limit: 2, on_conflict: 'raise' },
        context_schema: {
          type: 'object',
          properties: {
            email: { type: 'string' },
            remember_me: { type: 'boolean' },
          },
          required: %w[email],
        },
      )
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
        workflow_class.definition
      }.to raise_error(Bemi::Workflow::InvalidActionDefinitionError, "Action 'test_action' must be either 'sync' or 'async'")
    end

    it 'raises an error if an action waits for an invalid action' do
      workflow_class = Class.new(Bemi::Workflow)
      workflow_class.class_eval do
        name SecureRandom.hex

        def perform
          action :test_action, async: { queue: 'default' }, wait_for: [:action1, :action2]
        end
      end

      expect {
        workflow_class.definition
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
