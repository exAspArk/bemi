class SyncRegistrationWorkflow < Bemi::Workflow
  name :sync_registration

  concurrency limit: 2, on_conflict: :raise

  context :object do
    field :email, :string, required: true
    field :remember_me, :boolean
  end

  def perform
    action :create_user, sync: true
    action :send_confirmation_email, sync: true
    action :confirm_email_address, sync: true, wait_for: [:send_confirmation_email]
  end
end
