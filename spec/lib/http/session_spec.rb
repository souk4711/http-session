RSpec.describe HTTP::Session, vcr: true do
  def cache_store(sub)
    sub.cache_mgr.__send__(:store)
  end

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

  describe "#request" do
    describe "opts" do
      it "override session options" do
        sub = described_class.new.follow(false).freeze
        res = sub.get(httpbin("/redirect/1"), follow: true)
        expect(res.code).to eq(200)

        sub = described_class.new.follow(true).freeze
        res = sub.get(httpbin("/redirect/1"), follow: false)
        expect(res.code).to eq(302)
      end

      it "merge session options" do
        sub = described_class.new.headers("A" => "A", "B" => "B").freeze
        res = sub.get(httpbin("/anything"), headers: {"B" => "b", "C" => "C"})
        expect(res.code).to eq(200)
        expect(res.request.headers["A"]).to eq("A")
        expect(res.request.headers["B"]).to eq("b")
        expect(res.request.headers["C"]).to eq("C")
      end
    end

    describe "return" do
      it "a HTTP::Session::Response" do
        sub = described_class.new.freeze

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res).to be_an_instance_of(HTTP::Session::Response)
        expect(res.__getobj__).to be_an_instance_of(HTTP::Response)
        expect(res.__getobj__.body).to be_an_instance_of(HTTP::Response::Body)
        expect(res.request).to be_an_instance_of(HTTP::Session::Request)
        expect(res.request.__getobj__).to be_an_instance_of(HTTP::Request)

        res = sub.get(httpbin("/redirect/1"), follow: true)
        expect(res.code).to eq(200)
        expect(res).to be_an_instance_of(HTTP::Session::Response)
        expect(res.__getobj__).to be_an_instance_of(HTTP::Response)
        expect(res.__getobj__.body).to be_an_instance_of(HTTP::Response::Body)
        expect(res.request).to be_an_instance_of(HTTP::Session::Request)
        expect(res.request.__getobj__).to be_an_instance_of(HTTP::Request)

        res = sub.get(
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

  describe "cache" do
    subject do
      described_class.new(cache: true).freeze
    end

    describe "Basic" do
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
  end

  describe "cookies" do
    subject do
      described_class.new(cookies: true).freeze
    end

    describe "Basic" do
      it "can't use cookies across requests when disabled" do
        sub = described_class.new.freeze

        res = sub.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(302)

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq(nil)
      end

      it "can't use cookies cross site" do
        res = subject.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(302)

        res = subject.get("https://example.com")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq(nil)
      end

      it "can use cookies across requests" do
        res = subject.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(302)

        res = subject.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
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
        sub = described_class.new(cookies: true).cookies(a: 1).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#headers" do
        sub = described_class.new(cookies: true).headers("Cookie" => "a=1").freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#cookies & :cookies" do
        sub = described_class.new(cookies: true).cookies(a: 1).freeze
        res = sub.get(httpbin("/anything"), cookies: {_: "b=2"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2")
      end

      it "Session#headers & :headers" do
        sub = described_class.new(cookies: true).headers("Cookie" => "a=1").freeze
        res = sub.get(httpbin("/anything"), headers: {"Cookie" => "b=2"})
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
        sub = described_class.new(cookies: true).cookies(b: 2).freeze

        res = sub.get(httpbin("/cookies/set?a=1"))
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#headers & set" do
        sub = described_class.new(cookies: true).headers("Cookie" => "b=2").freeze

        res = sub.get(httpbin("/cookies/set?a=1"))
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#cookies & :cookies & set" do
        sub = described_class.new(cookies: true).cookies(b: 2).freeze

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
        sub = described_class.new(cookies: true).headers("Cookie" => "b=2").freeze

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
  end

  describe "persistent" do
    subject do
      described_class.new(persistent: true).freeze
    end

    describe "Basic" do
      it "nil/false" do
        sub = described_class.new.freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("close")

        sub = described_class.new(persistent: false).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("close")
      end

      it "true" do
        sub = described_class.new(persistent: true).freeze
        res = sub.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.headers["Connection"]).to eq("keep-alive")
      end

      it "pools - host" do
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
          pools: {httpbin("/abc") => {}}
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

      it "pools - *" do
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
    end

    describe "Isolated" do
      it "multiple requests using same connection without HTTP::StateError" do
        expect do
          16.times do |i|
            subject.get(httpbin("/anything"), params: {i => i})
          end
        end.to_not raise_error
      end
    end
  end

  describe "redirect" do
    subject do
      described_class.new.follow.freeze
    end

    it "absolute location" do
      res = subject.get(httpbin("/absolute-redirect/1"))
      expect(res.request.uri.to_s).to eq("http://httpbin.org/get")
      expect(res.code).to eq(200)
    end

    it "relative location" do
      res = subject.get(httpbin("/relative-redirect/1"))
      expect(res.request.uri.to_s).to eq("https://httpbin.org/get")
      expect(res.code).to eq(200)
    end

    it "redirect n times" do
      cnt = 0
      res = subject.get(httpbin("/redirect/4"), follow: {on_redirect: ->(_, _) { cnt += 1 }})
      expect(res.code).to eq(200)
      expect(cnt).to eq(4)
    end

    it "redirect without query string" do
      res = subject.get(httpbin("/redirect/1"), params: {q: 1})
      expect(res.request.uri.to_s).to eq("https://httpbin.org/get")
      expect(res.code).to eq(200)
    end

    it "redirect cross site" do
      res = subject.get(httpbin("/redirect-to?url=https://example.com"))
      expect(res.request.uri.to_s).to eq("https://example.com/")
      expect(res.code).to eq(200)
    end

    it "redirect cross site - remove Authorization header" do
      sub1 = described_class.new.headers(Authorization: "Basic <credentials>").follow.freeze
      res1 = sub1.get(httpbin("/redirect-to?url=https://example.com"))

      sub2 = described_class.new.follow.freeze
      res2 = sub2.get(httpbin("/redirect-to?url=https://example.com"), headers: {Authorization: "Basic <credentials>"})

      [res1, res2].each do |res|
        expect(res.history[0].request.headers["Authorization"]).to eq("Basic <credentials>")
        expect(res.history[0].request.headers["Host"]).to eq("httpbin.org")
        expect(res.history[0].code).to eq(302)
        expect(res.request.uri.to_s).to eq("https://example.com/")
        expect(res.request.headers["Authorization"]).to eq(nil)
        expect(res.request.headers["Host"]).to eq("example.com")
        expect(res.code).to eq(200)
      end
    end

    it "too many hops" do
      expect do
        subject.get(httpbin("/redirect/4"), follow: {max_hops: 3})
      end.to raise_error(HTTP::Session::Exceptions::RedirectError, "too many hops")
    end

    context "301" do
      it "GET methods unchanged" do
        res = subject.get(httpbin("/redirect-to?url=/get&status_code=301"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/get"))
        expect(res.request.verb).to eq(:get)
        expect(res.request.body.source).to eq("mybody")
      end

      it "non-GET methods changed to GET (body lost)" do
        sub = described_class.new.follow(strict: false).freeze
        res = sub.post(httpbin("/redirect-to?url=/get&status_code=301"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/get"))
        expect(res.request.verb).to eq(:get)
        expect(res.request.body.source).to eq(nil)
      end
    end

    context "302" do
      it "GET methods unchanged" do
        res = subject.get(httpbin("/redirect-to?url=/get&status_code=302"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/get"))
        expect(res.request.verb).to eq(:get)
        expect(res.request.body.source).to eq("mybody")
      end

      it "non-GET methods changed to GET (body lost)" do
        sub = described_class.new.follow(strict: false).freeze
        res = sub.post(httpbin("/redirect-to?url=/get&status_code=302"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/get"))
        expect(res.request.verb).to eq(:get)
        expect(res.request.body.source).to eq(nil)
      end
    end

    context "303" do
      it "GET methods unchanged" do
        res = subject.get(httpbin("/redirect-to?url=/get&status_code=303"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/get"))
        expect(res.request.verb).to eq(:get)
        expect(res.request.body.source).to eq("mybody")
      end

      it "non-GET methods changed to GET (body lost)" do
        sub = described_class.new.follow(strict: false).freeze
        res = sub.post(httpbin("/redirect-to?url=/get&status_code=303"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/get"))
        expect(res.request.verb).to eq(:get)
        expect(res.request.body.source).to eq(nil)
      end
    end

    context "307" do
      it "GET methods unchanged" do
        res = subject.get(httpbin("/redirect-to?url=/get&status_code=307"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/get"))
        expect(res.request.verb).to eq(:get)
        expect(res.request.body.source).to eq("mybody")
      end

      it "non-GET methods unchanged" do
        res = subject.post(httpbin("/redirect-to?url=/post&status_code=307"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/post"))
        expect(res.request.verb).to eq(:post)
        expect(res.request.body.source).to eq("mybody")
      end
    end

    context "308" do
      it "GET methods unchanged" do
        res = subject.get(httpbin("/redirect-to?url=/get&status_code=308"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/get"))
        expect(res.request.verb).to eq(:get)
        expect(res.request.body.source).to eq("mybody")
      end

      it "non-GET methods unchanged" do
        res = subject.post(httpbin("/redirect-to?url=/post&status_code=308"), body: "mybody")
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq(httpbin("/post"))
        expect(res.request.verb).to eq(:post)
        expect(res.request.body.source).to eq("mybody")
      end
    end

    context "cookies: true" do
      subject do
        described_class.new(cookies: true).follow.freeze
      end

      it "Set-Cookie" do
        res = subject.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(200)

        res = subject.get(httpbin("/anything"))
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "redirect cross site without Cookie" do
        res = subject.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(200)

        res = subject.get(httpbin("/redirect-to?url=https://github.com"))
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq("https://github.com/")
        expect(res.request.headers["Cookie"]).to eq(nil)
      end

      it "redirect cross site with same-origin Cookie" do
        res = subject.get(httpbin("/cookies/set/a/1"))
        expect(res.code).to eq(200)

        res = subject.get("https://github.com")
        expect(res.code).to eq(200)

        res = subject.get(httpbin("/redirect-to?url=https://github.com"))
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq("https://github.com/")
        expect(res.request.headers["Cookie"]).to include("_gh_sess=")
      end
    end

    context "persistent: true" do
      subject do
        described_class.new(persistent: true).follow.freeze
      end

      it "redirect cross site without HTTP::StateError" do
        res = subject.get(httpbin("/redirect-to?url=https://example.com"))
        expect(res.code).to eq(200)
        expect(res.request.uri.to_s).to eq("https://example.com/")
      end
    end
  end

  describe "thread safe" do
    it "cache: true" do
      sub = described_class.new(cache: true).freeze
      res = sub.get(httpbin("/cache/0"))
      Timecop.freeze(res.date)

      thrs = []
      8.times do |i|
        thrs << Thread.new do
          res = sub.get(httpbin("/cache/#{60 * i + 60}"))
          expect(res).to be_cacheable_using_maxage(max_age: 60 * i + 60)
          expect(res.headers["X-Httprb-Cache-Status"]).to eq("MISS")
        end
      end
      thrs.each(&:join)
      expect(cache_store(sub).instance_variable_get("@data").size).to eq(8)

      thrs = []
      8.times do |i|
        thrs << Thread.new do
          res = sub.get(httpbin("/cache/#{60 * i + 60}"))
          expect(res.code).to eq(200)
          expect(res.from_cache?).to eq(true)
          expect(res.headers["X-Httprb-Cache-Status"]).to eq("HIT")
        end
      end
      thrs.each(&:join)
    end

    it "cookies: true" do
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

    it "persistent: true" do
      sub = described_class.new(persistent: true).freeze

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

  describe "HTTP::Features" do
    subject do
      described_class.new(
        cache: true,
        cookies: true,
        persistent: true
      )
    end

    it "logging" do
      io = StringIO.new
      sub = subject.use(logging: {logger: Logger.new(io)}).freeze

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
      sub = subject.use(instrumentation: {instrumenter: ActiveSupport::Notifications.instrumenter}).freeze

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
        subject.use(:auto_inflate).freeze
      }.to raise_error(ArgumentError, /is not supported/)
    end

    it "hsf_auto_inflate" do
      sub = subject.use(:hsf_auto_inflate).freeze
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
      sub = subject.use(hsf_auto_inflate: {br: true}).freeze
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

      sub = subject.use(
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
