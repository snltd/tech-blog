# frozen_string_literal: true

require 'pathname'

def locate_config_ru
  Pathname.new(__dir__).parent + 'config.ru'
end
