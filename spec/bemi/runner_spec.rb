# frozen_string_literal: true

RSpec.describe Bemi::Runner do
  describe '.perform_workflow' do
    it 'raises an error if the workflow does not exist' do
      expect {
        Bemi.perform_workflow(:foo, context: {})
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises an error if the context is invalid' do
      expect {
        Bemi.perform_workflow(:sync_registration, context: {})
      }.to raise_error(Bemi::Runner::InvalidContext, "The value did not contain a required field of 'email'")
    end

    it 'returns a workflow instance' do
      workflow = Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com' })
      expect(workflow.id).to be_a(String)
      expect(workflow.name).to eq('sync_registration')
      expect(workflow.state).to eq('pending')
      expect(workflow.context).to eq(email: 'email@example.com')
      expect(workflow.definition).to include(SyncRegistrationWorkflow.definition)
    end

    it 'raises an error if the workflow is already running' do
      Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com' })
      Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com' })

      expect {
        Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com' })
      }.to raise_error(Bemi::Runner::ConcurrencyError, "Cannot run more than 2 'sync_registration' workflows at a time")
    end
  end

  describe '.perform_step' do
    context 'complete' do
      it 'creates an step instance' do
        workflow = Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com' })
        expect {
          Bemi.perform_step(:create_user, workflow_id: workflow.id, input: { password: 'asdf' })
        }.to change { Bemi::StepInstance.count }.by(1)

        step_instance = Bemi::StepInstance.order(finished_at: :desc).first
        expect(step_instance.id).to be_a(String)
        expect(step_instance.name).to eq('create_user')
        expect(step_instance.logs).to eq(nil)
        expect(step_instance.state).to eq('completed')
        expect(step_instance.workflow_instance_id).to eq(workflow.id)
        expect(step_instance.input).to eq(password: 'asdf')
        expect(step_instance.retry_count).to eq(0)
        expect(step_instance.started_at).to be_a(Time)
        expect(step_instance.finished_at).to be_a(Time)
        expect(step_instance.context).to eq(tags: %w[around_perform1 around_perform2 perform])
        expect(step_instance.output).to eq([id: 'id'])
      end

      it 'returns the output' do
        workflow = Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com' })
        output = Bemi.perform_step(:create_user, workflow_id: workflow.id, input: { password: 'asdf' })

        expect(output).to eq([id: 'id'])
      end

      it 'complete the workflow if all steps are completed' do
        workflow = Bemi.perform_workflow(:single_step)

        expect {
          Bemi.perform_step(:confirm_email_address, workflow_id: workflow.id)
        }.to change { workflow.reload.state }.from('pending').to('completed')

        expect(workflow.context).to eq(confirmed: true)
      end
    end

    context 'fail' do
      it 'fails if failed manually with custom_errors' do
        workflow = Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com' })

        expect {
          Bemi.perform_step(:send_confirmation_email, workflow_id: workflow.id)
        }.to raise_error(Bemi::Step::CustomFailError)

        step_instance = Bemi::StepInstance.order(finished_at: :desc).first
        expect(step_instance.id).to be_a(String)
        expect(step_instance.name).to eq('send_confirmation_email')
        expect(step_instance.logs).to be_a(String)
        expect(step_instance.state).to eq('failed')
        expect(step_instance.workflow_instance_id).to eq(workflow.id)
        expect(step_instance.input).to eq({})
        expect(step_instance.retry_count).to eq(0)
        expect(step_instance.started_at).to be_a(Time)
        expect(step_instance.finished_at).to be_a(Time)
        expect(step_instance.context).to eq({ email: 'email@example.com', rollbacked: true, around_rollbacked: true })
        expect(step_instance.output).to eq(nil)
        expect(step_instance.custom_errors).to eq({ email: 'Invalid email: email@example.com' })
      end

      it 'marks the workflow as failed' do
        workflow = Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com' })

        expect {
          Bemi.perform_step(:send_confirmation_email, workflow_id: workflow.id)
        }.to raise_error(Bemi::Step::CustomFailError)

        expect(workflow.reload.state).to eq('failed')
      end

      it 'fails if still waits for another step' do
        workflow = Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com', remember_me: true })

        expect {
          Bemi.perform_step(:confirm_email_address, workflow_id: workflow.id)
        }.to raise_error(Bemi::Runner::WaitingForStepError, "Waiting for steps: 'send_confirmation_email'")
      end
    end

    context 'validation' do
      it 'raises an error if passed an invalid input' do
        workflow = Bemi.perform_workflow(:sync_registration, context: { email: 'email@example.com' })

        expect {
          Bemi.perform_step(:create_user, workflow_id: workflow.id, input: { foo: 'bar' })
        }.to raise_error(Bemi::Runner::InvalidInput, "The value did not contain a required field of 'password'")
      end
    end
  end
end
