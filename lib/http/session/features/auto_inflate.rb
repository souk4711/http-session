require "set"

class HTTP::Session
  module Features
    class AutoInflate < HTTP::Feature
      def initialize(br: false)
        @supported_encoding = Set.new(%w[deflate gzip x-gzip])
        @supported_encoding.add("br") if br
        @supported_encoding.freeze
      end

      def wrap_response(response)
        content_encoding = response.headers.get(HTTP::Headers::CONTENT_ENCODING).first
        return response unless content_encoding && @supported_encoding.include?(content_encoding)

        content =
          case content_encoding
          when "br" then brotli_inflate(response.body)
          else inflate(response.body)
          end
        response.headers.delete(HTTP::Headers::CONTENT_ENCODING)
        response.headers[HTTP::Headers::CONTENT_LENGTH] = content.length

        options = {
          status: response.status,
          version: response.version,
          headers: response.headers,
          proxy_headers: response.proxy_headers,
          body: HTTP::Session::Response::StringBody.new(content),
          request: response.request
        }
        HTTP::Response.new(options)
      end

      private

      def brotli_inflate(body)
        Brotli.inflate(body)
      end

      def inflate(body)
        zstream = Zlib::Inflate.new(32 + Zlib::MAX_WBITS)
        zstream.inflate(body)
      ensure
        zstream.close
      end

      HTTP::Options.register_feature(:hsf_auto_inflate, self)
    end
  end
end
