class SyncRegistrationWorkflow < Bemi::Workflow
  name :sync_registration

  concurrency limit: 2, on_conflict: :raise

  context :object do
    field :email, :string, required: true
    field :remember_me, :boolean
  end

  def perform
    step :create_user do
      sync true

      input :object do
        field :password, :string, required: true
      end

      output array: :object do
        field :id, :string
      end
    end

    step :send_confirmation_email do
      sync true
    end

    step :confirm_email_address do
      sync true
      wait_for [:send_confirmation_email]
    end
  end
end
