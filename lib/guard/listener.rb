require 'rbconfig'

module Guard

  autoload :Darwin,  'guard/listeners/darwin'
  autoload :Linux,   'guard/listeners/linux'
  autoload :Windows, 'guard/listeners/windows'
  autoload :Polling, 'guard/listeners/polling'

  class Listener
    attr_reader :last_event, :sha1_checksums_hash, :directory

    def self.select_and_init(*a)
      if mac? && Darwin.usable?
        Darwin.new(*a)
      elsif linux? && Linux.usable?
        Linux.new(*a)
      elsif windows? && Windows.usable?
        Windows.new(*a)
      else
        UI.info "Using polling (Please help us to support your system better than that.)"
        Polling.new(*a)
      end
    end

    def initialize(directory=Dir.pwd, options={})
      @directory = directory.to_s
      @sha1_checksums_hash = {}
      @relativate_paths = options.fetch(:relativate_paths, true)
      update_last_event
    end

    def start
      watch directory
    end

    def stop
    end

    def on_change(&callback)
      @callback = callback
    end

    def update_last_event
      @last_event = Time.now
    end

    def modified_files(dirs, options = {})
      files = potentially_modified_files(dirs, options).select { |path| File.file?(path) && file_modified?(path) && file_content_modified?(path) }
      relativate_paths files
    end

    def worker
      raise NotImplementedError, "should respond to #watch"
    end

    # register a directory to watch. must be implemented by the subclasses
    def watch(directory)
      raise NotImplementedError, "do whatever you want here, given the directory as only argument"
    end

    def all_files
      potentially_modified_files [directory + '/'], :all => true
    end

    # scopes all given paths to the current #directory
    def relativate_paths(paths)
      return paths unless relativate_paths?
      paths.map do |path| 
        path.gsub(%r~^#{directory}/~, '')
      end
    end

    attr_writer :relativate_paths
    def relativate_paths?
      !!@relativate_paths
    end


  private

    def potentially_modified_files(dirs, options = {})
      match = options[:all] ? "**/*" : "*"
      Dir.glob(dirs.map { |dir| "#{dir}#{match}" })
    end

    def file_modified?(path)
      # Depending on the filesystem, mtime is probably only precise to the second, so round
      # both values down to the second for the comparison.
      File.mtime(path).to_i >= last_event.to_i
    rescue
      false
    end

    def file_content_modified?(path)
      sha1_checksum = Digest::SHA1.file(path).to_s
      if sha1_checksums_hash[path] != sha1_checksum
        @sha1_checksums_hash[path] = sha1_checksum
        true
      else
        false
      end
    end

    def self.mac?
      Config::CONFIG['target_os'] =~ /darwin/i
    end

    def self.linux?
      Config::CONFIG['target_os'] =~ /linux/i
    end

    def self.windows?
      Config::CONFIG['target_os'] =~ /mswin|mingw/i
    end

  end
end
