class AsyncRegistrationWorkflow < Bemi::Workflow
  name :async_registration

  def perform
    step :create_user, async: { queue: 'default', delay: 1.minute, priority: 10 }, concurrency: { limit: 1, on_conflict: :reschedule }
    step :send_confirmation_email, wait_for: [:create_user], async: { queue: 'kyc', cron: '0 0 * * *' }, on_error: { retry: 1 }
  end
end
