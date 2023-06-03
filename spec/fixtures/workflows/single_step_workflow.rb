class SingleStepWorkflow < Bemi::Workflow
  name :single_step

  def perform
    step :confirm_email_address do
      sync true
    end
  end
end
