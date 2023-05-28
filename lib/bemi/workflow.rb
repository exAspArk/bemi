# frozen_string_literal: true

class Bemi::Workflow
  InvalidConcurrencyOptionError = Class.new(StandardError)
  InvalidStepDefinitionError = Class.new(StandardError)

  ON_CONFLICT_RAISE = 'raise'
  ON_CONFLICT_REJECT = 'reject'

  CONCURRENCY_SCHEMA = {
    type: :object,
    properties: {
      limit: { type: :integer, minimum: 1 },
      on_conflict: { type: :string, enum: %i[raise reject] },
    },
    required: %i[limit on_conflict],
  }

  STEP_SCHEMA = {
    type: :object,
    properties: {
      sync: { type: :boolean },
      async: {
        type: :object,
        properties: {
          queue: { type: :string },
          priority: { type: :integer, minimum: 0 },
          delay: { type: :integer, minimum: 0 },
          cron: { type: :string },
        },
        required: %i[queue],
      },
      wait_for: {
        type: :array,
        items: { type: :string },
      },
      on_error: {
        type: :object,
        properties: {
          retry: { type: :integer, minimum: 0 },
        },
        required: %i[retry],
      },
      concurrency: {
        type: :object,
        properties: {
          limit: { type: :integer, minimum: 1 },
          on_conflict: { type: :string, enum: %i[reschedule] },
        },
        required: %i[limit on_conflict],
      },
    },
  }

  class << self
    include Bemi::Modules::Schemable

    def name(workflow_name)
      @workflow_name = workflow_name
      Bemi::Registrator.add_workflow(workflow_name, self)
    end

    def concurrency(concurrency_options)
      validate_concurrency_options!(concurrency_options)

      @concurrency_options = concurrency_options.merge(
        on_conflict: concurrency_options.fetch(:on_conflict).to_s,
      )
    end

    def context(type, options = {}, &block)
      @context_schema = build_schema(type, options, &block)
    end

    def definition
      {
        name: @workflow_name.to_s,
        steps: steps,
        concurrency: @concurrency_options,
        context_schema: @context_schema,
      }
    end

    private

    def steps
      self.new.steps
    end

    def validate_concurrency_options!(concurrency_options)
      errors = Bemi::Validator.validate(concurrency_options, CONCURRENCY_SCHEMA)
      raise Bemi::Workflow::InvalidConcurrencyOptionError, errors.first if errors.any?
    end
  end

  def initialize
    @steps = []
  end

  def steps
    perform
    @steps
  end

  def perform
    raise NotImplementedError
  end

  private

  def step(step_name, step_options)
    validate_step_options!(step_name, step_options)

    @steps << {
      name: step_name.to_s,
      sync: step_options[:sync],
      wait_for: step_options[:wait_for]&.map(&:to_s),
      async: step_options[:async],
      on_error: step_options[:on_error],
      concurrency: step_options[:concurrency],
    }
  end

  def validate_step_options!(step_name, step_options)
    errors = Bemi::Validator.validate(step_options, STEP_SCHEMA)
    raise Bemi::Workflow::InvalidStepDefinitionError, errors.first if errors.any?

    if step_options[:sync].nil? && step_options[:async].nil?
      raise Bemi::Workflow::InvalidStepDefinitionError, "Step '#{step_name}' must be either 'sync' or 'async'"
    end

    if step_options[:wait_for]
      unknown_step_names = step_options.fetch(:wait_for).select { |step_name| @steps.none? { |step| step.fetch(:name) == step_name.to_s } }
      return if unknown_step_names.empty?

      raise Bemi::Workflow::InvalidStepDefinitionError, "Step '#{step_name}' waits for unknown step names: #{unknown_step_names.map { |a| "'#{a}'" }.join(', ')}"
    end
  end
end
