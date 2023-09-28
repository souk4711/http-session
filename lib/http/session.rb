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
    handle_http_request_cookies(@options.http, opts, data)

    c = HTTP::Client.new(@options.http)
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

  def handle_http_request_cookies(client_opts, request_opts, data)
    session_cookies = data[:cookies]
    return if session_cookies.nil?

    # Override client's cookies
    if request_opts.key?(:cookies)
      cookies = request_opts[:cookies]
      cookies[:__http_session_cookies__] = session_cookies
      request_opts[:cookies] = cookies
      return
    end

    # Keep client's cookies.
    cookies = {}
    cookies[:__http_client_cookies__] = client_opts.cookies.values.join("; ") if client_opts.cookies.any?
    cookies[:__http_session_cookies__] = session_cookies
    request_opts[:cookies] = cookies
  end

  def extract_cookie_from_jar
    return if @jar.empty?
    @jar.cookies.map { |c| "#{c.name}=#{c.value}" }.join("; ")
  end

  def extract_cookie_to_jar(resp)
    req = resp.request
    resp.headers.get(HTTP::Headers::SET_COOKIE).each do |header|
      @jar.parse(header, req.uri)
    end
  end
end
