# frozen_string_literal: true

require 'rspec'
require 'fileutils'
require 'tmpdir'
require 'json'

# Mock Lich constants and methods that would normally be provided by the Lich environment
module LichMocks
  LICH_VERSION = '5.14.3'
  LICH_DIR = '/mock/lich'
  SCRIPT_DIR = '/mock/lich/scripts'
  LIB_DIR = '/mock/lich/lib'
  DATA_DIR = '/mock/lich/data'
  BACKUP_DIR = '/mock/lich/backup'
  TEMP_DIR = '/mock/lich/temp'

  def respond(msg = nil)
    # Mock respond method
    @responses ||= []
    @responses << msg
  end

  def _respond(msg)
    respond(msg)
  end

  def monsterbold_start
    '**'
  end

  def monsterbold_end
    '**'
  end
end

# Mock XMLData class
class XMLData
  def self.game
    'GS'
  end
end unless defined?(XMLData.game)

# Mock Lich class
class Lich
  def self.core_updated_with_lich_version=(version)
    @core_updated_with_lich_version = version
  end

  def self.core_updated_with_lich_version
    @core_updated_with_lich_version
  end
end unless defined?(Lich.core_updated_with_lich_version)

# Load the module (in real tests, you'd require the actual file)
# For this spec, we'll need to have the module defined or loaded
# require_relative '../update'

