class AsyncRegistrationWorkflow < Bemi::Workflow
  name :async_registration

  def perform
    action :create_user, async: { queue: 'default', delay: 1.minute, priority: 10 }
    action :send_confirmation_email, wait_for: [:create_user], async: { queue: 'kyc', cron: '0 0 * * *' }, on_error: { retry: 1 }
  end
end
