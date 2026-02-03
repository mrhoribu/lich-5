module Lich
  module Common
    module Frontend
      module Warlock
        @file_location = nil
        @file_name = nil
        @command_line_args = " --host localhost --port %port% --key %key%"

        def self.exist?
          case Frontend.operating_system
          when :windows
            registry_path = "Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\CurrentVersion\\AppModel\\Repository\\Packages"
            possible_folder = Registry.open(Registry::HKEY_CURRENT_USER, registry_path).each_key.find { |key| key.to_s =~ /Warlock/ }[0]
            return false if possible_folder.nil?
            folder_path = Registry.open(Registry::HKEY_CURRENT_USER, "#{registry_path}\\#{possible_folder}")['PackageRootFolder']
            if File.exist?(File.join(folder_path))
              @file_location = File.join(folder_path)
              @file_name = File.join("warlock3.exe")
              return true
            end
          when :macos
            if File.exist?(File.join("/Applications/Warlock3.app/Contents/MacOS/Warlock3"))
              @file_location = File.join("/Applications/Warlock3.app/Contents/MacOS")
              @file_name = File.join("Warlock3")
              return true
            end
          when :linux
            if File.exist?(File.join("/usr/bin/warlock3"))
              @file_location = File.join("/usr/bin")
              @file_name = File.join("warlock3")
              return true
            end
          end
          return false
        end

        def self.file_location
          @file_location
        end

        def self.file_name
          @file_name
        end

        def self.command_line_args
          @command_line_args
        end
      end
    end
  end
end
