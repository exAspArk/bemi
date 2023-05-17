# frozen_string_literal: true

class Bemi::Workflow
  class << self
    attr_reader :workflow_name

    def name(workflow_name)
      @workflow_name = workflow_name
      Bemi::Registrator.add_workflow(workflow_name, self)
    end

    def actions
      self.new.actions
    end
  end

  def initialize
    @actions = []
  end

  def actions
    perform
    @actions
  end

  private

  def action(action_name, action_options)
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
end
