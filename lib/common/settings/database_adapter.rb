module Lich
  module Common
    # Database adapter to separate database concerns with caching
    class DatabaseAdapter
      def initialize(data_dir, table_name)
        @file = File.join(data_dir, "lich.db3")
        @db = Sequel.sqlite(@file)
        @table_name = table_name
        @cache = {}
        setup!
      end

      def setup!
        @db.create_table?(@table_name) do
          text :script
          text :scope
          blob :hash
        end
        @table = @db[@table_name]
        load_cache
      end

      def table
        @table
      end

      def get_settings(script_name, scope = ":")
        cache_key = cache_key(script_name, scope)
        return @cache[cache_key] if @cache.key?(cache_key)

        entry = @table.first(script: script_name, scope: scope)
        settings = entry.nil? ? {} : Marshal.load(entry[:hash])
        @cache[cache_key] = settings
        settings
      end

      def save_settings(script_name, settings, scope = ":")
        blob = Sequel::SQL::Blob.new(Marshal.dump(settings))
        cache_key = cache_key(script_name, scope)

        if @table.where(script: script_name, scope: scope).count > 0
          @table
            .where(script: script_name, scope: scope)
            .insert_conflict(:replace)
            .update(hash: blob)
        else
          @table.insert(
            script: script_name,
            scope: scope,
            hash: blob
          )
        end

        # Update the cache
        @cache[cache_key] = settings
      end

      private

      def cache_key(script_name, scope)
        "#{script_name}:#{scope}"
      end

      def load_cache
        @table.each do |entry|
          cache_key = cache_key(entry[:script], entry[:scope])
          @cache[cache_key] = Marshal.load(entry[:hash])
        end
      end
    end
  end
end
