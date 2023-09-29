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
    data = build_http_request_data
    handle_http_request_options_cookies(@options.http, opts, data)
    handle_http_request_options_follow(@options.http, opts, data)

    c = HTTP::Client.new(@options.http)
    c.request(verb, uri, opts).tap do |resp|
      handle_http_response(resp, data)
    end
  end

  private

  def build_http_request_data
    synchronize do
      {
        cookies: extract_cookie_from_jar, # session cookies
        history: [] # a list of response objects holding the history of the redirection
      }
    end
  end

  def handle_http_response(resp, data)
    synchronize do
      extract_cookie_to_jar(resp, data)
    end
  end

  # Add session cookie to the request's :cookies.
  def handle_http_request_options_cookies(client_opts, request_opts, data)
    session_cookies = data[:cookies]
    return if session_cookies.nil?

    # Add it.
    if request_opts.key?(:cookies)
      request_opts[:cookies][:__http_session_cookies__] = session_cookies
      return
    end

    # Prevent client cookies from being overridden.
    client_cookies = client_opts.cookies.any? ? client_opts.cookies.values.join("; ") : nil
    request_opts[:cookies] = {
      __http_client_cookies__: client_cookies,
      __http_session_cookies__: session_cookies
    }.compact
  end

  # Wrap the :on_redirect method in the request's :follow.
  def handle_http_request_options_follow(client_opts, request_opts, data)
    follow = request_opts.key?(:follow) ? request_opts[:follow] : client_opts.follow
    return unless follow

    follow = {} if follow == true
    request_opts[:follow] = follow.merge(
      on_redirect: handle_http_request_options_follow_hijack(follow[:on_redirect], data)
    )
  end

  def handle_http_request_options_follow_hijack(o, data)
    lambda do |resp, req|
      data[:history] << resp
      o.call(resp, req) if o.respond_to?(:call)
    end
  end

  def extract_cookie_from_jar
    return if @jar.empty?
    @jar.cookies.map { |c| "#{c.name}=#{c.value}" }.join("; ")
  end

  def extract_cookie_to_jar(resp, data)
    all = ([] << data[:history] << resp).flatten
    all.each do |r|
      req = r.request
      r.headers.get(HTTP::Headers::SET_COOKIE).each do |header|
        @jar.parse(header, req.uri)
      end
    end
  end
end
