# frozen_string_literal: true

class Bemi::Config
  InvalidConfigurationError = Class.new(StandardError)

  CONFIGURATION_SCHEMA = {
    type: :object,
    properties: {
      storage: {
        type: :string,
        enum: %i[memory active_record],
      },
    },
    required: %i[storage],
  }

  class << self
    def configure(&block)
      block.call(self)
    end

    def storage=(storage)
      self.configuration[:storage] = storage
      validate_configuration!
    end

    def configuration
      @configuration ||= {}
    end

    private

    def validate_configuration!
      errors = Bemi::Validator.validate(configuration, CONFIGURATION_SCHEMA)
      raise Bemi::Config::InvalidConfigurationError, errors.first if errors.any?
    end
  end
end