RSpec.describe Lich::Util::Update do
  include LichMocks

  before(:each) do
    # Define constants if not already defined
    unless defined?(LICH_VERSION)
      stub_const('LICH_VERSION', LichMocks::LICH_VERSION)
    end
    unless defined?(LICH_DIR)
      stub_const('LICH_DIR', LichMocks::LICH_DIR)
    end
    unless defined?(SCRIPT_DIR)
      stub_const('SCRIPT_DIR', LichMocks::SCRIPT_DIR)
    end
    unless defined?(LIB_DIR)
      stub_const('LIB_DIR', LichMocks::LIB_DIR)
    end
    unless defined?(DATA_DIR)
      stub_const('DATA_DIR', LichMocks::DATA_DIR)
    end
    unless defined?(BACKUP_DIR)
      stub_const('BACKUP_DIR', LichMocks::BACKUP_DIR)
    end
    unless defined?(TEMP_DIR)
      stub_const('TEMP_DIR', LichMocks::TEMP_DIR)
    end
    unless defined?($clean_lich_char)
      $clean_lich_char = ';'
    end
    unless defined?($PROGRAM_NAME)
      $PROGRAM_NAME = 'lich.rbw'
    end

    # Reset instance variables
    described_class.instance_variable_set(:@_http_cache, {})
    described_class.instance_variable_set(:@current, LICH_VERSION)

    # Mock respond method
    allow(described_class).to receive(:respond).and_return(nil)
    allow(described_class).to receive(:_respond).and_return(nil)
    allow(described_class).to receive(:monsterbold_start).and_return('**')
    allow(described_class).to receive(:monsterbold_end).and_return('**')

    # Mock FileUtils operations
    allow(FileUtils).to receive(:mkdir_p)
    allow(FileUtils).to receive(:cp)
    allow(FileUtils).to receive(:cp_r)
    allow(FileUtils).to receive(:mv)
    allow(FileUtils).to receive(:rm)
    allow(FileUtils).to receive(:rm_rf)
    allow(FileUtils).to receive(:remove_dir)
    allow(FileUtils).to receive(:copy_entry)

    # Mock File operations
    allow(File).to receive(:exist?).and_return(false)
    allow(File).to receive(:join) { |*args| args.join('/') }
    allow(File).to receive(:basename) { |path| path.split('/').last }
    allow(File).to receive(:dirname) { |path| path.split('/')[0..-2].join('/') }
    allow(File).to receive(:delete)
    allow(File).to receive(:rename)
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:read).and_return('')

    # Mock Dir operations
    allow(Dir).to receive(:glob).and_return([])
    allow(Dir).to receive(:children).and_return([])
  end

  describe '.request' do
    context 'with --announce flag' do
      it 'calls announce method' do
        expect(described_class).to receive(:announce)
        described_class.request('--announce')
      end

      it 'calls announce with -a shorthand' do
        expect(described_class).to receive(:announce)
        described_class.request('-a')
      end
    end

    context 'with --branch flag' do
      it 'calls download_branch_update with branch name' do
        expect(described_class).to receive(:download_branch_update).with('test-branch')
        described_class.request('--branch=test-branch')
      end

      it 'handles branches with special characters' do
        expect(described_class).to receive(:download_branch_update).with('feature/new-system')
        described_class.request('--branch=feature/new-system')
      end
    end

    context 'with --update flag' do
      it 'calls download_release_update method' do
        expect(described_class).to receive(:download_release_update)
        described_class.request('--update')
      end

      it 'calls download_release_update with -u shorthand' do
        expect(described_class).to receive(:download_release_update)
        described_class.request('-u')
      end
    end

    context 'with --help flag' do
      it 'calls help method' do
        expect(described_class).to receive(:help)
        described_class.request('--help')
      end

      it 'calls help with -h shorthand' do
        expect(described_class).to receive(:help)
        described_class.request('-h')
      end
    end

    context 'with --snapshot flag' do
      it 'calls snapshot method' do
        expect(described_class).to receive(:snapshot)
        described_class.request('--snapshot')
      end

      it 'calls snapshot with -s shorthand' do
        expect(described_class).to receive(:snapshot)
        described_class.request('-s')
      end
    end

    context 'with --revert flag' do
      it 'calls revert method' do
        expect(described_class).to receive(:revert)
        described_class.request('--revert')
      end

      it 'calls revert with -r shorthand' do
        expect(described_class).to receive(:revert)
        described_class.request('-r')
      end
    end

    context 'with --script flag' do
      it 'calls update_file with script type' do
        expect(described_class).to receive(:update_file).with('script', 'test.lic')
        described_class.request('--script=test.lic')
      end
    end

    context 'with --library flag' do
      it 'calls update_file with library type' do
        expect(described_class).to receive(:update_file).with('library', 'test.rb')
        described_class.request('--library=test.rb')
      end
    end

    context 'with --data flag' do
      it 'calls update_file with data type' do
        expect(described_class).to receive(:update_file).with('data', 'test.xml')
        described_class.request('--data=test.xml')
      end
    end

    context 'with unknown command' do
      it 'responds with error message' do
        expect(described_class).to receive(:respond).at_least(:once)
        described_class.request('--invalid')
      end
    end

    context 'with --beta flag' do
      it 'calls prep_betatest with no arguments' do
        expect(described_class).to receive(:prep_betatest).with(nil, nil)
        described_class.request('--beta')
      end

      it 'calls prep_betatest with file type and name' do
        expect(described_class).to receive(:prep_betatest).with('script', 'test.lic')
        described_class.request('--beta --script=test.lic')
      end
    end
  end

  describe '.announce' do
    before(:each) do
      allow(described_class).to receive(:prep_update)
      described_class.instance_variable_set(:@update_to, '5.15.0')
      described_class.instance_variable_set(:@new_features, 'New features here')
    end

    context 'when newer version is available' do
      it 'displays update announcement' do
        expect(described_class).to receive(:respond).with(include('NEW VERSION AVAILABLE'))
        described_class.announce
      end
    end

    context 'when current version is up to date' do
      before(:each) do
        described_class.instance_variable_set(:@update_to, '5.14.3')
      end

      it 'displays current version is good' do
        expect(described_class).to receive(:respond).with(/Lich version.*is good/)
        described_class.announce
      end
    end

    context 'when running Lich 4' do
      before(:each) do
        stub_const('LICH_VERSION', '4.0.0')
        described_class.instance_variable_set(:@current, '4.0.0')
      end

      it 'displays unsupported message' do
        expect(described_class).to receive(:respond).with(/does not support Lich 4/)
        described_class.announce
      end
    end
  end

  describe '.help' do
    it 'displays help information' do
      expect(described_class).to receive(:respond).with(include('--help'))
      described_class.help
    end

    it 'includes branch update option' do
      expect(described_class).to receive(:respond).with(include('--branch='))
      described_class.help
    end

    it 'includes all major commands' do
      expect(described_class).to receive(:respond).with(include('--update', '--snapshot', '--revert'))
      described_class.help
    end
  end

  describe '.snapshot' do
    let(:timestamp) { '2024-01-15-12-30-45' }

    before(:each) do
      allow(Time).to receive(:now).and_return(Time.new(2024, 1, 15, 12, 30, 45))
      allow(File).to receive(:exist?).and_return(true)
    end

    it 'creates snapshot directory' do
      expect(FileUtils).to receive(:mkdir_p).with(include('L5-snapshot-2024-01-15-12-30-45'))
      described_class.snapshot
    end

    it 'backs up lich.rbw file' do
      expect(FileUtils).to receive(:cp).with(
        include('lich.rbw'),
        include('L5-snapshot')
      )
      described_class.snapshot
    end

    it 'backs up lib directory' do
      expect(FileUtils).to receive(:cp_r).with(LIB_DIR, include('L5-snapshot'))
      described_class.snapshot
    end

    it 'backs up core script files' do
      expect(FileUtils).to receive(:cp).at_least(:once)
      described_class.snapshot
    end

    it 'displays snapshot location' do
      expect(described_class).to receive(:respond).with(include('backed up to'))
      described_class.snapshot
    end
  end

  describe '.resolve_channel_ref' do
    context 'for stable channel' do
      it 'returns STABLE_REF' do
        expect(described_class.resolve_channel_ref(:stable)).to eq('main')
      end

      it 'returns STABLE_REF for production' do
        expect(described_class.resolve_channel_ref('production')).to eq('main')
      end
    end

    context 'for beta channel' do
      before(:each) do
        allow(described_class).to receive(:latest_stable_tag).and_return('v5.14.3')
        allow(described_class).to receive(:major_minor_from).and_return([5, 14])
      end

      it 'checks for environment variable first' do
        allow(ENV).to receive(:[]).with('LICH_BETA_REF').and_return('custom-beta')
        expect(described_class.resolve_channel_ref(:beta)).to eq('custom-beta')
      end

      it 'tries prerelease tags when no env var' do
        allow(ENV).to receive(:[]).with('LICH_BETA_REF').and_return(nil)
        expect(described_class).to receive(:latest_prerelease_tag_greater_than)
        described_class.resolve_channel_ref(:beta)
      end

      it 'falls back to prefixed branches' do
        allow(ENV).to receive(:[]).with('LICH_BETA_REF').and_return(nil)
        allow(described_class).to receive(:latest_prerelease_tag_greater_than).and_return(nil)
        expect(described_class).to receive(:latest_prefixed_branch_greater_than)
        described_class.resolve_channel_ref(:beta)
      end
    end
  end

  describe '.fetch_github_json' do
    let(:test_url) { 'https://api.github.com/repos/test/repo/releases' }
    let(:json_response) { { 'test' => 'data' }.to_json }

    context 'with successful request' do
      before(:each) do
        mock_response = double('response', read: json_response)
        allow(URI).to receive(:parse).with(test_url).and_return(double(open: mock_response))
      end

      it 'returns parsed JSON' do
        result = described_class.fetch_github_json(test_url)
        expect(result).to eq({ 'test' => 'data' })
      end

      it 'caches the response' do
        described_class.fetch_github_json(test_url)
        cache = described_class.instance_variable_get(:@_http_cache)
        expect(cache[test_url]).to be_a(Hash)
        expect(cache[test_url][:data]).to eq({ 'test' => 'data' })
      end

      it 'uses cached response within TTL' do
        described_class.fetch_github_json(test_url)
        expect(URI).to receive(:parse).once
        described_class.fetch_github_json(test_url) # Should use cache
      end
    end

    context 'with network error' do
      before(:each) do
        allow(URI).to receive(:parse).and_raise(StandardError.new('Network error'))
      end

      it 'returns nil on error' do
        expect(described_class.fetch_github_json(test_url)).to be_nil
      end

      it 'logs error message' do
        expect(described_class).to receive(:respond).with(include('network error'))
        described_class.fetch_github_json(test_url)
      end
    end
  end

  describe '.version_key' do
    it 'converts version string to Gem::Version' do
      result = described_class.version_key('5.14.3')
      expect(result).to be_a(Gem::Version)
      expect(result.to_s).to eq('5.14.3')
    end

    it 'strips leading v from tags' do
      result = described_class.version_key('v5.14.3')
      expect(result.to_s).to eq('5.14.3')
    end

    it 'extracts version from branch names' do
      result = described_class.version_key('pre/beta/5.15.0')
      expect(result.to_s).to eq('5.15.0')
    end

    it 'normalizes beta versions' do
      result = described_class.version_key('5.15.0-beta')
      expect(result.to_s).to eq('5.15.0.beta')
    end

    it 'handles complex version strings' do
      result = described_class.version_key('pre/beta-5.15.0-beta.1')
      expect(result).to be_a(Gem::Version)
    end
  end

  describe '.major_minor_from' do
    it 'extracts major and minor from x.y.z format' do
      expect(described_class.major_minor_from('5.14.3')).to eq([5, 14])
    end

    it 'extracts major and minor from x.y format' do
      expect(described_class.major_minor_from('5.14')).to eq([5, 14])
    end

    it 'strips leading v' do
      expect(described_class.major_minor_from('v5.14.3')).to eq([5, 14])
    end

    it 'returns [nil, nil] for invalid format' do
      expect(described_class.major_minor_from('invalid')).to eq([nil, nil])
    end

    it 'returns [nil, nil] for nil input' do
      expect(described_class.major_minor_from(nil)).to eq([nil, nil])
    end
  end

  describe '.latest_stable_tag' do
    let(:releases) do
      [
        { 'tag_name' => 'v5.14.3', 'prerelease' => false },
        { 'tag_name' => 'v5.14.2', 'prerelease' => false },
        { 'tag_name' => 'v5.15.0-beta.1', 'prerelease' => true }
      ]
    end

    before(:each) do
      allow(described_class).to receive(:fetch_github_json).and_return(releases)
    end

    it 'returns latest stable tag' do
      expect(described_class.latest_stable_tag).to eq('v5.14.3')
    end

    it 'excludes prerelease versions' do
      result = described_class.latest_stable_tag
      expect(result).not_to include('beta')
    end

    it 'returns nil when no releases found' do
      allow(described_class).to receive(:fetch_github_json).and_return(nil)
      expect(described_class.latest_stable_tag).to be_nil
    end
  end

  describe '.validate_lich_structure' do
    it 'returns true when lib and lich.rbw exist' do
      allow(File).to receive(:exist?).with(include('lib')).and_return(true)
      allow(File).to receive(:exist?).with(include('lich.rbw')).and_return(true)
      expect(described_class.validate_lich_structure('/test/dir')).to be true
    end

    it 'returns false when lib is missing' do
      allow(File).to receive(:exist?).with(include('lib')).and_return(false)
      allow(File).to receive(:exist?).with(include('lich.rbw')).and_return(true)
      expect(described_class.validate_lich_structure('/test/dir')).to be false
    end

    it 'returns false when lich.rbw is missing' do
      allow(File).to receive(:exist?).with(include('lib')).and_return(true)
      allow(File).to receive(:exist?).with(include('lich.rbw')).and_return(false)
      expect(described_class.validate_lich_structure('/test/dir')).to be false
    end
  end

  describe '.check_ruby_compatibility' do
    let(:source_dir) { '/test/source' }
    let(:version) { '5.15.0' }

    context 'when Ruby version is compatible' do
      before(:each) do
        version_content = "REQUIRED_RUBY = '2.6.0'"
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:read).and_return(version_content)
        stub_const('RUBY_VERSION', '3.0.0')
      end

      it 'returns true' do
        expect(described_class.check_ruby_compatibility(source_dir, version)).to be true
      end
    end

    context 'when Ruby version is too old' do
      before(:each) do
        version_content = "REQUIRED_RUBY = '3.2.0'"
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:read).and_return(version_content)
        stub_const('RUBY_VERSION', '2.6.0')
      end

      it 'returns false' do
        expect(described_class.check_ruby_compatibility(source_dir, version)).to be false
      end

      it 'displays error message' do
        expect(described_class).to receive(:respond).with(include('UPDATE ABORTED'))
        described_class.check_ruby_compatibility(source_dir, version)
      end
    end

    context 'when version file does not exist' do
      before(:each) do
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'returns true (no check performed)' do
        expect(described_class.check_ruby_compatibility(source_dir, version)).to be true
      end
    end
  end

  describe '.download_branch_update' do
    let(:branch_name) { 'test-branch' }
    let(:tarball_url) { "https://github.com/elanthia-online/lich-5/archive/refs/heads/#{branch_name}.tar.gz" }

    before(:each) do
      allow(described_class).to receive(:snapshot)
      allow(described_class).to receive(:validate_lich_structure).and_return(true)
      allow(described_class).to receive(:perform_update)
      allow(Dir).to receive(:children).and_return(['lich-5-test-branch'])

      # Mock tarball download
      mock_file = double('file')
      allow(mock_file).to receive(:write)
      allow(File).to receive(:open).and_yield(mock_file)

      # Mock URI open
      mock_response = double('response', read: 'tarball content')
      allow(URI).to receive(:parse).with(tarball_url).and_return(double(open: mock_response))

      # Mock Gem::Package extraction
      mock_package = double('package')
      allow(mock_package).to receive(:extract_tar_gz)
      allow(Gem::Package).to receive(:new).and_return(mock_package)
    end

    context 'with valid branch name' do
      it 'creates snapshot before update' do
        expect(described_class).to receive(:snapshot)
        described_class.download_branch_update(branch_name)
      end

      it 'downloads tarball from GitHub' do
        mock_response = double('response', read: 'tarball content')
        expect(URI).to receive(:parse).with(tarball_url).and_return(double(open: mock_response))
        described_class.download_branch_update(branch_name)
      end

      it 'validates Lich structure' do
        expect(described_class).to receive(:validate_lich_structure)
        described_class.download_branch_update(branch_name)
      end

      it 'performs update' do
        expect(described_class).to receive(:perform_update)
        described_class.download_branch_update(branch_name)
      end

      it 'cleans up temporary files' do
        expect(FileUtils).to receive(:remove_dir).at_least(:once)
        expect(FileUtils).to receive(:rm).at_least(:once)
        described_class.download_branch_update(branch_name)
      end
    end

    context 'with empty branch name' do
      it 'displays error and returns early' do
        expect(described_class).to receive(:respond).with(include('cannot be empty'))
        described_class.download_branch_update('')
      end

      it 'does not create snapshot' do
        expect(described_class).not_to receive(:snapshot)
        described_class.download_branch_update('')
      end
    end

    context 'with whitespace in branch name' do
      it 'strips whitespace' do
        expect(URI).to receive(:parse).with(
          "https://github.com/elanthia-online/lich-5/archive/refs/heads/test-branch.tar.gz"
        ).and_return(double(open: double(read: 'content')))
        described_class.download_branch_update('  test-branch  ')
      end
    end

    context 'when download fails' do
      before(:each) do
        allow(URI).to receive(:parse).and_raise(OpenURI::HTTPError.new('404 Not Found', nil))
      end

      it 'displays error message' do
        expect(described_class).to receive(:respond).with(include('Could not download branch'))
        described_class.download_branch_update(branch_name)
      end

      it 'attempts cleanup' do
        expect(FileUtils).to receive(:remove_dir).at_least(:once)
        described_class.download_branch_update(branch_name)
      end
    end

    context 'when structure validation fails' do
      before(:each) do
        allow(described_class).to receive(:validate_lich_structure).and_return(false)
      end

      it 'raises error with validation message' do
        expect(described_class).to receive(:respond).with(include('does not appear to be a valid Lich installation'))
        described_class.download_branch_update(branch_name)
      end
    end
  end

  describe '.download_release_update' do
    before(:each) do
      described_class.instance_variable_set(:@update_to, '5.15.0')
      described_class.instance_variable_set(:@zipfile, 'https://github.com/test.tar.gz')

      allow(described_class).to receive(:snapshot)
      allow(described_class).to receive(:check_ruby_compatibility).and_return(true)
      allow(described_class).to receive(:perform_update)

      # Mock file operations
      mock_file = double('file')
      allow(mock_file).to receive(:write)
      allow(File).to receive(:open).and_yield(mock_file)

      # Mock URI open
      mock_response = double('response', read: 'tarball content')
      allow(URI).to receive(:parse).and_return(double(open: mock_response))

      # Mock Gem::Package extraction
      mock_package = double('package')
      allow(mock_package).to receive(:extract_tar_gz)
      allow(Gem::Package).to receive(:new).and_return(mock_package)

      allow(Dir).to receive(:children).and_return(['lich-5-5.15.0'])
    end

    context 'when update is available' do
      it 'creates snapshot' do
        expect(described_class).to receive(:snapshot)
        described_class.download_release_update
      end

      it 'downloads update tarball' do
        expect(URI).to receive(:parse).with('https://github.com/test.tar.gz')
        described_class.download_release_update
      end

      it 'checks Ruby compatibility' do
        expect(described_class).to receive(:check_ruby_compatibility)
        described_class.download_release_update
      end

      it 'performs update' do
        expect(described_class).to receive(:perform_update)
        described_class.download_release_update
      end

      it 'cleans up temporary files' do
        expect(FileUtils).to receive(:remove_dir)
        expect(FileUtils).to receive(:rm)
        described_class.download_release_update
      end
    end

    context 'when current version is up to date' do
      before(:each) do
        described_class.instance_variable_set(:@update_to, '5.14.3')
      end

      it 'does not perform update' do
        expect(described_class).not_to receive(:perform_update)
        described_class.download_release_update
      end

      it 'displays version is good message' do
        expect(described_class).to receive(:respond).with(/is good/)
        described_class.download_release_update
      end
    end

    context 'when Ruby compatibility check fails' do
      before(:each) do
        allow(described_class).to receive(:check_ruby_compatibility).and_return(false)
      end

      it 'does not perform update' do
        expect(described_class).not_to receive(:perform_update)
        described_class.download_release_update
      end

      it 'cleans up downloaded files' do
        expect(FileUtils).to receive(:remove_dir).at_least(:once)
        expect(FileUtils).to receive(:rm).at_least(:once)
        described_class.download_release_update
      end
    end
  end

  describe '.perform_update' do
    let(:source_dir) { '/test/source' }
    let(:version) { '5.15.0' }

    before(:each) do
      allow(described_class).to receive(:update_core_data_and_scripts)
      allow(Dir).to receive(:glob).and_return([])
      allow(File).to receive(:open).and_call_original
    end

    it 'removes existing lib files' do
      expect(FileUtils).to receive(:rm_rf)
      described_class.perform_update(source_dir, version)
    end

    it 'copies new lib files' do
      expect(FileUtils).to receive(:copy_entry).with(include('lib'), LIB_DIR)
      described_class.perform_update(source_dir, version)
    end

    it 'updates core data and scripts' do
      expect(described_class).to receive(:update_core_data_and_scripts).with(version)
      described_class.perform_update(source_dir, version)
    end

    it 'updates lich.rbw file' do
      mock_read = double('read_file')
      mock_write = double('write_file')
      allow(mock_read).to receive(:read).and_return('new lich content')
      allow(mock_write).to receive(:write)

      expect(File).to receive(:open).with(include('lich.rbw'), 'rb').and_yield(mock_read)
      expect(File).to receive(:open).with(include('lich.rbw'), 'wb').and_yield(mock_write)

      described_class.perform_update(source_dir, version)
    end
  end

  describe '.revert' do
    let(:snapshot_dir) { "#{BACKUP_DIR}/L5-snapshot-2024-01-15-12-30-45" }

    before(:each) do
      allow(Dir).to receive(:glob).and_return([snapshot_dir])
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:open).and_return(double(read: "LICH_VERSION = \"5.14.2\"\n"))
      allow(File).to receive(:delete)
    end

    context 'when snapshot exists' do
      it 'removes current lib files' do
        expect(FileUtils).to receive(:rm_rf).with(include(LIB_DIR))
        described_class.revert
      end

      it 'restores lib files from snapshot' do
        expect(FileUtils).to receive(:cp_r).with(include('lib'), LIB_DIR)
        described_class.revert
      end

      it 'restores core scripts from snapshot' do
        expect(FileUtils).to receive(:cp_r).with(include('scripts'), SCRIPT_DIR)
        described_class.revert
      end

      it 'restores lich.rbw file' do
        mock_read = double('read_file', read: 'old lich content')
        mock_write = double('write_file')
        allow(mock_write).to receive(:write)

        expect(File).to receive(:open).with(include('lich.rbw'), 'rb').and_yield(mock_read)
        expect(File).to receive(:open).with(include('lich.rbw'), 'wb').and_yield(mock_write)

        described_class.revert
      end

      it 'displays reverted version' do
        expect(described_class).to receive(:respond).with(include('reverted to Lich5 version'))
        described_class.revert
      end
    end

    context 'when no snapshot exists' do
      before(:each) do
        allow(Dir).to receive(:glob).and_return([])
      end

      it 'displays error message' do
        expect(described_class).to receive(:respond).with(include('No prior Lich5 version found'))
        described_class.revert
      end

      it 'does not attempt to restore files' do
        expect(FileUtils).not_to receive(:cp_r)
        described_class.revert
      end
    end
  end

  describe '.update_file' do
    let(:file_content) { 'file content' }
    let(:mock_response) { double('response', read: file_content) }

    before(:each) do
      allow(URI).to receive(:parse).and_return(double(open: mock_response))
      allow(File).to receive(:exist?).and_return(false)
    end

    context 'with script type' do
      it 'downloads from scripts repository' do
        expect(URI).to receive(:parse).with(include('elanthia-online/scripts'))
        described_class.update_file('script', 'test.lic')
      end

      it 'validates .lic extension' do
        described_class.update_file('script', 'test.lic')
        expect(described_class).not_to receive(:respond).with(include('incorrect extension'))
      end

      it 'rejects invalid extensions' do
        expect(described_class).to receive(:respond).with(include('incorrect extension'))
        described_class.update_file('script', 'test.rb')
      end
    end

    context 'with library type' do
      before(:each) do
        allow(described_class).to receive(:resolve_channel_ref).and_return('main')
      end

      it 'downloads from lich-5 repository' do
        expect(URI).to receive(:parse).with(include('elanthia-online/lich-5'))
        described_class.update_file('library', 'test.rb')
      end

      it 'validates .rb extension' do
        described_class.update_file('library', 'test.rb')
        expect(described_class).not_to receive(:respond).with(include('incorrect extension'))
      end

      it 'uses beta channel when specified' do
        allow(described_class).to receive(:resolve_channel_ref).with(:beta).and_return('pre/beta/5.15')
        expect(URI).to receive(:parse).with(include('pre/beta/5.15'))
        described_class.update_file('library', 'test.rb', 'beta')
      end
    end

    context 'with data type' do
      it 'downloads from scripts repository' do
        expect(URI).to receive(:parse).with(include('elanthia-online/scripts'))
        described_class.update_file('data', 'test.xml')
      end

      it 'validates .xml extension' do
        described_class.update_file('data', 'test.xml')
        expect(described_class).not_to receive(:respond).with(include('incorrect extension'))
      end

      it 'validates .ui extension' do
        described_class.update_file('data', 'test.ui')
        expect(described_class).not_to receive(:respond).with(include('incorrect extension'))
      end
    end

    context 'with download error' do
      before(:each) do
        allow(URI).to receive(:parse).and_raise(StandardError.new('Network error'))
      end

      it 'displays error message' do
        expect(described_class).to receive(:respond).with(include('Error updating'))
        described_class.update_file('script', 'test.lic')
      end

      it 'cleans up temporary file' do
        allow(File).to receive(:exist?).with(include('.tmp')).and_return(true)
        expect(File).to receive(:delete).with(include('.tmp'))
        described_class.update_file('script', 'test.lic')
      end

      it 'restores old file if exists' do
        allow(File).to receive(:exist?).with(include('.old')).and_return(true)
        expect(File).to receive(:rename).with(include('.old'), anything)
        described_class.update_file('script', 'test.lic')
      end
    end
  end

  describe '.update_core_data_and_scripts' do
    let(:version) { '5.15.0' }

    before(:each) do
      allow(XMLData).to receive(:game).and_return('GS')
      allow(described_class).to receive(:update_file)
      allow(Lich).to receive(:core_updated_with_lich_version=)
      allow(File).to receive(:exist?).and_return(false)
    end

    context 'for GemStone IV' do
      it 'updates all core scripts' do
        expect(described_class).to receive(:update_file).with('script', anything).at_least(10).times
        described_class.update_core_data_and_scripts(version)
      end

      it 'updates GS-specific scripts' do
        expect(described_class).to receive(:update_file).with('script', 'ewaggle.lic')
        expect(described_class).to receive(:update_file).with('script', 'foreach.lic')
        described_class.update_core_data_and_scripts(version)
      end

      it 'does not update DR-specific scripts' do
        expect(described_class).not_to receive(:update_file).with('script', 'dependency.lic')
        described_class.update_core_data_and_scripts(version)
      end
    end

    context 'for DragonRealms' do
      before(:each) do
        allow(XMLData).to receive(:game).and_return('DR')
      end

      it 'updates DR-specific scripts' do
        expect(described_class).to receive(:update_file).with('script', 'dependency.lic')
        described_class.update_core_data_and_scripts(version)
      end

      it 'does not update GS-specific scripts' do
        expect(described_class).not_to receive(:update_file).with('script', 'ewaggle.lic')
        expect(described_class).not_to receive(:update_file).with('script', 'foreach.lic')
        described_class.update_core_data_and_scripts(version)
      end
    end

    context 'for invalid game' do
      before(:each) do
        allow(XMLData).to receive(:game).and_return('INVALID')
      end

      it 'displays error and returns early' do
        expect(described_class).to receive(:respond).with(include('invalid game type'))
        described_class.update_core_data_and_scripts(version)
      end

      it 'does not update any scripts' do
        expect(described_class).not_to receive(:update_file)
        described_class.update_core_data_and_scripts(version)
      end
    end

    it 'updates effect-list.xml' do
      expect(described_class).to receive(:update_file).with('data', 'effect-list.xml')
      described_class.update_core_data_and_scripts(version)
    end

    it 'updates Lich.db version' do
      expect(Lich).to receive(:core_updated_with_lich_version=).with(version)
      described_class.update_core_data_and_scripts(version)
    end
  end

  describe 'integration tests' do
    context 'full branch update workflow' do
      before(:each) do
        # Setup mocks for full workflow
        allow(described_class).to receive(:snapshot)
        allow(FileUtils).to receive(:mkdir_p)
        allow(Dir).to receive(:children).and_return(['lich-5-test-branch'])

        mock_tarball = double('tarball', read: 'tarball data')
        allow(URI).to receive(:parse).and_return(double(open: mock_tarball))

        mock_package = double('package')
        allow(mock_package).to receive(:extract_tar_gz)
        allow(Gem::Package).to receive(:new).and_return(mock_package)

        allow(File).to receive(:exist?).and_return(true)
        allow(described_class).to receive(:validate_lich_structure).and_return(true)
        allow(described_class).to receive(:update_core_data_and_scripts)
      end

      it 'completes full update successfully' do
        expect {
          described_class.download_branch_update('test-branch')
        }.not_to raise_error
      end

      it 'performs all required steps in order' do
        expect(described_class).to receive(:snapshot).ordered
        expect(URI).to receive(:parse).ordered
        expect(described_class).to receive(:validate_lich_structure).ordered
        expect(FileUtils).to receive(:rm_rf).ordered
        expect(described_class).to receive(:update_core_data_and_scripts).ordered

        described_class.download_branch_update('test-branch')
      end
    end
  end
end
