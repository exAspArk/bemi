# frozen_string_literal: true

require "json-schema"

class Bemi::Validator
  class << self
    def validate(values, schema)
      errors = JSON::Validator.fully_validate(schema, values)

      formatted_errors = errors.map do |error|
        error.
          sub(/ in schema .+\z/, ""). # remove a schema id
          sub('#/', ''). # remove a nested path
          gsub('"', "'"). # replace double quotes with single quotes
          sub("The property ''", 'The value'). # rephrase the root error
          gsub(' property ', ' field ') # replace "property" with 'field'
      end

      formatted_errors + unsupported_fields_errors(values, schema)
    end

    private

    def unsupported_fields_errors(values, schema)
      values.flat_map do |key, value|
        if schema[:properties][key].nil?
          "The field '#{key}' is not supported"
        elsif value.is_a?(Hash)
          unsupported_fields_errors(value, schema[:properties][key])
        end
      end.compact
    end
  end
end
