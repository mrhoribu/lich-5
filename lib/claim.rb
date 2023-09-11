module Claim
  Lock            = Mutex.new
  @claimed_room ||= nil
  @mine         ||= false
  @buffer         = []
  @others         = []
  @timestamp      = Time.now

  def self.claim_room(id)
    @claimed_room = id.to_i
    @timestamp    = Time.now
    if defined? Log
      Log.out("claimed #{@claimed_room}", label: %i(claim room))
    else
      respond "claimed #{@claimed_room}"
    end
    Lock.unlock
  end

  def self.claimed_room
    @claimed_room
  end

  def self.current?
    Lock.synchronize { @mine.eql?(true) }
  end

  def self.mine?
    self.current?
  end

  def self.others
    @others
  end

  def self.members
    return [] unless defined? Group

    if Group.checked?
      Group.members.map(&:noun)
    else
      []
    end
  end

  def self.clustered
    return [] unless defined? Cluster
    Cluster.connected
  end

  def self.handle_room
    begin
      lines = @buffer.dup
      @buffer = []
      room_xml = lines.join("\n").gsub("room players", "room-players")
      visible_others = lines.find { |line| line.start_with?("Also here: ") } || ""
      room_info = Oga.parse_xml("<move>%s</move>" % room_xml)
      room_pcs = Oga.parse_xml("<players>%s</players>" % visible_others).css("a").map { |ele| ele.attr("noun").value }
      room_pcs << :hidden if room_xml =~ /obvious signs of someone hiding/
      @others = room_pcs - self.clustered - self.members
      unless @others.empty?
        @mine = false
        if defined? Log
          return Log.out("prevented -> %s" % @others.join(", "), label: %i(claim others))
        else
          return respond("Claim prevented -> %s" % @others.join(", "))
        end
      end
      nav = room_info.css("nav").first
      @mine = true
      self.claim_room nav.attr("rm").value unless nav.nil?
    rescue StandardError => e
      if defined? Log
        Log.out(e)
      else
        respond "Claim Error: #{e}"
      end
    ensure
      Lock.unlock if Lock.owned?
    end
  end

  def self.ingest(line)
    @buffer << line if line =~ /<nav rm='(\d+)'/
    Lock.lock if not Lock.owned? and @buffer.size > 0
    @buffer << line if @buffer.size > 0
    self.handle_room if line =~ /<compass>/ and @buffer.size > 0
  end

  def self.hook()
    DownstreamHook.add("claim/room", ->line {
      begin
        self.ingest(line)
      rescue => exception
        if defined? Log
          Log.out(exception, label: %i(room claim err))
        else
          respond "Claim Error: #{exception}"
        end
      end
      return line
    })
  end

  def self.watch!
    gems_to_load = ['oga']
    failed_to_load = []
    gems_to_load.each { |gem|
      unless Gem::Dependency.new(gem).matching_specs.max_by(&:version).nil?
        require gem
      else
        failed_to_load.push(gem)
      end
    }
    unless failed_to_load.empty?
      echo "Requires Ruby gems: #{failed_to_load.join(", ")}"
      echo "Please install the above gem(s) to use the Claim module"
    end
    self.hook()
  end

  def self.unwatch!
    DownstreamHook.remove("claim/room")
    @mine = false
  end

  def self.watching?
    DownstreamHook.list.include?('claim/room')
  end

  def self.info
    info = { 'Current Room' => XMLData.room_id,
             'Mine'         => Claim.mine?,
             'Claimed Room' => Claim.claimed_room,
             'Checked'      => Claim.checked?,
             'Last Room'    => Claim.last_room,
             'Others'       => Claim.others }
    respond JSON.pretty_generate(info)
  end
end
