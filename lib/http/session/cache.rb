class HTTP::Session
  class Cache
    extend Forwardable
    include MonitorMixin

    # @!method enabled?
    #   True when it is enabled.
    #   @return [Boolean]
    def_delegator :@options, :enabled?

    # @!method shared_cache?
    #   True when it is a shared cache.
    #   @return [Boolean]
    def_delegator :@options, :shared_cache?

    # @!method private_cache?
    #   True when it is a private cache.
    #   @return [Boolean]
    def_delegator :@options, :private_cache?

    # @param [Options::CacheOption] options
    def initialize(options)
      super()
      @options = options
    end

    # Read an entry from cache.
    #
    # @param [Request] req
    # @return [nil, Entry]
    def read(req)
      synchronize do
        key = cache_key_for(req)
        entries = read_entries(key)
        entries.find { |e| entry_matched?(e, req) }
      end
    end

    # Write an entry to cache.
    #
    # @param [Request] req
    # @param [Response] res
    # @return [void]
    def write(req, res)
      synchronize do
        key = cache_key_for(req)
        entries = read_entries(key)
        entries = entries.reject { |e| entry_matched?(e, req) }
        entry = HTTP::Session::Cache::Entry.new(req, res)
        entries << entry
        write_entries(key, entries)
      end
    end

    private

    def entry_matched?(entry, req)
      entry_matched_by_verb?(entry, req) &&
        entry_matched_by_headers?(entry, req)
    end

    def entry_matched_by_verb?(entry, req)
      entry.request.verb == req.verb
    end

    def entry_matched_by_headers?(entry, req)
      vary = entry.response.headers[HTTP::Headers::VARY]
      return true if vary.nil? || vary == ""

      vary != "*" && vary.split(",").map(&:strip).all? do |name|
        entry.request.headers[name] == req.headers[name]
      end
    end

    def read_entries(key)
      entrie = store.read(key) || []
      entrie.map do |e|
        Entry.deserialize(e)
      end
    end

    def write_entries(key, entries)
      entries = entries.map do |e|
        e = e.serialize
        e[:res][:headers].delete(HTTP::Headers::AGE)
        e
      end
      store.write(key, entries)
    end

    def cache_key_for(req)
      Digest::SHA256.hexdigest(req.uri)
    end

    # Only available when #enbled? has the value true.
    def store
      @options.store
    end
  end
end
