# frozen_string_literal: true

class Bemi::Action
  class << self
    include Bemi::Modules::Schemable

    attr_reader :around_perform_method_names, :input_schema, :context_schema, :output_schema

    def name(action_name)
      @action_name = action_name
      Bemi::Registrator.add_action(action_name, self)
    end

    def input(type, options = {}, &block)
      @input_schema = build_schema(type, options, &block)
    end

    def context(type, options = {}, &block)
      @context_schema = build_schema(type, options, &block)
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

  attr_reader :workflow, :input, :context, :output, :rollback_output

  def initialize(workflow:, input:)
    @workflow = workflow
    @input = input.freeze
    @context = {}
  end

  def perform_with_callbacks
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

  # TODO: rollback
  def rollback
  end

  # wait_for
  # around_rollback
  # concurrency_key
  # fail!
  # add_error
end
