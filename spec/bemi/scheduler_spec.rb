require 'bemi/background_job/active_job'

RSpec.describe Bemi::Scheduler do
  describe '.run' do
    it 'schedules an async action' do
      workflow = Bemi.perform_workflow(:async_registration)

      expect { Bemi::Scheduler.run }.to change { Bemi::ActionInstance.count }.by(1)

      action = Bemi::ActionInstance.order(:created_at).last
      expect(action.workflow).to eq(workflow)
      expect(action.name).to eq('create_user')
      expect(action.pending?).to eq(true)
      expect(action.started_at).to be(nil)
      expect(action.finished_at).to be(nil)
    end

    it 'executes an async action' do
      workflow = Bemi.perform_workflow(:async_registration)

      perform_enqueued_jobs(queue: 'default') { Bemi::Scheduler.run }

      action = Bemi::ActionInstance.order(:created_at).first
      expect(action.reload.workflow).to eq(workflow)
      expect(action.name).to eq('create_user')
      expect(action.logs).to eq(nil)
      expect(action.workflow_instance_id).to eq(workflow.id)
      expect(action.input).to eq(nil)
      expect(action.retry_count).to eq(0)
      expect(action.started_at).to be_a(Time)
      expect(action.finished_at).to be_a(Time)
      expect(action.context).to eq(tags: %w[around_perform1 around_perform2 perform])
      expect(action.output).to eq([id: 'id'])
      expect(action.started_at).to be_a(Time)
      expect(action.finished_at).to be_a(Time)
    end

    it 'does not execute an async action if there is a concurrency conflict' do
      Bemi.perform_workflow(:async_registration)
      Bemi::Scheduler.run
      Bemi.perform_workflow(:async_registration)

      expect { Bemi::Scheduler.run }.not_to change { Bemi::ActionInstance.count }
    end

    it 'schedules the next action' do
      workflow = Bemi.perform_workflow(:async_registration)
      perform_enqueued_jobs(queue: 'default') { Bemi::Scheduler.run }

      Bemi::Scheduler.run

      action = Bemi::ActionInstance.order(:created_at).last
      expect(action.workflow).to eq(workflow)
      expect(action.name).to eq('send_confirmation_email')
      expect(action.pending?).to eq(true)
      expect(action.started_at).to be(nil)
      expect(action.finished_at).to be(nil)
    end

    it 'retries a failed action' do
      workflow = Bemi.perform_workflow(:async_registration, context: { email: 'email@example.com' })

      perform_enqueued_jobs { Bemi::Scheduler.run }
      action1 = Bemi::ActionInstance.order(:created_at).offset(1).last
      expect(action1.workflow).to eq(workflow)
      expect(action1.name).to eq('send_confirmation_email')
      expect(action1.failed?).to eq(true)
      expect(action1.context).to eq(email: 'email@example.com', around_rollbacked: true, rollbacked: true)
      expect(action1.custom_errors).to eq(email: 'Invalid email: email@example.com')
      expect(action1.logs).to be_a(String)
      expect(action1.started_at).to be_a(Time)
      expect(action1.finished_at).to be_a(Time)
      expect(action1.retry_count).to eq(0)
      expect(workflow.reload.running?).to eq(true)

      perform_enqueued_jobs { Bemi::Scheduler.run }
      action2 = Bemi::ActionInstance.order(:created_at).last
      expect(action2.id).not_to eq(action1.id)
      expect(action2).to eq(action1.reload.retry_action)
      expect(action2.workflow).to eq(workflow)
      expect(action2.name).to eq('send_confirmation_email')
      expect(action2.failed?).to eq(true)
      expect(action2.context).to eq(email: 'email@example.com', around_rollbacked: true, rollbacked: true)
      expect(action2.custom_errors).to eq(email: 'Invalid email: email@example.com')
      expect(action2.logs).to be_a(String)
      expect(action2.started_at).to be_a(Time)
      expect(action2.finished_at).to be_a(Time)
      expect(action2.retry_action_instance_id).to be(nil)
      expect(action2.retry_count).to eq(1)
      expect(workflow.reload.failed?).to eq(true)
    end

    it 'does not retry after max retry count' do
      workflow = Bemi.perform_workflow(:async_registration, context: { email: 'email@example.com' })
      perform_enqueued_jobs
      Bemi::Scheduler.run # create_user
      Bemi::Scheduler.run # send_confirmation_email
      Bemi::Scheduler.run # send_confirmation_email retry

      expect { Bemi::Scheduler.run }.not_to change { Bemi::ActionInstance.count }
    end
  end
end
