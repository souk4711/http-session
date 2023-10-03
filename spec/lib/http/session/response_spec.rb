RSpec.describe HTTP::Session::Response, vcr: true do
  let(:subject) { HTTP::Session.new.freeze }

  describe "#history" do
    it "empty if no redirection" do
      res = subject.get(httpbin("/redirect/2"))
      expect(res.code).to eq(302)
      expect(res.history.count).to eq(0)
    end

    it "holding the history of the redirection" do
      res = subject.get(httpbin("/redirect/2"), follow: true)
      expect(res.code).to eq(200)
      expect(res.history.count).to eq(2)
      expect(res.history.map { |e| e.class }).to eq([HTTP::Session::Response, HTTP::Session::Response])
      expect(res.history.map { |e| e.request.class }).to eq([HTTP::Session::Request, HTTP::Session::Request])
      expect(res.history[0].request.uri.to_s).to eq(httpbin("/redirect/2"))
      expect(res.history[1].request.uri.to_s).to eq(httpbin("/relative-redirect/1"))
      expect(res.request.uri.to_s).to eq(httpbin("/get"))
    end
  end

  describe "#cacheable?" do
    it "etag" do
      res = subject.get(httpbin("/cache"))
      expect(res.code).to eq(200)
      expect(res.cache_control.no_store?).to eq(nil)
      expect(res.cache_control.private?).to eq(nil)
      expect(res.validateable?).to eq(true)
      expect(res.ttl(shared: true)).to eq(nil)
      expect(res.fresh?(shared: true)).to eq(nil)
      expect(res.cacheable?(shared: true)).to eq(true)
    end

    it "max-age" do
      res = subject.get(httpbin("/response-headers"), params: {"Cache-Control" => "public, max-age=60", "Age" => "30"})
      expect(res.code).to eq(200)
      expect(res.cache_control.no_store?).to eq(nil)
      expect(res.cache_control.private?).to eq(nil)
      expect(res.validateable?).to eq(false)
      expect(res.ttl(shared: true)).to eq(30)
      expect(res.fresh?(shared: true)).to eq(true)
      expect(res.cacheable?(shared: true)).to eq(true)
    end

    it "s-maxage" do
      res = subject.get(httpbin("/response-headers"), params: {"Cache-Control" => "public, max-age=60, s-maxage=15", "Age" => "30"})
      expect(res.code).to eq(200)
      expect(res.ttl(shared: true)).to eq(-15)
      expect(res.fresh?(shared: true)).to eq(false)
      expect(res.cacheable?(shared: true)).to eq(false)
      expect(res.ttl(shared: false)).to eq(30)
      expect(res.fresh?(shared: false)).to eq(true)
      expect(res.cacheable?(shared: false)).to eq(true)
    end

    it "no-cache" do
      res = subject.get(httpbin("/response-headers"), params: {"Cache-Control" => "public, max-age=60, no-cache", "Age" => "30"})
      expect(res.code).to eq(200)
      expect(res.cache_control.no_cache?).to eq(true)
      expect(res.cacheable?(shared: true)).to eq(true)
    end

    it "no-store" do
      res = subject.get(httpbin("/response-headers"), params: {"Cache-Control" => "public, max-age=60, no-store", "Age" => "30"})
      expect(res.code).to eq(200)
      expect(res.cache_control.no_store?).to eq(true)
      expect(res.cacheable?(shared: true)).to eq(false)
    end

    it "private" do
      res = subject.get(httpbin("/response-headers"), params: {"Cache-Control" => "private, max-age=60", "Age" => "30"})
      expect(res.code).to eq(200)
      expect(res.cache_control.private?).to eq(true)
      expect(res.cacheable?(shared: true)).to eq(false)
      expect(res.cacheable?(shared: false)).to eq(true)
    end
  end

  describe "#date" do
    it "default to Time.now" do
      res = subject.get(httpbin("/delay/0"))
      now = Time.httpdate(res.headers["Date"])
      Timecop.freeze(res.date)

      res = HTTP.get(httpbin("/delay/1"))
      res.headers.delete("Date")
      res = HTTP::Session::Response.new(res)
      expect(res.date.to_i).to eq(now.to_i)
    end

    it "read from headers" do
      res = subject.get(httpbin("/delay/0"))
      now = Time.httpdate(res.headers["Date"])
      Timecop.freeze(res.date)

      res = subject.get(httpbin("/delay/1"))
      expect(res.date.to_i).to be > (now.to_i + 1)
    end
  end
end
