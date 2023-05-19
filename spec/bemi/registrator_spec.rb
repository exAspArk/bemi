# frozen_string_literal: true

RSpec.describe Bemi::Registrator do
  describe '.add_workflow' do
    it 'raises an error if the workflow name is already registered' do
      expect {
        Bemi::Registrator.add_workflow(:sync_registration, SyncRegistrationWorkflow)
      }.to raise_error(Bemi::Registrator::DuplicateWorkflowNameError, "Workflow 'sync_registration' is already registered")
    end
  end

  describe '.add_action' do
    it 'raises an error if the action name is already registered' do
      expect {
        Bemi::Registrator.add_action(:create_user, CreateUserAction)
      }.to raise_error(Bemi::Registrator::DuplicateActionNameError, "Action 'create_user' is already registered")
    end
  end

  describe '.sync_workflows!' do
    it 'returns a list of workflows' do
      result = Bemi::Registrator.sync_workflows!(Dir.glob('../fixtures/workflows/*.rb'))

      expect(result).to match([
        {
          name: 'async_registration',
          actions: an_instance_of(Array),
          concurrency: nil,
          context_schema: nil,
        },
        {
          name: 'sync_registration',
          actions: an_instance_of(Array),
          concurrency: an_instance_of(Hash),
          context_schema: an_instance_of(Hash),
        },
      ])
    end
  end
end
