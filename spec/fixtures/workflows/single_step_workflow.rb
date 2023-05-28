class SingleStepWorkflow < Bemi::Workflow
  name :single_step

  def perform
    step :confirm_email_address, sync: true
  end
end
