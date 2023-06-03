class AsyncRegistrationWorkflow < Bemi::Workflow
  name :async_registration

  def perform
    step :create_user do
      async queue: 'default', delay: 1.minute, priority: 10
      concurrency limit: 1, on_conflict: :reschedule

      input :object do
        field :password, :string, required: true
      end

      output array: :object do
        field :id, :string
      end
    end

    step :send_confirmation_email do
      wait_for [:create_user]
      async queue: 'kyc', cron: '0 0 * * *'
      on_error retry: 1
    end
  end
end
