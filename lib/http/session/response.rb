class HTTP::Session
  # Provides access to the HTTP response.
  #
  # Mostly borrowed from [rack-cache/lib/rack/cache/response.rb](https://github.com/rack/rack-cache/blob/main/lib/rack/cache/response.rb)
  class Response < SimpleDelegator
    class << self
      def new(*args)
        args[0].is_a?(self) ? args[0] : super
      end
    end

    # Status codes of responses that MAY be stored by a cache or used in reply
    # to a subsequent request.
    #
    # https://datatracker.ietf.org/doc/html/rfc9110#section-15.1
    CACHEABLE_RESPONSE_CODES = [
      200, # OK
      203, # Non-Authoritative Information
      204, # No Content
      206, # Partial Content
      300, # Multiple Choices
      301, # Moved Permanently
      308, # Permanent Redirect
      404, # Not Found
      405, # Method Not Allowed
      410, # Gone
      414, # URI Too Long
      501  # Not Implemented
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

    # Determine if the response is served from cache.
    def from_cache?
      v = headers[HTTP::Session::Cache::Status::HEADER_NAME]
      HTTP::Session::Cache::Status.HIT?(v)
    end

    # A CacheControl instance based on the response's cache-control header.
    #
    # @return [Cache::CacheControl]
    def cache_control
      @cache_control ||= HTTP::Session::Cache::CacheControl.new(headers[HTTP::Headers::CACHE_CONTROL])
    end

    # True when the cache-control/no-cache directive is present.
    def no_cache?
      cache_control.no_cache?
    end

    # Determine if the response is worth caching under any circumstance.
    #
    # https://datatracker.ietf.org/doc/html/rfc9111#section-3
    def cacheable?(shared:, req:)
      # the response status code is final (see Section 15 of [HTTP])
      return false unless CACHEABLE_RESPONSE_CODES.include?(status)

      # the no-store cache directive is not present in the response (see Section 5.2.2.5)
      return false if cache_control.no_store?

      # if the cache is shared
      if shared
        # the private response directive is either not present or allows a shared cache
        # to store a modified response; see Section 5.2.2.7)
        return false if cache_control.private?

        # the Authorization header field is not present in the request (see Section 11.6.2
        # of [HTTP]) or a response directive is present that explicitly allows shared
        # caching (see Section 3.5)
        return false if req.headers[HTTP::Headers::AUTHORIZATION] &&
          (!cache_control.public? && !cache_control.shared_max_age)
      end

      # responses with neither a freshness lifetime (expires, max-age) nor cache validator
      # (last-modified, etag) are considered uncacheable
      validateable? || fresh?(shared: shared)
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
    def fresh?(shared:)
      ttl(shared: shared) && ttl(shared: shared) > 0
    end

    # The response's time-to-live in seconds, or nil when no freshness
    # information is present in the response. When the responses #ttl
    # is <= 0, the response may not be served from cache without first
    # revalidating with the origin.
    #
    # @return [Numeric]
    def ttl(shared:)
      max_age(shared: shared) - age if max_age(shared: shared)
    end

    # The number of seconds after the time specified in the response's Date
    # header when the the response should no longer be considered fresh. First
    # check for a r-maxage directive, then a s-maxage directive, then a max-age
    # directive, and then fall back on an expires header; return nil when no
    # maximum age can be established.
    #
    # @return [Numeric]
    def max_age(shared:)
      (shared && cache_control.shared_max_age) ||
        cache_control.max_age ||
        (expires && (expires - date))
    end

    # The value of the expires header as a Time object.
    #
    # @return [Time]
    def expires
      headers[HTTP::Headers::EXPIRES] && Time.httpdate(headers[HTTP::Headers::EXPIRES])
    rescue
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
    rescue
      headers[HTTP::Headers::DATE] = now.httpdate
    end
  end
end
