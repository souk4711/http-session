class HTTP::Session
  # @author [rack/rack-cache](https://github.com/rack/rack-cache)
  # @author [souk4711/http-session](https://github.com/souk4711/http-session)
  class Response < SimpleDelegator
    class << self
      def new(*args)
        args[0].is_a?(self) ? args[0] : super
      end
    end

    # Status codes of responses that MAY be stored by a cache or used in reply
    # to a subsequent request.
    #
    # http://tools.ietf.org/html/rfc2616#section-13.4
    CACHEABLE_RESPONSE_CODES = [
      200, # OK
      203, # Non-Authoritative Information
      300, # Multiple Choices
      301, # Moved Permanently
      302, # Found
      404, # Not Found
      410  # Gone
    ].to_set

    # @!attribute [rw] history
    #   @return [Array<Response>] a list of response objects holding the history of the redirection
    attr_accessor :history

    # @!attribute [r] now
    #   @return [Time] the time when the Response object was instantiated
    attr_reader :now

    # Returns a new instance of Response.
    def initialize(*args)
      super

      @now = Time.now
      _hs_ensure_header_date

      @history = []
    end

    # A CacheControl instance based on the response's cache-control header.
    #
    # @return [Cache::CacheControl]
    def cache_control
      @cache_control ||= HTTP::Session::Cache::CacheControl.new(headers[HTTP::Headers::CACHE_CONTROL])
    end

    # Determine if the response is worth caching under any circumstance. Responses
    # marked "private" with an explicit cache-control directive are considered
    # uncacheable
    #
    # Responses with neither a freshness lifetime (expires, max-age) nor cache
    # validator (last-modified, etag) are considered uncacheable.
    def cacheable?(in_private_caches:)
      return false unless CACHEABLE_RESPONSE_CODES.include?(status)
      return false if cache_control.no_store?
      return false if cache_control.private? && !in_private_caches
      validateable? || fresh?
    end

    # Determine if the response includes headers that can be used to validate
    # the response with the origin using a conditional GET request.
    def validateable?
      headers.include?(HTTP::Headers::LAST_MODIFIED) || headers.include?(HTTP::Headers::ETAG)
    end

    # Determine if the response is "fresh". Fresh responses may be served from
    # cache without any interaction with the origin. A response is considered
    # fresh when it includes a cache-control/max-age indicator or Expiration
    # header and the calculated age is less than the freshness lifetime.
    def fresh?
      ttl && ttl > 0
    end

    # The response's time-to-live in seconds, or nil when no freshness
    # information is present in the response. When the responses #ttl
    # is <= 0, the response may not be served from cache without first
    # revalidating with the origin.
    #
    # @return [Numeric]
    def ttl
      max_age - age if max_age
    end

    # The number of seconds after the time specified in the response's Date
    # header when the the response should no longer be considered fresh. First
    # check for a r-maxage directive, then a s-maxage directive, then a max-age
    # directive, and then fall back on an expires header; return nil when no
    # maximum age can be established.
    #
    # @return [Numeric]
    def max_age
      cache_control.shared_max_age ||
        cache_control.max_age ||
        (expires && (expires - date))
    end

    # The value of the expires header as a Time object.
    #
    # @return [Time]
    def expires
      headers[HTTP::Headers::EXPIRES] && Time.httpdate(headers[HTTP::Headers::EXPIRES])
    rescue ArgumentError
      nil
    end

    # The date of the response.
    #
    # @return [Time]
    def date
      Time.httpdate(headers[HTTP::Headers::DATE])
    end

    # The age of the response.
    #
    # @return [Numeric]
    def age
      (headers[HTTP::Headers::AGE] || [(now - date).to_i, 0].max).to_i
    end

    # The literal value of ETag HTTP header or nil if no etag is specified.
    def etag
      headers[HTTP::Headers::ETAG]
    end

    # The String value of the Last-Modified header exactly as it appears
    # in the response (i.e., no date parsing / conversion is performed).
    def last_modified
      headers[HTTP::Headers::LAST_MODIFIED]
    end

    private

    # When no Date header is present or is unparseable, set the Date header to Time.now.
    def _hs_ensure_header_date
      date
    rescue ArgumentError
      headers[HTTP::Headers::DATE] = now.httpdate
    end
  end
end
