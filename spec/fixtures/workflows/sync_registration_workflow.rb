class SyncRegistrationWorkflow < Bemi::Workflow
  name :sync_registration

  concurrency limit: 1, on_conflict: :raise

  def perform
    action :create_user, sync: true
    action :send_confirmation_email, sync: true
    action :confirm_email_address, sync: true
  end
end