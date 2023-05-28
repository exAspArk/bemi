class ConfirmEmailAddressStep < Bemi::Step
  name :confirm_email_address

  def perform
    workflow.context[:confirmed] = true
  end
end
