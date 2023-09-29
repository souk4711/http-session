RSpec.describe HTTP::Session, vcr: true do
  let(:subject) { described_class.new.freeze }

  describe "#request" do
    describe "opts" do
      it "override session options" do
        res = subject.dup.follow(false).get("https://httpbin.org/redirect/1", follow: true)
        expect(res.code).to eq(200)

        res = subject.dup.follow(true).get("https://httpbin.org/redirect/1", follow: false)
        expect(res.code).to eq(302)
      end

      it "merge session options" do
        res = subject.dup.headers("A" => "A", "B" => "B").get("https://httpbin.org/anything", headers: {"B" => "b", "C" => "C"})
        expect(res.code).to eq(200)
        expect(res.request.headers["A"]).to eq("A")
        expect(res.request.headers["B"]).to eq("b")
        expect(res.request.headers["C"]).to eq("C")
      end
    end

    describe "return" do
      it "a HTTP::Session::Response" do
        res = subject.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res).to be_an_instance_of(HTTP::Session::Response)
        expect(res.request).to be_an_instance_of(HTTP::Session::Request)

        res = subject.get("https://httpbin.org/redirect/1", follow: true)
        expect(res.code).to eq(200)
        expect(res).to be_an_instance_of(HTTP::Session::Response)
        expect(res.request).to be_an_instance_of(HTTP::Session::Request)

        res = subject.get(
          "https://httpbin.org/redirect/1",
          follow: true,
          features: {logging: {logger: HTTP::Features::Logging::NullLogger.new}}
        )
        expect(res.code).to eq(200)
        expect(res).to be_instance_of(HTTP::Session::Response)
        expect(res.request).to be_an_instance_of(HTTP::Session::Request)
      end
    end
  end

  describe "cookies" do
    describe "Cookie" do
      it ":cookies" do
        res = subject.get("https://httpbin.org/anything", cookies: {_: "a=1"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it ":headers" do
        res = subject.get("https://httpbin.org/anything", headers: {"Cookie" => "a=1"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#cookies" do
        res = subject.dup.cookies(a: 1).get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#headers" do
        res = subject.dup.headers("Cookie" => "a=1").get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#cookies & :cookies" do
        res = subject.dup.cookies(a: 1).get("https://httpbin.org/anything", cookies: {_: "b=2"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2")
      end

      it "Session#headers & :headers" do
        res = subject.dup.headers("Cookie" => "a=1").get("https://httpbin.org/anything", headers: {"Cookie" => "b=2"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2")
      end
    end

    describe "Set-Cookie" do
      it "set" do
        res = subject.get("https://httpbin.org/cookies/set/a/1")
        expect(res.code).to eq(302)

        res = subject.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end

      it "multiple" do
        res = subject.get("https://httpbin.org/cookies/set/a/1")
        expect(res.code).to eq(302)

        res = subject.get("https://httpbin.org/cookies/set/b/2")
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("a=1")

        res = subject.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1; b=2")
      end

      it "override" do
        res = subject.get("https://httpbin.org/cookies/set/a/1")
        expect(res.code).to eq(302)

        res = subject.get("https://httpbin.org/cookies/set/a/2")
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("a=1")

        res = subject.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=2")
      end

      it "delete" do
        res = subject.get("https://httpbin.org/cookies/set?a=1")
        expect(res.code).to eq(302)

        res = subject.get("https://httpbin.org/cookies/delete?a=")
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("a=1")

        res = subject.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq(nil)
      end
    end

    describe "Cookie & Set-Cookie" do
      it ":cookies & set" do
        res = subject.get("https://httpbin.org/cookies/set?a=1", cookies: {_: "b=2"})
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = subject.get("https://httpbin.org/anything", cookies: {_: "b=2"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it ":headers & set" do
        res = subject.get("https://httpbin.org/cookies/set?a=1", headers: {"Cookie" => "b=2"})
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = subject.get("https://httpbin.org/anything", headers: {"Cookie" => "b=2"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#cookies & set" do
        sub = subject.dup.cookies(b: 2)

        res = sub.get("https://httpbin.org/cookies/set?a=1")
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = sub.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#headers & set" do
        sub = subject.dup.headers("Cookie" => "b=2")

        res = sub.get("https://httpbin.org/cookies/set?a=1")
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("b=2")

        res = sub.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#cookies & :cookies & set" do
        sub = subject.dup.cookies(b: 2)

        res = sub.get("https://httpbin.org/cookies/set?a=1", cookies: {_: "c=3"})
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("c=3")

        res = sub.get("https://httpbin.org/anything", cookies: {_: "d=4"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("d=4; a=1")

        res = sub.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#headers & :headers & set" do
        sub = subject.dup.headers("Cookie" => "b=2")

        res = sub.get("https://httpbin.org/cookies/set?a=1", headers: {"Cookie" => "c=3"})
        expect(res.code).to eq(302)
        expect(res.request.headers["Cookie"]).to eq("c=3")

        res = sub.get("https://httpbin.org/anything", headers: {"Cookie" => "d=4"})
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("d=4; a=1")

        res = sub.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("b=2; a=1")
      end
    end

    describe "Redirect" do
      it "keep Set-Cookie" do
        res = subject.get("https://httpbin.org/cookies/set/a/1", follow: true)
        expect(res.code).to eq(200)

        res = subject.get("https://httpbin.org/anything")
        expect(res.code).to eq(200)
        expect(res.request.headers["Cookie"]).to eq("a=1")
      end
    end
  end

  describe "redirect" do
    it "redirect n times" do
      cnt = 0
      res = subject.get("https://httpbin.org/redirect/4", follow: {
        on_redirect: ->(_, _) { cnt += 1 }
      })
      expect(res.code).to eq(200)
      expect(cnt).to eq(4)
    end
  end
end
