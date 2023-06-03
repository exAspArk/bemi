class CreateUserStep < Bemi::Step
  name :create_user

  context :object do
    field :tags, array: :string
  end

  around_perform :test_around_perform1
  around_perform :test_around_perform2

  def perform
    context[:tags] << 'perform'
    [{ id: 'id' }]
  end

  def concurrency_key
    options[:queue]
  end

  private

  def test_around_perform1(&block)
    context[:tags] ||= []
    context[:tags] << 'around_perform1'
    block.call
  end

  def test_around_perform2(&block)
    context[:tags] << 'around_perform2'
    block.call
  end
end
