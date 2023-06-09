# frozen_string_literal: true

module Bemi::Modules
  module Schemable
    def build_schema(type, options, &block)
      @schema_acc = {}
      block&.call

      if array_type?(type)
        schema_type(type).merge(options).deep_merge(items: @schema_acc)
      else
        schema_type(type).merge(options).merge(@schema_acc)
      end
    end

    def field(name, type, options = {})
      @schema_acc[:properties] ||= {}
      @schema_acc[:properties][name] = schema_type(type).merge(options.except(:required))
      return if !options[:required]

      @schema_acc[:required] ||= []
      @schema_acc[:required] << name.to_s
    end

    private

    def array_type?(type)
      type.is_a?(Hash) && type.fetch(:array)
    end

    def schema_type(type)
      if array_type?(type)
        { type: 'array', items: { type: type.fetch(:array).to_s } }
      else
        { type: type.to_s }
      end
    end
  end
end
