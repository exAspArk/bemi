# frozen_string_literal: true

RSpec.describe Bemi::Registrator do
  describe '.add_workflow' do
    it 'raises an error if the workflow name is already registered' do
      expect {
        Bemi::Registrator.add_workflow(:sync_registration, SyncRegistrationWorkflow)
      }.to raise_error(Bemi::Registrator::DuplicateWorkflowNameError, "Workflow 'sync_registration' is already registered")
    end
  end

  describe '.add_step' do
    it 'raises an error if the step name is already registered' do
      expect {
        Bemi::Registrator.add_step(:create_user, CreateUserStep)
      }.to raise_error(Bemi::Registrator::DuplicateStepNameError, "Step 'create_user' is already registered")
    end
  end

  describe '.sync_workflows!' do
    it 'returns a list of workflows' do
      result = Bemi::Registrator.sync_workflows!(Dir.glob('../fixtures/workflows/*.rb'))

      expect(result).to match([
        {
          name: 'async_registration',
          steps: an_instance_of(Array),
          concurrency: nil,
          context_schema: nil,
        },
        {
          name: 'single_step',
          steps: an_instance_of(Array),
          concurrency: nil,
          context_schema: nil,
        },
        {
          name: 'sync_registration',
          steps: an_instance_of(Array),
          concurrency: an_instance_of(Hash),
          context_schema: an_instance_of(Hash),
        },
      ])
    end
  end
end
