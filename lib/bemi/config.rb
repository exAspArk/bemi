# frozen_string_literal: true

class Bemi::Config
  InvalidConfigurationError = Class.new(StandardError)

  CONFIGURATION_SCHEMA = {
    type: :object,
    properties: {
      storage_adapter: {
        type: :string,
        enum: %i[active_record],
      },
      storage_parent_class: {
        type: :string,
      },
      background_job_adapter: {
        type: :string,
        enum: %i[active_job],
      },
      background_job_parent_class: {
        type: :string,
      },
    },
    required: %i[storage_adapter storage_parent_class background_job_adapter background_job_parent_class],
  }

  STORAGE_ADAPTER_ACTIVE_RECORD = :active_record

  DEFAULT_STORAGE_ADAPTER = STORAGE_ADAPTER_ACTIVE_RECORD
  DEFAULT_STORAGE_PARENT_CLASS = 'ActiveRecord::Base'

  BACKGROUND_JOB_ADAPTER_ACTIVE_JOB = :active_job
  DEFAULT_BACKGROUND_JOB_ADAPTER = BACKGROUND_JOB_ADAPTER_ACTIVE_JOB
  DEFAULT_BACKGROUND_JOB_PARENT_CLASS = 'ActiveJob::Base'

  class << self
    def configure(&block)
      block.call(self)
      Bemi::Scheduler.daemonize
    end

    def storage_adapter=(storage_adapter)
      self.configuration[:storage_adapter] = storage_adapter
      validate_configuration!
    end

    def storage_parent_class=(storage_parent_class)
      self.configuration[:storage_parent_class] = storage_parent_class
      validate_configuration!
    end

    def background_job_adapter=(background_job_adapter)
      self.configuration[:background_job_adapter] = background_job_adapter
      validate_configuration!
    end

    def background_job_parent_class=(background_job_parent_class)
      self.configuration[:background_job_parent_class] = background_job_parent_class
      validate_configuration!
    end

    def configuration
      @configuration ||= {
        storage_adapter: DEFAULT_STORAGE_ADAPTER,
        storage_parent_class: DEFAULT_STORAGE_PARENT_CLASS,
        background_job_adapter: DEFAULT_BACKGROUND_JOB_ADAPTER,
        background_job_parent_class: DEFAULT_BACKGROUND_JOB_PARENT_CLASS,
      }
    end

    private

    def validate_configuration!
      errors = Bemi::Validator.validate(configuration, CONFIGURATION_SCHEMA)
      raise Bemi::Config::InvalidConfigurationError, errors.first if errors.any?
    end
  end
end
