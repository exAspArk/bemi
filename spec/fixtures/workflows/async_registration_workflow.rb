class AsyncRegistrationWorkflow < Bemi::Workflow
  name :async_registration

  def perform
    action :create_user, async: { queue: 'default' }
    action :send_welcome_email, wait_for: [:create_user], async: { queue: 'default' }
    action :run_background_check, wait_for: [:send_welcome_email], async: { queue: 'kyc' }
  end
end
