# HTTP::Session

HTTP::Session - a session abstraction for [http.rb] in order to support **cookies** and **caching**.


## Quickstart

### Install

Add this line to your application's Gemfile:

```ruby
gem 'ruby-http-session', require: "http-session"
```

### Cookies

The cookies are automatically set each time a request is made.

```ruby
require "http-session"

http = HTTP.session(cookies: true)
  .follow
  .timeout(8)
  .freeze

r = http.get("https://httpbin.org/cookies/set/mycookies/abc")
pp JSON.parse(r.body)["cookies"]  # -> {"mycookies"=>"abc"}

r = http.get("https://httpbin.org/cookies")
pp JSON.parse(r.body)["cookies"]  # -> {"mycookies"=>"abc"}
```

### Caching

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

**This only takes 1 time to deliver the request to the origin server:**

```ruby
require "http-session"

http = HTTP.session(cache: true)
  .follow
  .timeout(8)
  .freeze

60.times do
  http.get("https://cdn.jsdelivr.net/npm/jquery@3.6.4/dist/jquery.min.js")
end
```

### Thread Safe

The following **HTTP::Session** methods are thread-safe:

* **head**
* **get**
* **post**
* **put**
* **delete**
* **trace**
* **options**
* **connect**
* **patch**
* **request**


## Reference

### Caching

#### Shared Cache

A [shared cache] is a cache that stores responses for **reuse by more than one user**; shared caches
are usually (but not always) deployed as a part of an intermediary. **This is used by default**.

**Note**: Responses for requests with **Authorization** header fields will not be stored in a shared
cache unless explicitly allowed. Read [rfc9111#section-3.5] for more.

```ruby
http = HTTP.session(cache: true) # or HTTP.session(cache: {shared: true})
  .follow
  .timeout(8)
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

#### Private Cache

A [private cache], in contrast, is **dedicated to a single user**; often, they are deployed as a
component of a user agent.

```ruby
http = HTTP.session(cache: {private: true})
  .follow
  .timeout(8)
  .freeze
```

#### Cache Store

The default cache store is `ActiveSupport::Cache::MemoryStore`, which resides on the client instance. You
can use ths `:store` option to set another store, e.g. `ActiveSupport::Cache::MemCacheStore`.

```ruby
store = ActiveSupport::Cache::MemCacheStore.new("localhost", "server-downstairs.localnetwork:8229")
http = HTTP.session(cache: {store: store})
  .follow
  .timeout(8)
  .freeze
```

#### Cache Status

The following value is used in the `X-Httprb-Cache-Status` response header:

* **HIT**: found in cache
* **REVALIDATED**: found in cache but stale, revalidated success
* **EXPIRED**: found in cache but stale, revalidated failure, served from the origin server
* **MISS**: not found in cache, served from the origin server
* **UNCACHEABLE**: the request can not use cached response

### HTTP::Features

#### logging

Log requests and responses.

```ruby
require "http-session"
require "logger"

http = HTTP.session(cache: true)
  .follow
  .timeout(8)
  .use(logging: { logger: Logger.new($stdout) })
  .freeze

http.get("https://httpbin.org/get")
# I, [2023-10-07T13:17:42.208296 #2708620]  INFO -- : > GET https://httpbin.org/get
# D, [2023-10-07T13:17:42.208349 #2708620] DEBUG -- : Connection: close
# Host: httpbin.org
# User-Agent: http.rb/5.1.1
# ...
```

#### instrumentation

Instrument requests and responses. Expects an ActiveSupport::Notifications-compatible instrumenter.

```ruby
require "http-session"
require "active_support/all"

ActiveSupport::Notifications.subscribe('start_request.http') do |name, start, finish, id, payload|
  pp start: start, req: payload[:request].inspect
end

ActiveSupport::Notifications.subscribe('request.http') do |name, start, finish, id, payload|
  pp start: start, req: payload[:request].inspect, res: payload[:response].inspect
end

http = HTTP.session(cache: true)
  .follow
  .timeout(8)
  .use(instrumentation: { instrumenter: ActiveSupport::Notifications.instrumenter })
  .freeze

http.get("https://httpbin.org/get")
# {:start=>2023-10-07 13:14:36.953487129 +0800, :req=>"#<HTTP::Request/1.1 GET https://httpbin.org/get>"}
# {:start=>2023-10-07 13:14:36.954112865 +0800,
#  :req=>"nil",
#  :res=>"#<HTTP::Response/1.1 200 OK {\"Date\"=>\"Sat, 07 Oct 2023 05:14:37 GMT\", \"Content-Type\"=>\"application/json\", \"Content-Length\"=>\"236\", \"Connection\"=>\"close\", \"Server\"=>\"gunicorn/19.9.0\", \"Access-Control-Allow-Origin\"=>\"*\", \"Access-Control-Allow-Credentials\"=>\"true\", \"X-Httprb-Cache-Status\"=>\"MISS\"}>"}
```

#### hsf_auto_inflate

Simlar to `auto_inflate`, used for automatically decompressing the response body.

```ruby
require "http-session"
require "brotli"

http = HTTP.session(cache: true)
  .follow
  .timeout(8)
  .use(hsf_auto_inflate: {br: true})
  .freeze

res = http.get("https://cdn.jsdelivr.net/npm/jquery@3.6.4/dist/jquery.min.js", headers: {"Accept-Encoding" => "br"})
pp res.body.to_s  # => "/*! jQuery v3.6.4 | ...
```

### Intergate with WebMock

```ruby
require "http-session/webmock"
```


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
[rfc9111#section-3.5]:https://datatracker.ietf.org/doc/html/rfc9111/#section-3.5
[shared cache]:https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching#shared_cache
[private cache]:https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching#private_caches
[http.rb]:https://github.com/httprb/http
