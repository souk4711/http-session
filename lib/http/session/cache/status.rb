class HTTP::Session
  class Cache
    class Status
      # rubocop:disable Layout/ExtraSpacing
      HEADER_NAME = "X-Httprb-Cache-Status"
      HIT         = "HIT"         # found in cache
      REVALIDATED = "REVALIDATED" # found in cache but stale, revalidated success
      EXPIRED     = "EXPIRED"     # found in cache but stale, revalidated failure, served from the origin server
      MISS        = "MISS"        # not found in cache, served from the origin server
      UNCACHEABLE = "UNCACHEABLE" # the request can not use cached response
      # rubocop:enable Layout/ExtraSpacing

      class << self
        def HIT?(v)
          v == HIT || v == REVALIDATED
        end
      end
    end
  end
end
