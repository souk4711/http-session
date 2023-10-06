# HTTP::Session

HTTP::Session - a session abstraction for [http.rb] in order to support **cookies** and **caching**.

## Intro

### Cache

**This takes 1 minute:**

```ruby
require "active_support/all"
require "http"

ActiveSupport::Notifications.subscribe('start_request.http') do |name, start, finish, id, payload|
  pp start: start, req: payload[:request].inspect
end

http = HTTP
  .follow
  .timeout(8)
  .use(instrumentation: { instrumenter: ActiveSupport::Notifications.instrumenter })

60.times do
  http.get("https://cdn.jsdelivr.net/npm/jquery@3.6.4/dist/jquery.min.js", headers: {"Accept-Encoding" => ""})
end
```

**This takes 1 second:**

```ruby
require "active_support/all"
require "http-session"

ActiveSupport::Notifications.subscribe('start_request.http') do |name, start, finish, id, payload|
  pp start: start, req: payload[:request].inspect
end

http = HTTP.session(cache: true)
  .follow
  .timeout(8)
  .use(instrumentation: { instrumenter: ActiveSupport::Notifications.instrumenter })

60.times do
  http.get("https://cdn.jsdelivr.net/npm/jquery@3.6.4/dist/jquery.min.js", headers: {"Accept-Encoding" => ""})
end
```

When responses can be reused from a cache, taking into account [HTTP RFC 9111] rules for user agents and
shared caches. The following headers are used to determine whether the response is cacheable or not:

* `Cache-Control` request header
  * `no-store`
  * `no-cache`
* `Cache-Control` response header
  * `no-store`
  * `no-cache`
  * `private`
  * `public`
  * `max-age`
  * `s-maxage`
* `Etag` & `Last-Modified` response header for conditional requests
* `Vary` response header for content negotiation


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'http-session'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install http-session


## Usage

### Shared Cache

A [shared cache] is a cache that stores responses for **reuse by more than one user**; shared caches
are usually (but not always) deployed as a part of an intermediary. This is used by default.

```ruby
http = HTTP.session(cache: true) # or HTTP.session(cache: {shared: true})
  .follow
  .timeout(4)
  .use(hsf_auto_inflate: {br: true})
  .freeze

res = http.get("https://cdn.jsdelivr.net/npm/jquery@3.6.4/dist/jquery.min.js")
p "cache-status: #{res.headers["x-httprb-cache-status"]}" # => miss

res = http.get("https://cdn.jsdelivr.net/npm/jquery@3.6.4/dist/jquery.min.js")
p "cache-status: #{res.headers["x-httprb-cache-status"]}" # => hit

res = http.get("https://cdn.jsdelivr.net/npm/jquery@3.6.4/dist/jquery.min.js", headers: {"cache-control" => "no-cache"})
p "cache-status: #{res.headers["x-httprb-cache-status"]}" # => revalidated

res = http.get("https://cdn.jsdelivr.net/npm/jquery@3.6.4/dist/jquery.min.js", headers: {"cache-control" => "no-store"})
p "cache-status: #{res.headers["x-httprb-cache-status"]}" # => uncacheable
```

### Private Cache

A [private cache], in contrast, is **dedicated to a single user**; often, they are deployed as a
component of a user agent.

```ruby
http = HTTP.session(cache: {private: true})
  .follow
  .timeout(4)
  .use(hsf_auto_inflate: {br: true})
  .freeze
```

### Cache Store

The default cache store is `ActiveSupport::Cache::MemoryStore`, which resides on the client instance. You
can use ths `:store` option to set another store, e.g. `ActiveSupport::Cache::MemCacheStore`.

```ruby
store = ActiveSupport::Cache::MemCacheStore.new("localhost", "server-downstairs.localnetwork:8229")
http = HTTP.session(cache: {store: store})
  .follow
  .timeout(4)
  .use(hsf_auto_inflate: {br: true})
  .freeze
```

### HTTP::Features

The following features can work with `http-session`:

* [logging]: Log requests and responses.
* [instrumentation]: Instrument requests and responses. Expects an ActiveSupport::Notifications-compatible instrumenter.
* [hsf_auto_inflate]: Simlar to [auto_inflate], used for automatically decompressing the response body.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/souk4711/http-session. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/souk4711/http-session/blob/main/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Code of Conduct

Everyone interacting in the HTTP::Session project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/souk4711/http-session/blob/main/CODE_OF_CONDUCT.md).


[HTTP RFC 9111]:https://datatracker.ietf.org/doc/html/rfc9111/
[shared cache]:https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching#shared_cache
[private cache]:https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching#private_caches
[http.rb]:https://github.com/httprb/http
[logging]:https://github.com/httprb/http/wiki/Logging-and-Instrumentation#logging
[instrumentation]:https://github.com/httprb/http/wiki/Logging-and-Instrumentation#instrumentation
[auto_inflate]:https://github.com/httprb/http/wiki/Compression#automatic-inflating
[hsf_auto_inflate]:https://github.com/souk4711/http-session/blob/main/lib/http/session/features/auto_inflate.rb
