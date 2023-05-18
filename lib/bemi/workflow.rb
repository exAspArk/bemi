# frozen_string_literal: true

class Bemi::Workflow
  InvalidConcurrencyOptionError = Class.new(StandardError)
  InvalidActionDefinitionError = Class.new(StandardError)

  CONCURRENCY_SCHEMA = {
    type: :object,
    properties: {
      limit: { type: :integer, minimum: 1 },
      on_conflict: { type: :string, enum: %i[raise reject] },
    },
    required: %i[limit on_conflict],
  }

  ACTION_SCHEMA = {
    type: :object,
    properties: {
      sync: { type: :boolean },
      async: {
        type: %i[boolean object],
        properties: {
          queue: { type: :string },
          priority: { type: :integer, minimum: 0 },
          delay: { type: :integer, minimum: 0 },
          cron: { type: :string },
        },
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
      },
    },
  }

  class << self
    attr_reader :workflow_name, :concurrency_options

    def name(workflow_name)
      @workflow_name = workflow_name
      @concurrency_options = {}

      Bemi::Registrator.add_workflow(workflow_name, self)
    end

    def concurrency(concurrency_options)
      validate_concurrency_options!(concurrency_options)
      @concurrency_options = concurrency_options
    end

    def actions
      self.new.actions
    end

    private

    def validate_concurrency_options!(concurrency_options)
      errors = Bemi::Validator.validate(concurrency_options, CONCURRENCY_SCHEMA)
      raise Bemi::Workflow::InvalidConcurrencyOptionError, errors.first if errors.any?
    end
  end

  def initialize
    @actions = []
  end

  def actions
    perform
    @actions
  end

  def perform
    raise NotImplementedError
  end

  private

  def action(action_name, action_options)
    validate_action_options!(action_name, action_options)

    execution =
      if action_options[:sync]
        'sync'
      elsif action_options[:async]
        'async'
      end

    @actions << {
      name: action_name.to_s,
      execution: execution,
      wait_for: action_options[:wait_for] || [],
      async: action_options[:async].is_a?(Hash) ? action_options[:async] : {},
      on_error: action_options[:on_error] || {},
      concurrency: action_options[:concurrency] || {},
      input_schema: action_options[:input_schema] || {},
      output_schema: action_options[:output_schema] || {},
    }
  end

  def validate_action_options!(action_name, action_options)
    errors = Bemi::Validator.validate(action_options, ACTION_SCHEMA)
    raise Bemi::Workflow::InvalidActionDefinitionError, errors.first if errors.any?

    if action_options[:sync].nil? && action_options[:async].nil?
      raise Bemi::Workflow::InvalidActionDefinitionError, "Action '#{action_name}' must be either 'sync' or 'async'"
    end

    if action_options[:wait_for]
      unknown_action_names = action_options[:wait_for].select { |action_name| @actions.none? { |action| action[:name] == action_name.to_s } }
      return if unknown_action_names.empty?

      raise Bemi::Workflow::InvalidActionDefinitionError, "Action '#{action_name}' waits for unknown action names: #{unknown_action_names.map { |a| "'#{a}'" }.join(', ')}"
    end
  end
end
