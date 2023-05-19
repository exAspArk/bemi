class SendConfirmationEmailAction < Bemi::Action
  name :send_confirmation_email

  around_rollback :test_around_rollback

  custom_errors :object do
    field :email, :string
  end

  def perform
    context[:email] = workflow.context[:email]
    custom_errors[:email] = "Invalid email: #{context[:email]}"
    fail!
  end

  def rollback
    context[:rollbacked] = true
  end

  def test_around_rollback(&block)
    context[:around_rollbacked] = true
    block.call
  end
end
