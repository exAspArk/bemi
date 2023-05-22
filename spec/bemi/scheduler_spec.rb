require 'bemi/background_job/active_job'

RSpec.describe Bemi::Scheduler do
  describe '.run' do
    it 'schedules an async action' do
      workflow = Bemi.perform_workflow(:async_registration)
      mock_job

      expect { Bemi::Scheduler.run }.to change { Bemi::ActionInstance.count }.by(1)

      action = Bemi::ActionInstance.order(:created_at).last
      expect(action.workflow).to eq(workflow)
      expect(action.name).to eq('create_user')
      expect(action.pending?).to eq(true)
    end

    it 'executes an async action' do
      workflow = Bemi.perform_workflow(:async_registration)
      mock_job

      Bemi::Scheduler.run
      execute_job

      action = Bemi::ActionInstance.order(:created_at).last
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
    end

    it 'schedules the next action' do
      workflow = Bemi.perform_workflow(:async_registration)
      mock_job do
        Bemi::Scheduler.run
        execute_job
      end
      mock_job

      Bemi::Scheduler.run
      action = Bemi::ActionInstance.order(:created_at).last

      expect(action.workflow).to eq(workflow)
      expect(action.name).to eq('send_welcome_email')
      expect(action.pending?).to eq(true)
    end
  end

  private

  def mock_job(&block)
    expect(Bemi::ActionJob).to receive(:perform_later)
    block&.call
  end

  def execute_job
    Bemi::ActionJob.new.perform(Bemi::ActionInstance.order(:created_at).last.id)
  end
end
