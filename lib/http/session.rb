require "http"
require "monitor"

require_relative "session/client"
require_relative "session/configurable"
require_relative "session/options"
require_relative "session/request"
require_relative "session/requestable"
require_relative "session/response"
require_relative "session/version"

# Use session to manage cookies and cache across requests.
class HTTP::Session
  include MonitorMixin
  include HTTP::Session::Configurable
  include HTTP::Session::Requestable

  def initialize(options = {})
    super()

    @options = HTTP::Session::Options.new(options)
    @jar = HTTP::CookieJar.new
  end

  def request(verb, uri, opts = {})
    c = HTTP::Session::Client.new(@options.http)
    c.request(verb, uri, opts, self).tap do |res|
      handle_http_response(res)
    end
  end

  # @!visibility private
  def make_http_request_data
    synchronize do
      {
        cookies: extract_cookie_from_jar
      }
    end
  end

  private

  def handle_http_response(res)
    synchronize do
      extract_cookie_to_jar(res)
    end
  end

  def extract_cookie_from_jar
    return if @jar.empty?
    @jar.cookies.each_with_object({}) { |c, h| h[c.name] = c.value }
  end

  def extract_cookie_to_jar(res)
    all = ([] << res.history << res).flatten
    all.each do |r|
      req = r.request
      r.headers.get(HTTP::Headers::SET_COOKIE).each do |header|
        @jar.parse(header, req.uri)
      end
    end
  end
end
