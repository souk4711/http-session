class HTTP::Session
  class Cookies
    extend Forwardable
    include MonitorMixin

    # @!method enabled?
    #   True when it is enabled.
    #   @return [Boolean]
    def_delegator :@options, :enabled?

    # @param [Options::CookiesOption] options
    def initialize(options)
      super()
      @options = options
    end

    # Read cookies.
    #
    # @return [nil, Hash]
    def read
      synchronize do
        read_cookies
      end
    end

    # Write cookies.
    #
    # @param [Response] res
    # @return [void]
    def write(res)
      synchronize do
        write_cookies(res)
      end
    end

    private

    def read_cookies
      return if jar.empty?
      jar.cookies.each_with_object({}) { |c, h| h[c.name] = c.value }
    end

    def write_cookies(res)
      all = ([] << res.history << res).flatten
      all.each do |r|
        req = r.request
        r.headers.get(HTTP::Headers::SET_COOKIE).each do |header|
          jar.parse(header, req.uri)
        end
      end
    end

    # Only available when #enbled? has the value true.
    def jar
      @options.jar
    end
  end
end
