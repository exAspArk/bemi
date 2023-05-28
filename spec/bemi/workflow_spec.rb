# frozen_string_literal: true

RSpec.describe Bemi::Workflow do
  describe '.definition' do
    it 'returns a list of steps' do
      result = SyncRegistrationWorkflow.definition

      expect(result).to eq(
        name: 'sync_registration',
        steps: [
          { sync: true, async: nil, concurrency: nil, name: "create_user", on_error: nil, wait_for: nil },
          { sync: true, async: nil, concurrency: nil, name: "send_confirmation_email", on_error: nil, wait_for: nil },
          { sync: true, async: nil, concurrency: nil, name: "confirm_email_address", on_error: nil, wait_for: ['send_confirmation_email'] },
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

    it "raises an error if an step definition doesn't specify 'sync' or 'async'" do
      workflow_class = Class.new(Bemi::Workflow)
      workflow_class.class_eval do
        name SecureRandom.hex

        def perform
          step :test_step, on_error: { retry: 1 }
        end
      end

      expect {
        workflow_class.definition
      }.to raise_error(Bemi::Workflow::InvalidStepDefinitionError, "Step 'test_step' must be either 'sync' or 'async'")
    end

    it 'raises an error if an step waits for an invalid step' do
      workflow_class = Class.new(Bemi::Workflow)
      workflow_class.class_eval do
        name SecureRandom.hex

        def perform
          step :test_step, async: { queue: 'default' }, wait_for: [:step1, :step2]
        end
      end

      expect {
        workflow_class.definition
      }.to raise_error(Bemi::Workflow::InvalidStepDefinitionError, "Step 'test_step' waits for unknown step names: 'step1', 'step2'")
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
