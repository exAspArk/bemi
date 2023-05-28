# frozen_string_literal: true

class Bemi::Step
  CustomFailError = Class.new(StandardError)

  ON_CONFLICT_RESCHEDULE = 'reschedule'

  class << self
    include Bemi::Modules::Schemable

    attr_reader :step_name,
      :around_perform_method_names,
      :around_rollback_method_names,
      :input_schema,
      :context_schema,
      :output_schema,
      :custom_errors_schema

    def name(step_name)
      @step_name = step_name
      Bemi::Registrator.add_step(step_name, self)
    end

    def input(type, options = {}, &block)
      @input_schema = build_schema(type, options, &block)
    end

    def context(type, options = {}, &block)
      @context_schema = build_schema(type, options, &block)
    end

    def custom_errors(type, options = {}, &block)
      @custom_errors_schema = build_schema(type, options, &block)
    end

    def output(type, options = {}, &block)
      @output_schema = build_schema(type, options, &block)
    end

    def around_perform(method_name)
      @around_perform_method_names ||= []
      @around_perform_method_names << method_name
    end

    def around_rollback(method_name)
      @around_rollback_method_names ||= []
      @around_rollback_method_names << method_name
    end
  end

  attr_reader :workflow, :input, :context, :custom_errors, :output

  def initialize(workflow:, input: nil)
    @workflow = workflow
    @input = input&.freeze
    @context = {}
    @custom_errors = {}
  end

  def perform_with_around_wrappers
    perform_block = proc do
      @output = perform
    end

    self.class.around_perform_method_names&.each do |method_name|
      perform_block = send(method_name) do
        perform_block
      end
    end

    perform_block.call
  end

  def perform
    raise NotImplementedError
  end

  def rollback_with_around_wrappers
    rollback_block = proc do
      @output = rollback
    end

    self.class.around_rollback_method_names&.each do |method_name|
      rollback_block = send(method_name) do
        rollback_block
      end
    end

    rollback_block.call
  end

  def rollback
  end

  def concurrency_key
    "#{self.class.step_name}-#{input&.to_json}"
  end

  def options
    workflow.definition.fetch(:steps).find { |step| step.fetch(:name) == self.class.step_name.to_s }
  end

  def fail!
    raise Bemi::Step::CustomFailError
  end
end
