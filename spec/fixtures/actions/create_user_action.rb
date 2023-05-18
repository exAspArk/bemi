class CreateUserAction < Bemi::Action
  name :create_user

  input :object do
    field :password, :string, required: true
  end

  context :object do
    field :tags, array: :string
  end

  output array: :object do
    field :attribute, :string
  end

  around_perform :test_around_perform
  around_rollback :test_around_rollback

  private

  def test_around_perform(&block)
    block.call
  end

  def test_around_rollback(&block)
    block.call
  end
end
