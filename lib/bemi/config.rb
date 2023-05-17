# frozen_string_literal: true

Bemi::UnsupportedStorageError = Class.new(StandardError)

class Bemi::Config
  SUPPORTED_STORAGES = %i[memory active_record].freeze
  DEFAULT_STORAGE = :active_record

  class << self
    attr_reader :storage

    def configure(&block)
      self.storage = DEFAULT_STORAGE

      block.call(self)
    end

    def storage=(storage)
      if !SUPPORTED_STORAGES.include?(storage)
        raise Bemi::UnsupportedStorageError, "Unsupported storage option '#{storage}'"
      end

      @storage = storage
    end
  end
end
