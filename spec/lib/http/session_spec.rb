RSpec.describe HTTP::Session, vcr: true do
  def cache_store(sub)
    sub.cache_mgr.__send__(:store)
  end

  describe "#request" do
    let(:subject) { described_class.new.freeze }

    describe "opts" do
      it "override session options" do
        res = subject.dup.follow(false).get(httpbin("/redirect/1"), follow: true)
        expect(res.code).to eq(200)

        res = subject.dup.follow(true).get(httpbin("/redirect/1"), follow: false)
        expect(res.code).to eq(302)
      end

      it "merge session options" do
        res = subject.dup.headers("A" => "A", "B" => "B").get(httpbin("/anything"), headers: {"B" => "b", "C" => "C"})
        expect(res.code).to eq(200)
        expect(res.request.headers["A"]).to eq("A")
        expect(res.request.headers["B"]).to eq("b")
        expect(res.request.headers["C"]).to eq("C")
      end
    end

    describe "return" do
      it "a HTTP::Session::Response" do
        res = subject.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res).to be_an_instance_of(HTTP::Session::Response)
        expect(res.__getobj__).to be_an_instance_of(HTTP::Response)
        expect(res.__getobj__.body).to be_an_instance_of(HTTP::Response::Body)
        expect(res.request).to be_an_instance_of(HTTP::Session::Request)
        expect(res.request.__getobj__).to be_an_instance_of(HTTP::Request)

        res = subject.get(httpbin("/redirect/1"), follow: true)
        expect(res.code).to eq(200)
        expect(res).to be_an_instance_of(HTTP::Session::Response)
        expect(res.__getobj__).to be_an_instance_of(HTTP::Response)
        expect(res.__getobj__.body).to be_an_instance_of(HTTP::Response::Body)
        expect(res.request).to be_an_instance_of(HTTP::Session::Request)
        expect(res.request.__getobj__).to be_an_instance_of(HTTP::Request)

        res = subject.get(
          httpbin("/redirect/1"),
          follow: true,
          features: {logging: {logger: HTTP::Features::Logging::NullLogger.new}}
        )
        expect(res.code).to eq(200)
        expect(res).to be_instance_of(HTTP::Session::Response)
        expect(res.__getobj__).to be_an_instance_of(HTTP::Response)
        expect(res.__getobj__.body).to be_an_instance_of(HTTP::Response::Body)
        expect(res.request).to be_an_instance_of(HTTP::Session::Request)
        expect(res.request.__getobj__).to be_an_instance_of(HTTP::Request)
      end
    end
  end

  describe "redirect" do
    let(:subject) { described_class.new.freeze }

    it "redirect n times" do
      cnt = 0
      res = subject.get(httpbin("/redirect/4"), follow: {
        on_redirect: ->(_, _) { cnt += 1 }
      })
      expect(res.code).to eq(200)
      expect(cnt).to eq(4)
    end
  end

  describe "cache" do
    matcher :be_cacheable_using_etag do |expected|
      match do |actual|
        expect(actual.code).to eq(200)
        expect(actual.etag).to be_a(String)
        expect(actual.last_modified).to be_a(String)
        expect(actual.validateable?).to eq(true)
      end
    end

    matcher :be_cacheable_using_maxage do |expected = {}|
      match do |actual|
        max_age = expected[:max_age] || 60
        expect(actual.code).to eq(200)
        expect(actual.max_age(shared: true)).to eq(max_age)
        expect(actual.age).to eq(0)
        expect(actual.fresh?(shared: true)).to eq(true)
      end
    end

    let(:subject) { described_class.new(cache: true).freeze }

    describe "Basic" do
      it "can use cache across requests" do
        res1 = subject.get(httpbin("/cache"))
        expect(res1).to be_cacheable_using_etag
        expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

        res2 = subject.get(httpbin("/cache"))
        expect(res2.code).to eq(200)
        expect(res2.from_cache?).to eq(true)
        expect(res2.headers["X-Httprb-Cache-Status"]).to eq("REVALIDATED")
        expect(res2.request.headers["If-None-Match"]).to eq(res1.etag)
        expect(res2.request.headers["If-Modified-Since"]).to eq(res1.last_modified)
      end

      it "can't use cache across requests when disabled" do
        sub = described_class.new.freeze

        res1 = sub.get(httpbin("/cache"))
        expect(res1).to be_cacheable_using_etag
        expect(res1.headers["X-Httprb-Cache-Status"]).to eq(nil)
        expect(cache_store(sub)).to eq(nil)

        res2 = sub.get(httpbin("/cache"))
        expect(res2.code).to eq(200)
        expect(res2.from_cache?).to eq(false)
        expect(res2.headers["X-Httprb-Cache-Status"]).to eq(nil)
        expect(res2.request.headers["If-None-Match"]).to eq(nil)
        expect(res2.request.headers["If-Modified-Since"]).to eq(nil)
      end

      it "return a cached HTTP::Session::Response" do
        res1 = subject.get(httpbin("/cache"))
        expect(res1).to be_cacheable_using_etag
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

        res2 = subject.get(httpbin("/cache"))
        expect(res2.code).to eq(200)
        expect(res2.from_cache?).to eq(true)
        expect(res2).to be_an_instance_of(HTTP::Session::Response)
        expect(res2.__getobj__).to be_an_instance_of(HTTP::Response)
        expect(res2.__getobj__.body).to be_an_instance_of(HTTP::Session::Response::StringBody)
        expect(res2.request).to be_an_instance_of(HTTP::Session::Request)
        expect(res2.request.__getobj__).to be_an_instance_of(HTTP::Request)
      end

      it "variant format" do
        uri = jsdelivr("/npm/jquery@3.6.4/dist/jquery.min.js")

        res = subject.get(uri)
        expect(res.code).to eq(200)
        expect(res.body.to_s).to start_with("/*! jQuery v3.6.4 |")

        res = subject.get(uri)
        expect(res.code).to eq(200)
        expect(res.from_cache?).to eq(true)
        expect(res.body.to_s).to start_with("/*! jQuery v3.6.4 |")

        res = subject.get(uri, headers: {"Accept-Encoding" => "gzip"})
        expect(res.code).to eq(200)
        expect(Zlib::Inflate.new(32 + Zlib::MAX_WBITS).inflate(res.body)).to start_with("/*! jQuery v3.6.4 |")

        res = subject.get(uri, headers: {"Accept-Encoding" => "gzip"})
        expect(res.code).to eq(200)
        expect(res.from_cache?).to eq(true)
        expect(Zlib::Inflate.new(32 + Zlib::MAX_WBITS).inflate(res.body)).to start_with("/*! jQuery v3.6.4 |")
      end

      it "thread safe" do
        res = subject.get(httpbin("/cache/0"))
        Timecop.freeze(res.date)

        thrs = []
        8.times do |i|
          thrs << Thread.new do
            res = subject.get(httpbin("/cache/#{60 * i + 60}"))
            expect(res).to be_cacheable_using_maxage(max_age: 60 * i + 60)
            expect(res.headers["X-Httprb-Cache-Status"]).to eq("MISS")
          end
        end
        thrs.each(&:join)
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(8)

        thrs = []
        8.times do |i|
          thrs << Thread.new do
            res = subject.get(httpbin("/cache/#{60 * i + 60}"))
            expect(res.code).to eq(200)
            expect(res.from_cache?).to eq(true)
            expect(res.headers["X-Httprb-Cache-Status"]).to eq("HIT")
          end
        end
        thrs.each(&:join)
      end
    end

    describe "Response Directives" do
      it "Cache-Control: max-age" do
        res = subject.get(httpbin("/cache/0"))
        Timecop.freeze(res.date)

        res1 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "max-age=60"}
        )
        expect(res1).to be_cacheable_using_maxage
        expect(res1.from_cache?).to eq(false)
        expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

        res2 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "max-age=60"}
        )
        expect(res2.code).to eq(200)
        expect(res2.from_cache?).to eq(true)
        expect(res2.headers["X-Httprb-Cache-Status"]).to eq("HIT")
      end

      it "Cache-Control: s-max-age" do
        res = subject.get(httpbin("/cache/0"))
        Timecop.freeze(res.date)

        res1 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "s-maxage=60"}
        )
        expect(res1).to be_cacheable_using_maxage
        expect(res1.from_cache?).to eq(false)
        expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

        res2 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "s-maxage=60"}
        )
        expect(res2.code).to eq(200)
        expect(res2.from_cache?).to eq(true)
        expect(res2.headers["X-Httprb-Cache-Status"]).to eq("HIT")
      end

      it "Cache-Control: no-cache" do
        res = subject.get(httpbin("/cache/0"))
        Timecop.freeze(res.date)

        res1 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "max-age=60, no-cache"}
        )
        expect(res1).to be_cacheable_using_maxage
        expect(res1.from_cache?).to eq(false)
        expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

        res2 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "max-age=60, no-cache"}
        )
        expect(res2.code).to eq(200)
        expect(res2.from_cache?).to eq(false)
        expect(res2.headers["X-Httprb-Cache-Status"]).to eq("EXPIRED")
      end

      it "Cache-Control: no-store" do
        res = subject.get(httpbin("/cache/0"))
        Timecop.freeze(res.date)

        res1 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "max-age=60, no-store"}
        )
        expect(res1).to be_cacheable_using_maxage
        expect(res1.from_cache?).to eq(false)
        expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(0)
      end

      it "Cache-Control: private" do
        res = subject.get(httpbin("/cache/0"))
        Timecop.freeze(res.date)

        res1 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "max-age=60, private"}
        )
        expect(res1).to be_cacheable_using_maxage
        expect(res1.from_cache?).to eq(false)
        expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(0)
      end

      describe "Vary" do
        it "use '*' to indicate that the response is uncacheable" do
          res = subject.get(httpbin("/cache/0"))
          Timecop.freeze(res.date)

          res1 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60", "Vary" => "*"}
          )
          expect(res1).to be_cacheable_using_maxage
          expect(res1.from_cache?).to eq(false)
          expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
          expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

          res2 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60", "Vary" => "*"}
          )
          expect(res2.code).to eq(200)
          expect(res2.from_cache?).to eq(false)
          expect(res2.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        end

        it "use '' to ignore content negotiation" do
          res = subject.get(httpbin("/cache/0"))
          Timecop.freeze(res.date)

          res1 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60", "Vary" => ""},
            headers: {"Accept" => "text/html"}
          )
          expect(res1).to be_cacheable_using_maxage
          expect(res1.from_cache?).to eq(false)
          expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
          expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

          res2 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60", "Vary" => ""},
            headers: {"Accept" => "application/xml"}
          )
          expect(res2.code).to eq(200)
          expect(res2.from_cache?).to eq(true)
          expect(res2.headers["X-Httprb-Cache-Status"]).to eq("HIT")
        end

        it "headers matched" do
          res = subject.get(httpbin("/cache/0"))
          Timecop.freeze(res.date)

          res1 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60", "Vary" => "Accept"},
            headers: {"Accept" => "text/html"}
          )
          expect(res1).to be_cacheable_using_maxage
          expect(res1.from_cache?).to eq(false)
          expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
          expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

          res2 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60", "Vary" => "Accept"},
            headers: {"Accept" => "text/html"}
          )
          expect(res2.code).to eq(200)
          expect(res2.from_cache?).to eq(true)
          expect(res2.headers["X-Httprb-Cache-Status"]).to eq("HIT")
        end

        it "headers unmatched" do
          res = subject.get(httpbin("/cache/0"))
          Timecop.freeze(res.date)

          res1 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60", "Vary" => "Accept"},
            headers: {"Accept" => "text/html"}
          )
          expect(res1).to be_cacheable_using_maxage
          expect(res1.from_cache?).to eq(false)
          expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
          expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

          res2 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60", "Vary" => "Accept"},
            headers: {"Accept" => "application/xml"}
          )
          expect(res2.code).to eq(200)
          expect(res2.from_cache?).to eq(false)
          expect(res2.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        end
      end

      describe "Age" do
        it "a cache MUST generate the field when using a fresh entry" do
          res = subject.get(httpbin("/cache/0"))
          Timecop.freeze(res.date)

          res1 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60"}
          )
          expect(res1).to be_cacheable_using_maxage
          expect(res1.from_cache?).to eq(false)
          expect(res1.headers["Age"]).to eq(nil)
          expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

          Timecop.freeze(res1.date + 2)
          res2 = subject.get(
            httpbin("/response-headers"),
            params: {"Cache-Control" => "max-age=60"}
          )
          expect(res2.code).to eq(200)
          expect(res2.from_cache?).to eq(true)
          expect(res2.headers["Age"]).to eq("2")
        end
      end
    end

    describe "Request Directives" do
      it "Cache-Control: no-cache" do
        res = subject.get(httpbin("/cache/0"))
        Timecop.freeze(res.date)

        res1 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "max-age=60"}
        )
        expect(res1).to be_cacheable_using_maxage
        expect(res1.from_cache?).to eq(false)
        expect(res1.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(1)

        res2 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "max-age=60"},
          headers: {"Cache-Control" => "no-cache"}
        )
        expect(res2.code).to eq(200)
        expect(res2.from_cache?).to eq(false)
        expect(res2.headers["X-Httprb-Cache-Status"]).to eq("EXPIRED")
      end

      it "Cache-Control: no-store" do
        res = subject.get(httpbin("/cache/0"))
        Timecop.freeze(res.date)

        res1 = subject.get(
          httpbin("/response-headers"),
          params: {"Cache-Control" => "max-age=60"},
          headers: {"Cache-Control" => "no-store"}
        )
        expect(res1).to be_cacheable_using_maxage
        expect(res1.from_cache?).to eq(false)
        expect(res1.headers["X-Httprb-Cache-Status"]).to eq("UNCACHEABLE")
        expect(cache_store(subject).instance_variable_get("@data").size).to eq(0)
      end
    end

    describe "HTTP::Features" do
      it "logging" do
        io = StringIO.new
        sub = described_class.new(cache: true).use(logging: {logger: Logger.new(io)}).freeze

        res1 = sub.get(httpbin("/cache"))
        expect(res1).to be_cacheable_using_etag
        expect(cache_store(sub).instance_variable_get("@data").size).to eq(1)

        out1 = (io.rewind && io.read).tap { io.truncate(0) }
        expect(out1.scan("< 200 OK").count).to eq(1)

        res2 = sub.get(httpbin("/cache"))
        expect(res2.code).to eq(200)
        expect(res2.from_cache?).to eq(true)

        out2 = (io.rewind && io.read).tap { io.truncate(0) }
        expect(out2.scan("< 200 OK").count).to eq(1)
      end

      it "instrumentation" do
        res_arr = []
        ActiveSupport::Notifications.subscribe("request.http") do |name, start, finish, id, payload|
          res_arr << payload[:response]
        end

        require "active_support/isolated_execution_state"
        sub = described_class.new(cache: true).use(instrumentation: {instrumenter: ActiveSupport::Notifications.instrumenter}).freeze

        res1 = sub.get(httpbin("/cache"))
        expect(res1).to be_cacheable_using_etag
        expect(res_arr).to eql([res1])
        expect(cache_store(sub).instance_variable_get("@data").size).to eq(1)

        res2 = sub.get(httpbin("/cache"))
        expect(res2.code).to eq(200)
        expect(res2.from_cache?).to eq(true)
        expect(res_arr).to eql([res1, res2])
      end

      it "auto_inflate" do
        expect {
          described_class.new(cache: true).use(:auto_inflate).freeze
        }.to raise_error(ArgumentError, /is not supported/)
      end

      it "hsf_auto_inflate" do
        sub = described_class.new(cache: true).use(:hsf_auto_inflate).freeze
        uri = jsdelivr("/npm/jquery@3.6.4/dist/jquery.min.js")

        res = sub.get(uri)
        expect(res.code).to eq(200)
        expect(res.body.to_s).to start_with("/*! jQuery v3.6.4 |")

        res = sub.get(uri)
        expect(res.code).to eq(200)
        expect(res.from_cache?).to eq(true)
        expect(res.body.to_s).to start_with("/*! jQuery v3.6.4 |")

        res = sub.get(uri, headers: {"Accept-Encoding" => "gzip"})
        expect(res.code).to eq(200)
        expect(res.body.to_s).to start_with("/*! jQuery v3.6.4 |")

        res = sub.get(uri, headers: {"Accept-Encoding" => "gzip"})
        expect(res.code).to eq(200)
        expect(res.from_cache?).to eq(true)
        expect(res.body.to_s).to start_with("/*! jQuery v3.6.4 |")
      end

      it "hsf_auto_inflate - br", skip: (RUBY_ENGINE == "jruby" && "gem 'brotli' not works in JRuby") do
        sub = described_class.new(cache: true).use(hsf_auto_inflate: {br: true}).freeze
        uri = jsdelivr("/npm/jquery@3.6.4/dist/jquery.min.js")

        res = sub.get(uri, headers: {"Accept-Encoding" => "br"})
        expect(res.code).to eq(200)
        expect(res.body.to_s).to start_with("/*! jQuery v3.6.4 |")

        res = sub.get(uri, headers: {"Accept-Encoding" => "br"})
        expect(res.code).to eq(200)
        expect(res.from_cache?).to eq(true)
        expect(res.body.to_s).to start_with("/*! jQuery v3.6.4 |")
      end

      it "handle responses in the reverse order from the requests" do
        feature_class_order =
          Class.new(HTTP::Feature) do
            @order = []

            class << self
              attr_reader :order
            end

            def initialize(id:)
              @id = id
            end

            def wrap_request(req)
              self.class.order << "request.#{@id}"
              req
            end

            def wrap_response(res)
              self.class.order << "response.#{@id}"
              res
            end
          end
        feature_instance_a = feature_class_order.new(id: "a")
        feature_instance_b = feature_class_order.new(id: "b")
        feature_instance_c = feature_class_order.new(id: "c")

        sub = described_class.new(cache: true).use(
          test_feature_a: feature_instance_a,
          test_feature_b: feature_instance_b,
          test_feature_c: feature_instance_c
        ).freeze
        sub.get(httpbin("/cache"))

        expect(feature_class_order.order).to eq(
          ["request.a", "request.b", "request.c", "response.c", "response.b", "response.a"]
        )
      end
    end
  end

  describe "cookies" do
    let(:subject) { described_class.new(cookies: true).freeze }

    describe "Basic" do
      it "can use cookies across requests" do
        res = subject.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(302)

        res = subject.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "can't use cookies across requests when disabled" do
        sub = described_class.new.freeze

        res = sub.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(302)

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq(nil)
      end

      it "thread safe" do
        sub = described_class.new(cookies: true).follow.freeze

        thrs = []
        8.times do |i|
          thrs << Thread.new do
            res = sub.get(httpbin("/cookies/set/#{i}/#{i * 2}"))
            expect(res.code).to eq(200)
          end
        end
        thrs.each(&:join)

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("0=0; 1=2; 2=4; 3=6; 4=8; 5=10; 6=12; 7=14")
      end
    end

    describe "Cookie" do
      it ":cookies" do
        res = subject.get(httpbin("/anything"), cookies: {_: "a=1"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it ":headers" do
        res = subject.get(httpbin("/anything"), headers: {"Cookie" => "a=1"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#cookies" do
        res = subject.dup.cookies(a: 1).get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#headers" do
        res = subject.dup.headers("Cookie" => "a=1").get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#cookies & :cookies" do
        res = subject.dup.cookies(a: 1).get(httpbin("/anything"), cookies: {_: "b=2"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2")
      end

      it "Session#headers & :headers" do
        res = subject.dup.headers("Cookie" => "a=1").get(httpbin("/anything"), headers: {"Cookie" => "b=2"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2")
      end
    end

    describe "Set-Cookie" do
      it "set" do
        res = subject.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(302)

        res = subject.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "multiple" do
        res = subject.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(302)

        res = subject.get(httpbin("/cookies/set/b/2"))
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("a=1")

        res = subject.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1; b=2")
      end

      it "override" do
        res = subject.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(302)

        res = subject.get(httpbin("/cookies/set/a/2"))
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("a=1")

        res = subject.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=2")
      end

      it "delete" do
        res = subject.get(httpbin("/cookies/set?a=1"))
        expect(res.code).to eq(302)

        res = subject.get(httpbin("/cookies/delete?a="))
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("a=1")

        res = subject.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq(nil)
      end
    end

    describe "Cookie & Set-Cookie" do
      it ":cookies & set" do
        res = subject.get(httpbin("/cookies/set?a=1"), cookies: {_: "b=2"})
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = subject.get(httpbin("/anything"), cookies: {_: "b=2"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it ":headers & set" do
        res = subject.get(httpbin("/cookies/set?a=1"), headers: {"Cookie" => "b=2"})
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = subject.get(httpbin("/anything"), headers: {"Cookie" => "b=2"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#cookies & set" do
        sub = subject.dup.cookies(b: 2)

        res = sub.get(httpbin("/cookies/set?a=1"))
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#headers & set" do
        sub = subject.dup.headers("Cookie" => "b=2")

        res = sub.get(httpbin("/cookies/set?a=1"))
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#cookies & :cookies & set" do
        sub = subject.dup.cookies(b: 2)

        res = sub.get(httpbin("/cookies/set?a=1"), cookies: {_: "c=3"})
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("c=3")

        res = sub.get(httpbin("/anything"), cookies: {_: "d=4"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("d=4; a=1")

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#headers & :headers & set" do
        sub = subject.dup.headers("Cookie" => "b=2")

        res = sub.get(httpbin("/cookies/set?a=1"), headers: {"Cookie" => "c=3"})
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("c=3")

        res = sub.get(httpbin("/anything"), headers: {"Cookie" => "d=4"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("d=4; a=1")

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end
    end

    describe "Redirect" do
      it "keep Set-Cookie" do
        res = subject.get(httpbin("/cookies/set/a/1"), follow: true)
        expect(res.code).to eq(200)

        res = subject.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end
    end
  end

  describe "persistent" do
    describe "Basic" do
      it "opts - nil/false" do
        sub = described_class.new.freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("close")

        sub = described_class.new(persistent: false).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("close")
      end

      it "opts - true" do
        sub = described_class.new(persistent: true).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("keep-alive")
      end

      it "opts - pools - host" do
        sub = described_class.new(persistent: {
          pools: {HTTP::URI.parse(httpbin("/")).origin => nil}
        }).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("close")

        sub = described_class.new(persistent: {
          pools: {HTTP::URI.parse(httpbin("/")).origin => false}
        }).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("close")

        sub = described_class.new(persistent: {
          pools: {HTTP::URI.parse(httpbin("/")).origin => true}
        }).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("keep-alive")

        sub = described_class.new(persistent: {
          pools: {HTTP::URI.parse(httpbin("/")).origin => {}}
        }).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("keep-alive")

        sub = described_class.new(persistent: {
          pools: {
            HTTP::URI.parse(httpbin("/")).origin => false,
            "*" => true
          }
        }).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("close")
      end

      it "opts - pools - *" do
        sub = described_class.new(persistent: {
          pools: {"*" => nil}
        }).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("close")

        sub = described_class.new(persistent: {
          pools: {"*" => false}
        }).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("close")

        sub = described_class.new(persistent: {
          pools: {"*" => true}
        }).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("keep-alive")

        sub = described_class.new(persistent: {
          pools: {"*" => {}}
        }).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("keep-alive")
      end

      it "thread safe" do
        sub = described_class.new(persistent: {
          pools: {
            HTTP::URI.parse(httpbin("/")).origin => {maxsize: 2}
          }
        }).freeze

        thrs = []
        8.times do |i|
          thrs << Thread.new do
            res = sub.get(httpbin("/anything"), params: {i => i})
            expect(res.code).to eq(200)
            expect(res.headers["Connection"]).to eq("keep-alive")
            expect(JSON.parse(res.body)["args"]).to eq({i.to_s => i.to_s})
          end
        end
        thrs.each(&:join)
      end
    end

    describe "Redirect" do
    end
  end
end
