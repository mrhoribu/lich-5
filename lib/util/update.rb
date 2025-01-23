## Let's have fun updating Lich5!

module Lich
  module Util
    module Update
      module Opts
        require 'ostruct'
        
        FLAG_PREFIX    = "--"
    
        def self.parse_command(h, c)
          h[c.to_sym] = true
        end

        def self.parse_flag(h, f)
          (name, val) = f[2..-1].split("=")
          if val.nil?
            h[name.to_sym] = true
          else
            val = val.split(",")

            h[name.to_sym] = val.size == 1 ? val.first : val
          end
        end

        def self.parse(args = Script.current.vars[1..-1])        
          OpenStruct.new(**args.to_a.reduce(Hash.new) do |opts, v|
            if v.start_with?(FLAG_PREFIX)
              Opts.parse_flag(opts, v)
            else
              Opts.parse_command(opts, v)
            end
            opts
          end)
        end

        def self.method_missing(method, *args)
          parse.send(method, *args)
        end
      end

      require 'json'
      require 'open-uri'
      require 'rubygems/package'
      require 'zlib'

      @current = LICH_VERSION
      @snapshot_core_script = ["alias.lic", "autostart.lic", "dependency.lic", "ewaggle.lic", "foreach.lic", "go2.lic", "infomon.lic",
                               "jinx.lic", "lnet.lic", "log.lic", "logxml.lic", "map.lic", "repository.lic", "vars.lic", "version.lic"]

      def self.request(type = '--announce')
        case type
        when /--announce|-a/
          self.announce
        when /--(?:beta|test)(?: --(?:(script|library|data))=(.*))?/
          self.prep_betatest($1.dup, $2.dup)
        when /--help|-h/
          self.help # Ok, that's just wrong.
        when /--update|-u/
          self.download_update
        when /--refresh/
          _respond; _respond "This command has been removed."
        when /--revert|-r/
          self.revert
        when /--(?:(script|library|data))=(.*)/
          self.update_file($1.dup, $2.dup)
        when /--snapshot|-s/ # this one needs to be after --script
          self.snapshot
        else
          _respond; _respond "Command '#{type}' unknown, illegitimate and ignored.  Exiting . . ."; _respond
        end
      end

      def self.announce
        self.prep_update
        if "#{LICH_VERSION}".chr == '5'
          if Gem::Version.new(@current) < Gem::Version.new(@update_to)
            if !@new_features.empty?
              _respond ''; _respond monsterbold_start() + "*** NEW VERSION AVAILABLE ***" + monsterbold_end()
              _respond ''; _respond ''
              _respond ''; _respond @new_features
              _respond ''
              _respond ''; _respond "If you are interested in updating, run ';lich5-update --update' now."
              _respond ''
            end
          else
            _respond ''; _respond "Lich version #{LICH_VERSION} is good.  Enjoy!"; _respond ''
          end
        else
          # lich version 4 - just say 'no'
          _respond "This script does not support Lich #{LICH_VERSION}."
        end
      end

      def self.help
        _respond "
    --help                   Display this message
    --announce               Get summary of changes for next version
    --update                 Update all changes for next version
    --snapshot               Grab current snapshot of Lich5 ecosystem and put in backup
    --revert                 Roll the Lich5 ecosystem back to the most recent snapshot

  Example usage:

  [One time suggestions]
    ;autostart add --global lich5-update --announce    Check for new version at login
    ;autostart add --global lich5-update --update      To auto accept all updates at login

  [On demand suggestions]
    ;lich5-update --announce                  Check to see if a new version is available
    ;lich5-update --update                    Update the Lich5 ecosystem to the current release
    ;lich5-update --revert                    Roll the Lich5 ecosystem back to latest snapshot
    ;lich5-update --script=<NAME>             Update an individual script file found in Lich-5
    ;lich5-update --library=<NAME>            Update an individual library file found in Lich-5
    ;lich5-update --data=<NAME>               Update an individual data file found in Lich-5

    *NOTE* If you use '--snapshot' in ';autostart' you will create a new
                snapshot folder every time you log a character in.  NOT recommended.
    "
      end

      def self.snapshot
        _respond
        _respond 'Creating a snapshot of current Lich core files ONLY.'
        _respond
        _respond 'You may also wish to copy your entire Lich5 folder to'
        _respond 'another location for additional safety, after any'
        _respond 'additional requested updates are completed.'

        ## Let's make the snapshot folder

        snapshot_subdir = File.join(BACKUP_DIR, "L5-snapshot-#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}")
        FileUtils.mkdir_p(snapshot_subdir)

        ## lich.rbw main file backup

        FileUtils.cp(File.join(LICH_DIR, File.basename($PROGRAM_NAME)), File.join(snapshot_subdir, File.basename($PROGRAM_NAME)))

        ## LIB folder backup and it's subfolders

        FileUtils.mkdir_p(File.join(snapshot_subdir, "lib"))
        FileUtils.cp_r(LIB_DIR, snapshot_subdir)

        ## here we should maintain a discrete array of script files (450K versus 10M plus)
        ## we need to find a better way without hving to maintain this list

        FileUtils.mkdir_p(File.join(snapshot_subdir, "scripts"))
        @snapshot_core_script.each { |file|
          FileUtils.cp(File.join(SCRIPT_DIR, file), File.join(snapshot_subdir, "scripts", file)) if File.exist?(File.join(SCRIPT_DIR, file))
        }

        _respond
        _respond 'Current Lich ecosystem files (only) backed up to:'
        _respond "    #{snapshot_subdir}"
      end

      def self.prep_betatest(type = nil, requested_file = nil)
        if type.nil?
          respond 'You are electing to participate in the beta testing of the next Lich release.'
          respond 'This beta test will include only Lich code, and does not include Ruby upates.'
          respond 'While we will do everything we can to ensure you have a smooth experience, '
          respond 'it is a test, and untoward things can result.  Please confirm your choice:'
          respond 'Please confirm your participation:  ;send Y or ;send N'
          # we are only going to get the next client-input line, and if it does not confirm, we bail
          # we are doing this to prevent hanging the client with various other inputs by the user
          sync_thread = $_CLIENT_ || $_DETACHABLE_CLIENT_
          line = sync_thread.gets until line.strip =~ /^(?:<c>)?(?:;send|;s) /i
          if line =~ /send Y|s Y/i
            @beta_response = 'accepted'
            respond 'Beta test installation accepted.  Thank you for considering!'
          else
            @beta_response = 'rejected'
            respond 'Aborting beta test installation request.  Thank you for considering!'
            respond
          end
          if @beta_response =~ /accepted/
            filename = "https://api.github.com/repos/elanthia-online/lich-5/releases"
            update_info = URI.parse(filename).open.read
            record = JSON::parse(update_info).first # assumption: Latest beta release always first record in API
            record.each { |entry, value|
              if entry.include? 'tag_name'
                @update_to = value.sub('v', '')
              elsif entry.include? 'assets'
                @holder = value
              elsif entry.include? 'body'
                @new_features = value.gsub(/\#\# What's Changed.+$/m, '')
              end
            }
            beta_asset = @holder.find { |x| x['name'] =~ /lich-5.tar.gz/ }
            @zipfile = beta_asset.fetch('browser_download_url')
            Lich::Util::Update.download_update
          elsif @beta_response =~ /rejected/
            nil
          else
            respond 'This is not where I want to be on a beta test request.'
            respond
          end
        else
          self.update_file(type, requested_file, 'beta')
        end
      end

      def self.prep_update
        filename = "https://api.github.com/repos/elanthia-online/lich-5/releases/latest"
        update_info = URI.parse(filename).open.read

        JSON::parse(update_info).each { |entry, value|
          if entry.include? 'tag_name'
            @update_to = value.sub('v', '')
          elsif entry.include? 'assets'
            @holder = value
          elsif entry.include? 'body'
            @new_features = value.gsub(/\#\# What's Changed.+$/m, '')
          end
        }
        release_asset = @holder.find { |x| x['name'] =~ /lich-5.tar.gz/ }
        @zipfile = release_asset.fetch('browser_download_url')
      end

      def self.download_update
        ## This is the workhorse routine that does the file moves from an update
        self.prep_update if @update_to.nil? or @update_to.empty?
        if Gem::Version.new("#{@update_to}") <= Gem::Version.new("#{@current}")
          _respond ''; _respond "Lich version #{LICH_VERSION} is good.  Enjoy!"; _respond ''
        else
          _respond; _respond 'Getting reaady to update.  First we will create a'
          _respond 'snapshot in case there are problems with the update.'

          self.snapshot

          # download the requested update (can be prod release, or beta)
          _respond; _respond "Downloading Lich5 version #{@update_to}"; _respond
          filename = "lich5-#{@update_to}"
          File.open(File.join(TEMP_DIR, "#{filename}.tar.gz"), "wb") do |file|
            file.write URI.parse(@zipfile).open.read
          end

          # unpack and prepare to use the requested update
          FileUtils.mkdir_p(File.join(TEMP_DIR, filename))
          Gem::Package.new("").extract_tar_gz(File.open(File.join(TEMP_DIR, "#{filename}.tar.gz"), "rb"), File.join(TEMP_DIR, filename))
          new_target = Dir.children(File.join(TEMP_DIR, filename))
          FileUtils.cp_r(File.join(TEMP_DIR, filename, new_target[0]), TEMP_DIR)
          FileUtils.remove_dir(File.join(TEMP_DIR, filename))
          FileUtils.mv(File.join(TEMP_DIR, new_target[0]), File.join(TEMP_DIR, filename))

          # delete all existing lib files to not leave old ones behind
          FileUtils.rm_f(Dir.glob(File.join(LIB_DIR, "*")))

          _respond; _respond 'Copying updated lich files to their locations.'

          ## We do not care about local edits from players in the Lich5 / lib location
          FileUtils.copy_entry(File.join(TEMP_DIR, filename, "lib"), File.join(LIB_DIR))
          _respond; _respond "All Lich lib files have been updated."; _respond

          ## Use new method so can be reused to do a blanket update of core data & scripts
          self.update_core_data_and_scripts(@update_to)

          ## Finally we move the lich.rbw file into place to complete the update.  We do
          ## not need to save a copy of this in the TEMP_DIR as previously done, since we
          ## took the snapshot at the beginning.
          lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
          update_to_lich = File.join(TEMP_DIR, filename, "lich.rbw")
          File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }

          ## And we clen up after ourselves
          FileUtils.remove_dir(File.join(TEMP_DIR, filename)) # we know these exist because
          FileUtils.rm(File.join(TEMP_DIR, "#{filename}.tar.gz")) # we just processed them

          _respond; _respond "Lich5 has been updated to Lich5 version #{@update_to}"
          _respond "You should exit the game, then log back in.  This will start the game"
          _respond "with your updated Lich.  Enjoy!"
        end
      end

      def self.revert
        ## Since the request is to roll-back, we will do so destructively
        ## without another snapshot and without worrying about saving files
        ## that can be reinstalled with the lich5-update --update command

        _respond; _respond 'Reverting Lich5 to previously installed version.'
        revert_array = Dir.glob(File.join(BACKUP_DIR, "*")).sort.reverse
        restore_snapshot = revert_array[0]
        if restore_snapshot.empty? or /L5-snapshot/ !~ restore_snapshot
          _respond "No prior Lich5 version found. Seek assistance."
        else
          # delete all lib files
          FileUtils.rm_f(Dir.glob(File.join(LIB_DIR, "*")))
          # copy all backed up lib files
          FileUtils.cp_r(File.join(restore_snapshot, "lib", "."), LIB_DIR)
          # delete array of core scripts
          @snapshot_core_script.each { |file|
            File.delete(File.join(SCRIPT_DIR, file)) if File.exist?(File.join(SCRIPT_DIR, file))
          }
          # copy all backed up core scripts (array to save, only array files in backup)
          FileUtils.cp_r(File.join(restore_snapshot, "scripts", "."), SCRIPT_DIR)

          # skip gameobj-data and spell-list (non-functional logically, previous versions
          # already present and current files may contain local edits)

          # update lich.rbw in stream because it is active (we hope)
          lich_to_update = File.join(LICH_DIR, File.basename($PROGRAM_NAME))
          update_to_lich = File.join(restore_snapshot, "lich.rbw")
          File.open(update_to_lich, 'rb') { |r| File.open(lich_to_update, 'wb') { |w| w.write(r.read) } }

          # as a courtesy to the player, remind which version they were rev'd back to
          targetversion = ''
          targetfile = File.open(File.join(LIB_DIR, "version.rb")).read
          targetfile.each_line do |line|
            if line =~ /LICH_VERSION\s+?=\s+?/
              targetversion = line.sub(/LICH_VERSION\s+?=\s+?/, '').sub('"', '')
            end
          end
          _respond
          _respond "Lich5 has been reverted to Lich5 version #{targetversion}"
          _respond "You should exit the game, then log back in.  This will start the game"
          _respond "with your previous version of Lich.  Enjoy!"
        end
      end

      def self.update_file(type, rf, version = 'production')
        requested_file = rf
        case type
        when "script"
          location = SCRIPT_DIR
          if requested_file.downcase == 'dependency.lic'
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/dr-scripts/main"
          else
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
          end
          requested_file =~ /\.lic$/ ? requested_file_ext = ".lic" : requested_file_ext = "bad extension"
        when "library"
          location = LIB_DIR
          case version
          when "production"
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/lich-5/master/lib"
          when "beta"
            remote_repo = "https://raw.githubusercontent.com/elanthia-online/lich-5/staging/lib"
          end
          requested_file =~ /\.rb$/ ? requested_file_ext = ".rb" : requested_file_ext = "bad extension"
        when "data"
          location = DATA_DIR
          remote_repo = "https://raw.githubusercontent.com/elanthia-online/scripts/master/scripts"
          requested_file =~ /(\.(?:xml|ui))$/ ? requested_file_ext = $1.dup : requested_file_ext = "bad extension"
        end
        unless requested_file_ext == "bad extension"
          File.delete(File.join(location, requested_file)) if File.exist?(File.join(location, requested_file))
          begin
            File.open(File.join(location, requested_file), "wb") do |file|
              file.write URI.parse(File.join(remote_repo, requested_file)).open.read
            end
            _respond
            _respond "#{requested_file} has been updated."
          rescue
            # we created a garbage file (zero bytes filename) so let's clean it up and inform.
            sleep 1
            File.delete(File.join(location, requested_file)) if File.exist?(File.join(location, requested_file))
            _respond; _respond "The filename #{requested_file} is not available via lich5-update."
            _respond "Check the spelling of your requested file, or use ';jinx' to"
            _respond "to download #{requested_file} from another respository."
          end
        else
          _respond
          _respond "The requested file #{requested_file} has an incorrect extension."
          _respond "Valid extensions are '.lic' for scripts, '.rb' for library files,"
          _respond "and '.xml' or '.ui' for data files. Please correct and try again."
        end
      end

      def self.update_core_data_and_scripts(version = LICH_VERSION)
        if XMLData.game !~ /^GS|^DR/
          _respond "invalid game type, unsure what scripts to update via Update.update_core_scripts"
          return
        end

        updatable_scripts = {
          "all" => ["alias.lic", "autostart.lic", "go2.lic", "jinx.lic", "log.lic", "logxml.lic", "map.lic", "repository.lic", "vars.lic", "version.lic"],
          "gs"  => ["ewaggle.lic", "foreach.lic"],
          "dr"  => ["dependency.lic"]
        }

        ## We DO care about local edits from players to the Lich5 / data files
        ## specifically gameobj-data.xml and spell-list.xml.
        ## Let's be a little more purposeful and gentle with these two files.
        ["effect-list.xml"].each { |file|
          transition_filename = "#{file}".sub(".xml", '')
          newfilename = File.join(DATA_DIR, "#{transition_filename}-#{Time.now.to_i}.xml")
          if File.exist?(File.join(DATA_DIR, file))
            File.open(File.join(DATA_DIR, file), 'rb') { |r| File.open(newfilename, 'wb') { |w| w.write(r.read) } }
            _respond "The prior version of #{file} was renamed to #{newfilename}."
          end
          self.update_file('data', file)
        }

        ## We do not care about local edits from players to the Lich5 / script location
        ## for CORE scripts (those required to run Lich5 properly)
        updatable_scripts["all"].each { |script| self.update_file('script', script) }
        updatable_scripts["gs"].each { |script| self.update_file('script', script) } if XMLData.game =~ /^GS/
        updatable_scripts["dr"].each { |script| self.update_file('script', script) } if XMLData.game =~ /^DR/

        ## Update Lich.db value with last updated version
        Lich.core_updated_with_lich_version = version
      end
      # End module definitions
    end
  end
end
