class SingleActionWorkflow < Bemi::Workflow
  name :single_action

  def perform
    action :confirm_email_address, sync: true
  end
end
