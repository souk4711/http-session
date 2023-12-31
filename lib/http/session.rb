require "forwardable"
require "http"
require "monitor"
require "set"

require_relative "session/exceptions"
require_relative "session/options/optionable"
require_relative "session/options/cache_option"
require_relative "session/options/cookies_option"
require_relative "session/options/persistent_option"
require_relative "session/options"
require_relative "session/cache/cache_control"
require_relative "session/cache/entry"
require_relative "session/cache/status"
require_relative "session/cache"
require_relative "session/cookies"
require_relative "session/connection_pool"
require_relative "session/pool_manager"
require_relative "session/request"
require_relative "session/response/string_body"
require_relative "session/response"
require_relative "session/features/auto_inflate"
require_relative "session/features"
require_relative "session/context/follow_context"
require_relative "session/context"
require_relative "session/client/perform"
require_relative "session/client"
require_relative "session/redirector"
require_relative "session/configurable"
require_relative "session/requestable"
require_relative "session/version"

# Use session to manage cookies and cache across requests.
class HTTP::Session
  include HTTP::Session::Configurable
  include HTTP::Session::Requestable

  # @!visibility private
  attr_reader :default_options

  # @!visibility private
  attr_reader :cookies_mgr

  # @!visibility private
  attr_reader :cache_mgr

  # @param [Hash] default_options
  # @option default_options [Boolean, Hash] :cookies session cookies option
  # @option default_options [Boolean, Hash] :cache session cache option
  # @option default_options [Boolean, Hash] :persistent session persistent option
  # @option default_options [Hash] :http http client options
  def initialize(default_options = {})
    super()

    @default_options = HTTP::Session::Options.new(default_options)
    @cookies_mgr = HTTP::Session::Cookies.new(@default_options.cookies)
    @cache_mgr = HTTP::Session::Cache.new(@default_options.cache)
    @pool_mgr = HTTP::Session::PoolManager.new(@default_options.persistent, self)
  end

  # @param verb
  # @param uri
  # @param [Hash] opts
  # @return [Response]
  def request(verb, uri, opts = {})
    http_opts = @default_options.http.merge(opts)
    opts[:follow] = false

    res = perform(verb, uri, opts)
    return res unless http_opts.follow

    redirector = HTTP::Session::Redirector.new(http_opts.follow)
    redirector.perform(res) do |new_verb, new_uri, follow_ctx|
      new_opts = follow_ctx.same_origin? ? opts : {}
      ctx = HTTP::Session::Context.new(follow: follow_ctx)
      perform(new_verb, new_uri, new_opts, ctx)
    end
  end

  # @!visibility private
  def freeze
    super.tap do
      default_options.freeze
    end
  end

  private

  def perform(verb, uri, opts, ctx = nil)
    @pool_mgr.with(uri) do |c|
      c.request(verb, uri, opts, ctx)
    end
  end
end
