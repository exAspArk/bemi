# frozen_string_literal: true

class Bemi::Config
  InvalidConfigurationError = Class.new(StandardError)

  CONFIGURATION_SCHEMA = {
    type: :object,
    properties: {
      storage_type: {
        type: :string,
        enum: %i[active_record],
      },
      storage_parent_class: {
        type: :string,
      },
    },
    required: %i[storage_type storage_parent_class],
  }

  DEFAULT_STORAGE_TYPE = :active_record
  DEFAULT_STORAGE_PARENT_CLASS = 'ActiveRecord::Base'

  class << self
    def configure(&block)
      block.call(self)
    end

    def storage_type=(storage_type)
      self.configuration[:storage_type] = storage_type
      validate_configuration!
    end

    def storage_parent_class=(storage_parent_class)
      self.configuration[:storage_parent_class] = storage_parent_class
      validate_configuration!
    end

    def configuration
      @configuration ||= {
        storage_type: DEFAULT_STORAGE_TYPE,
        storage_parent_class: DEFAULT_STORAGE_PARENT_CLASS,
      }
    end

    private

    def validate_configuration!
      errors = Bemi::Validator.validate(configuration, CONFIGURATION_SCHEMA)
      raise Bemi::Config::InvalidConfigurationError, errors.first if errors.any?
    end
  end
end
