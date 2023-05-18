# frozen_string_literal: true

RSpec.describe Bemi::Registrator do
  describe '.add' do
    it 'raises an error if the workflow name is already registered' do
      expect {
        Bemi::Registrator.add_workflow(:sync_registration, SyncRegistrationWorkflow)
      }.to raise_error(Bemi::Registrator::DuplicateWorkflowNameError, "Workflow 'sync_registration' is already registered")
    end
  end

  describe '.sync_workflows!' do
    it 'returns a list of workflows' do
      result = Bemi::Registrator.sync_workflows!(Dir.glob('../fixtures/workflows/*.rb'))

      expect(result).to eq([
        {
          name: 'sync_registration',
          actions: SyncRegistrationWorkflow.actions,
          concurrency: { limit: 1, on_conflict: :raise },
        }
      ])
    end
  end
end