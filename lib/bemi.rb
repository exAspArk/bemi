# frozen_string_literal: true

require_relative 'bemi/adapters/abstract'
require_relative 'bemi/adapters/memory'
require_relative 'bemi/config'
require_relative 'bemi/registrator'
require_relative 'bemi/storage'
require_relative 'bemi/version'
require_relative 'bemi/workflow'

class Bemi
  class << self
    def configure(&block)
      Bemi::Config.configure(&block)
    end
  end
end
