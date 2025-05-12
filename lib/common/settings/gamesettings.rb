# Refactored Ruby-compatible Settings Implementation

module Lich
  module Common
    require 'sequel'
    require_relative 'settings/database_adapter'

    module Settings
      @db_adapter = DatabaseAdapter.new(DATA_DIR, :script_auto_settings)
      @settings_cache = {}

      def self.[](scope = ":", name)
        script_name = Script.current.name
        @db_adapter.get_settings(script_name, scope)[name]
      end

      def self.[]=(scope = ":", name, value)
        script_name = Script.current.name
        settings = @db_adapter.get_settings(script_name, scope)
        settings[name] = value
        @db_adapter.save_settings(script_name, settings, scope)
        return settings[name]
      end

      def self.to_h(scope = ":")
        script_name = Script.current.name
        @db_adapter.get_settings(script_name, scope)
      end

      def self.to_hash(scope = ":")
        script_name = Script.current.name
        @db_adapter.get_settings(script_name, scope)
      end

      def self.save
        # :noop
      end

      # Deprecated calls
      def Settings.save_all
        Lich.deprecated('Settings.save_all', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def Settings.clear
        Lich.deprecated('Settings.clear', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def Settings.auto=(_val)
        Lich.deprecated('Settings.auto=(val)', 'not using, not applicable,', caller[0], fe_log: true)
      end

      def Settings.auto
        Lich.deprecated('Settings.auto', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def Settings.autoload
        Lich.deprecated('Settings.autoload', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end
    end
  end
end
# This code is a refactored Sequel based version of the original Lich settings implementation.
