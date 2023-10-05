require "http"
require "monitor"

require_relative "session/cache/cache_control"
require_relative "session/cache/entry"
require_relative "session/cache/status"
require_relative "session/cache"
require_relative "session/client/perform"
require_relative "session/client"
require_relative "session/configurable"
require_relative "session/features/auto_inflate"
require_relative "session/options/cache_option"
require_relative "session/options/cookies_option"
require_relative "session/options"
require_relative "session/request"
require_relative "session/requestable"
require_relative "session/response/string_body"
require_relative "session/response"
require_relative "session/version"

# Use session to manage cookies and cache across requests.
class HTTP::Session
  include MonitorMixin
  include HTTP::Session::Configurable
  include HTTP::Session::Requestable

  # @!attribute [r] default_options
  #   @return [Options]
  attr_reader :default_options

  # @!attribute [r] cache
  #   @return [Cache]
  attr_reader :cache

  # @param [Hash] default_options
  # @option default_options [Boolean, Hash] :cookies session cookies option
  # @option default_options [Boolean, Hash] :cache session cache option
  # @option default_options [Hash] :http http client options
  def initialize(default_options = {})
    super()

    @default_options = HTTP::Session::Options.new(default_options)
    @cache = HTTP::Session::Cache.new(@default_options.cache)
    @jar = HTTP::CookieJar.new
  end

  # @param verb
  # @param uri
  # @param [Hash] opts
  # @return [Response]
  def request(verb, uri, opts = {})
    c = HTTP::Session::Client.new(@default_options.http, self)
    c.request(verb, uri, opts).tap do |res|
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
    return unless @default_options.cookies.enabled?

    return if @jar.empty?
    @jar.cookies.each_with_object({}) { |c, h| h[c.name] = c.value }
  end

  def extract_cookie_to_jar(res)
    return unless @default_options.cookies.enabled?

    all = ([] << res.history << res).flatten
    all.each do |r|
      req = r.request
      r.headers.get(HTTP::Headers::SET_COOKIE).each do |header|
        @jar.parse(header, req.uri)
      end
    end
  end
end
