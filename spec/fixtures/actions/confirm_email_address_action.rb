class SendConfirmationEmailAction < Bemi::Action
  name :confirm_email_address

  def perform
    workflow.context[:confirmed] = true
  end
end
