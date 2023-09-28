require "http"
require "monitor"

require_relative "session/configurable"
require_relative "session/exceptions"
require_relative "session/options"
require_relative "session/requestable"
require_relative "session/version"

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
    data = handle_http_request
    cookies = data.fetch(:cookies)

    c = HTTP::Client.new(@options.http)
    c = c.cookies(cookies) if cookies
    c.request(verb, uri, opts).tap do |resp|
      handle_http_response(resp)
    end
  end

  private

  def handle_http_request
    synchronize do
      {
        cookies: extract_cookie_from_jar
      }
    end
  end

  def handle_http_response(resp)
    synchronize do
      extract_cookie_to_jar(resp)
    end
  end

  def extract_cookie_from_jar
    return if @jar.empty?
    @jar.cookies.each_with_object({}) { |c, h| h[c.name] = c.value }
  end

  def extract_cookie_to_jar(resp)
    req = resp.request
    resp.headers.get(HTTP::Headers::SET_COOKIE).each do |header|
      @jar.parse(header, req.uri)
    end
  end
end
