# frozen_string_literal: true

class Bemi::Action
  class << self
    include Bemi::Modules::Schemable

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

  # input
  # output
  # context
  # workflow
  # wait_for
  # around_perform
  # rollback
  # around_rollback
  # concurrency_key
  # fail!
  # add_error
end
