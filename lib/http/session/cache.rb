class HTTP::Session
  class Cache
    include MonitorMixin

    # @param [Options::CacheOption] options
    def initialize(options)
      super()

      @options = options
    end

    # @param [Request] req
    # @return [Entry]
    def read(req)
      synchronize do
        key = cache_key_for(req)
        entries = read_entries(key)
        entries.find { |e| entry_matched?(e, req) }
      end
    end

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

    # True when it is a shared cache.
    def shared?
      @options.shared_cache?
    end

    # True when it is a private cache.
    def private?
      @options.private_cache?
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
      (store.read(key) || []).map { |e| Entry.deserialize(e, from_cache: true) }
    end

    def write_entries(key, entries)
      store.write(key, entries.map { |e| e.serialize })
    end

    def store
      @options.store
    end

    def cache_key_for(req)
      Digest::SHA256.hexdigest(req.uri)
    end
  end
end
