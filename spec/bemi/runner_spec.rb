# frozen_string_literal: true

RSpec.describe Bemi::Runner do
  describe '.perform_workflow' do
    it 'raises an error if the workflow does not exist' do
      expect {
        Bemi::Runner.perform_workflow(:foo, context: {})
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises an error if the context is invalid' do
      expect {
        Bemi::Runner.perform_workflow(:sync_registration, context: {})
      }.to raise_error(Bemi::Runner::InvalidContext, "The value did not contain a required field of 'email'")
    end

    it 'returns a workflow instance' do
      workflow = Bemi::Runner.perform_workflow(:sync_registration, context: { email: 'email@example.com' })
      expect(workflow.id).to be_a(String)
      expect(workflow.name).to eq('sync_registration')
      expect(workflow.status).to eq('pending')
      expect(workflow.context).to eq(email: 'email@example.com')
      expect(workflow.definition).to include(SyncRegistrationWorkflow.definition)
    end
  end

  describe '.perform_action' do
    it 'creates an action instance' do
      workflow = Bemi::Runner.perform_workflow(:sync_registration, context: { email: 'email@example.com' })
      expect {
        Bemi::Runner.perform_action(:create_user, workflow_id: workflow.id, input: { password: 'asdf' })
      }.to change { Bemi::ActionInstance.count }.by(1)

      action_instance = Bemi::ActionInstance.last
      expect(action_instance.id).to be_a(String)
      expect(action_instance.name).to eq('create_user')
      expect(action_instance.logs).to eq(nil)
      expect(action_instance.status).to eq('completed')
      expect(action_instance.workflow_instance_id).to eq(workflow.id)
      expect(action_instance.input).to eq(password: 'asdf')
      expect(action_instance.retry_count).to eq(0)
      expect(action_instance.started_at).to be_a(Time)
      expect(action_instance.finished_at).to be_a(Time)
      expect(action_instance.context).to eq(tags: %w[around_perform1 around_perform2 perform])
      expect(action_instance.output).to eq(['id' => 'id'])
    end

    it 'raises an error if passed an invalid input' do
      workflow = Bemi::Runner.perform_workflow(:sync_registration, context: { email: 'email@example.com' })

      expect {
        Bemi::Runner.perform_action(:create_user, workflow_id: workflow.id, input: { foo: 'bar' })
      }.to raise_error(Bemi::Runner::InvalidInput, "The value did not contain a required field of 'password'")
    end
  end
end
