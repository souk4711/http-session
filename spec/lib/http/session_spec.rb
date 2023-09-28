RSpec.describe HTTP::Session, vcr: true do
  let(:subject) { HTTP::Session.new }

  describe "cookies" do
    describe "Cookie" do
      it ":cookies" do
        resp = subject.get("https://httpbin.org/", cookies: {_: "a=1"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it ":headers" do
        resp = subject.get("https://httpbin.org/", headers: {"Cookie" => "a=1"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it "#cookies" do
        resp = subject.cookies(a: 1).get("https://httpbin.org/")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it "#headers" do
        resp = subject.headers("Cookie" => "a=1").get("https://httpbin.org/")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it "#cookies & :cookies" do
        resp = subject.cookies(a: 1).get("https://httpbin.org/", cookies: {_: "b=2"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2")
      end

      it "#headers & :headers" do
        resp = subject.headers("Cookie" => "a=1").get("https://httpbin.org/", headers: {"Cookie" => "b=2"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2")
      end
    end

    describe "Set-Cookie" do
      it "set" do
        subject.get("https://httpbin.org/cookies/set/a/1")
        jar = subject.instance_variable_get("@jar")
        expect(jar.cookies.count).to eq(1)
        expect(jar.cookies[0].cookie_value).to eq("a=1")

        resp = subject.get("https://httpbin.org/")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it "multiple" do
        subject.get("https://httpbin.org/cookies/set/a/1")
        jar = subject.instance_variable_get("@jar")
        expect(jar.cookies.count).to eq(1)
        expect(jar.cookies[0].cookie_value).to eq("a=1")

        subject.get("https://httpbin.org/cookies/set/b/2")
        jar = subject.instance_variable_get("@jar")
        expect(jar.cookies.count).to eq(2)
        expect(jar.cookies[0].cookie_value).to eq("a=1")
        expect(jar.cookies[1].cookie_value).to eq("b=2")

        resp = subject.get("https://httpbin.org/")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1; b=2")
      end

      it "override" do
        subject.get("https://httpbin.org/cookies/set/a/1")
        jar = subject.instance_variable_get("@jar")
        expect(jar.cookies.count).to eq(1)
        expect(jar.cookies[0].cookie_value).to eq("a=1")

        subject.get("https://httpbin.org/cookies/set/a/2")
        jar = subject.instance_variable_get("@jar")
        expect(jar.cookies.count).to eq(1)
        expect(jar.cookies[0].cookie_value).to eq("a=2")

        resp = subject.get("https://httpbin.org/")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=2")
      end

      it "delete" do
        subject.get("https://httpbin.org/cookies/set?a=1")
        jar = subject.instance_variable_get("@jar")
        expect(jar.cookies.count).to eq(1)
        expect(jar.cookies[0].cookie_value).to eq("a=1")

        subject.get("https://httpbin.org/cookies/delete?a=")
        jar = subject.instance_variable_get("@jar")
        expect(jar.cookies.count).to eq(0)

        resp = subject.get("https://httpbin.org/")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq(nil)
      end
    end

    describe "Cookie & Set-Cookie" do
      it do
      end
    end
  end
end
