require 'bemi/background_job/active_job'

RSpec.describe Bemi::Scheduler do
  describe '.run' do
    it 'schedules an async step' do
      workflow = Bemi.perform_workflow(:async_registration)

      expect { Bemi::Scheduler.run }.to change { Bemi::StepInstance.count }.by(1)

      step = Bemi::StepInstance.order(:created_at).last
      expect(step.workflow).to eq(workflow)
      expect(step.name).to eq('create_user')
      expect(step.pending?).to eq(true)
      expect(step.started_at).to be(nil)
      expect(step.finished_at).to be(nil)
    end

    it 'executes an async step' do
      workflow = Bemi.perform_workflow(:async_registration)

      perform_enqueued_jobs(queue: 'default') { Bemi::Scheduler.run }

      step = Bemi::StepInstance.order(:created_at).first
      expect(step.reload.workflow).to eq(workflow)
      expect(step.name).to eq('create_user')
      expect(step.logs).to eq(nil)
      expect(step.workflow_instance_id).to eq(workflow.id)
      expect(step.input).to eq(nil)
      expect(step.retry_count).to eq(0)
      expect(step.started_at).to be_a(Time)
      expect(step.finished_at).to be_a(Time)
      expect(step.context).to eq(tags: %w[around_perform1 around_perform2 perform])
      expect(step.output).to eq([id: 'id'])
      expect(step.started_at).to be_a(Time)
      expect(step.finished_at).to be_a(Time)
    end

    it 'does not execute an async step if there is a concurrency conflict' do
      Bemi.perform_workflow(:async_registration)
      Bemi::Scheduler.run
      Bemi.perform_workflow(:async_registration)

      expect { Bemi::Scheduler.run }.not_to change { Bemi::StepInstance.count }
    end

    it 'schedules the next step' do
      workflow = Bemi.perform_workflow(:async_registration)
      perform_enqueued_jobs(queue: 'default') { Bemi::Scheduler.run }

      Bemi::Scheduler.run

      step = Bemi::StepInstance.order(:created_at).last
      expect(step.workflow).to eq(workflow)
      expect(step.name).to eq('send_confirmation_email')
      expect(step.pending?).to eq(true)
      expect(step.started_at).to be(nil)
      expect(step.finished_at).to be(nil)
    end

    it 'retries a failed step' do
      workflow = Bemi.perform_workflow(:async_registration, context: { email: 'email@example.com' })

      perform_enqueued_jobs { Bemi::Scheduler.run }
      step1 = Bemi::StepInstance.order(:created_at).offset(1).last
      expect(step1.workflow).to eq(workflow)
      expect(step1.name).to eq('send_confirmation_email')
      expect(step1.failed?).to eq(true)
      expect(step1.context).to eq(email: 'email@example.com', around_rollbacked: true, rollbacked: true)
      expect(step1.custom_errors).to eq(email: 'Invalid email: email@example.com')
      expect(step1.logs).to be_a(String)
      expect(step1.started_at).to be_a(Time)
      expect(step1.finished_at).to be_a(Time)
      expect(step1.retry_count).to eq(0)
      expect(workflow.reload.running?).to eq(true)

      perform_enqueued_jobs { Bemi::Scheduler.run }
      step2 = Bemi::StepInstance.order(:created_at).last
      expect(step2.id).not_to eq(step1.id)
      expect(step2).to eq(step1.reload.retry_step)
      expect(step2.workflow).to eq(workflow)
      expect(step2.name).to eq('send_confirmation_email')
      expect(step2.failed?).to eq(true)
      expect(step2.context).to eq(email: 'email@example.com', around_rollbacked: true, rollbacked: true)
      expect(step2.custom_errors).to eq(email: 'Invalid email: email@example.com')
      expect(step2.logs).to be_a(String)
      expect(step2.started_at).to be_a(Time)
      expect(step2.finished_at).to be_a(Time)
      expect(step2.retry_step_instance_id).to be(nil)
      expect(step2.retry_count).to eq(1)
      expect(workflow.reload.failed?).to eq(true)
    end

    it 'does not retry after max retry count' do
      workflow = Bemi.perform_workflow(:async_registration, context: { email: 'email@example.com' })
      perform_enqueued_jobs
      Bemi::Scheduler.run # create_user
      Bemi::Scheduler.run # send_confirmation_email
      Bemi::Scheduler.run # send_confirmation_email retry

      expect { Bemi::Scheduler.run }.not_to change { Bemi::StepInstance.count }
    end
  end
end
