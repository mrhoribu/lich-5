# Refactored Ruby-compatible Settings Implementation

module Lich
  module Common
    require 'sequel'

    require_relative 'settings/settings_proxy'
    require_relative 'settings/database_adapter'
    require_relative 'settings/path_navigator'

    module Settings
      @db_adapter = DatabaseAdapter.new(DATA_DIR, :script_auto_settings)
      @settings_cache = {}

      def self.refresh_data(scope = ":")
        # Requests made directly to this method want a refreshed set of data.
        # Aliased to Settings.load for backwards compatibility.
        script_name = Script.current.name
        cache_key = "#{script_name}::#{scope}"
        
        # Get from database and update cache
        @settings_cache[cache_key] = @db_adapter.get_settings(script_name, scope)
      end

      def self.[](scope = ":", name)
        script_name = Script.current.name
        cache_key = "#{script_name}::#{scope}"
        
        unless @settings_cache[cache_key]
          @settings_cache[cache_key] = @db_adapter.get_settings(script_name, scope)
        end
        @settings_cache[cache_key][name]
      end

      def self.[]=(scope = ":", name, value)
        script_name = Script.current.name
        cache_key = "#{script_name}::#{scope}"

        unless @settings_cache[cache_key][name] == value
          @settings_cache[cache_key] ||= Hash.new
          @settings_cache[cache_key][name] = value
          @db_adapter.save_settings(script_name, @settings_cache[cache_key], scope)
        end

        return @settings_cache[cache_key][name]
      end

      def self.to_h(scope = ":")
        # Return unwrapped hash
        script_name = Script.current.name
        cache_key = "#{script_name}::#{scope}"
        
        # Get from database and update cache
        @settings_cache[cache_key] = @db_adapter.get_settings(script_name, scope)
      end

      def self.to_hash(scope = ":")
        # Return unwrapped hash
        script_name = Script.current.name
        cache_key = "#{script_name}::#{scope}"
        
        # Get from database and update cache
        @settings_cache[cache_key] = @db_adapter.get_settings(script_name, scope)
      end

      def self.save
        # :noop
      end

      def self.load # pulled from Deprecated calls to alias to refresh_data()
        refresh_data()
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
