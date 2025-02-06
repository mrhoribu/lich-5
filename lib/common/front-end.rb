require 'tempfile'
require 'json'
require 'fileutils'
require 'rbconfig'

module Lich
  module Common
    module Frontend
      require_relative 'frontend/warlock'

      @session_file = nil
      @tmp_session_dir = File.join Dir.tmpdir, "simutronics", "sessions"
      @supports_xml = true
      @client = ""

      def self.create_session_file(name, host, port, display_session: true)
        return if name.nil?
        FileUtils.mkdir_p @tmp_session_dir
        @session_file = File.join(@tmp_session_dir, "%s.session" % name.downcase.capitalize)
        session_descriptor = { name: name, host: host, port: port }.to_json
        puts "writing session descriptor to %s\n%s" % [@session_file, session_descriptor] if display_session
        File.open(@session_file, "w") do |fd|
          fd << session_descriptor
        end
      end

      def self.session_file_location
        @session_file
      end

      def self.cleanup_session_file
        return if @session_file.nil?
        File.delete(@session_file) if File.exist? @session_file
      end

      def self.supports_xml
        @supports_xml
      end

      def self.supports_xml=(value)
        @supports_xml = value
      end

      def self.client
        @client
      end

      def self.client=(value)
        @client = value
      end

      def self.operating_system
        host_os = RbConfig::CONFIG['host_os']
        case host_os
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
          :windows
        when /darwin|mac os/
          :macos
        when /linux|solaris|bsd/
          :linux
        else
          raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
        end
      end
    end
  end
end
