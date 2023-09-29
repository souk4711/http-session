RSpec.describe HTTP::Session, vcr: true do
  let(:subject) { described_class.new }

  describe "#request" do
    describe "opts" do
      it "override session options" do
        resp = subject.follow(false).get("https://httpbin.org/redirect/1", follow: true)
        expect(resp.code).to eq(200)

        resp = subject.follow(true).get("https://httpbin.org/redirect/1", follow: false)
        expect(resp.code).to eq(302)
      end

      it "merge session options" do
        resp = subject.headers("A" => "A", "B" => "B").get("https://httpbin.org/anything", headers: {"B" => "b", "C" => "C"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["A"]).to eq("A")
        expect(resp.request.headers["B"]).to eq("b")
        expect(resp.request.headers["C"]).to eq("C")
      end
    end
  end

  describe "cookies" do
    describe "Cookie" do
      it ":cookies" do
        resp = subject.get("https://httpbin.org/anything", cookies: {_: "a=1"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it ":headers" do
        resp = subject.get("https://httpbin.org/anything", headers: {"Cookie" => "a=1"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#cookies" do
        resp = subject.cookies(a: 1).get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#headers" do
        resp = subject.headers("Cookie" => "a=1").get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it "Session#cookies & :cookies" do
        resp = subject.cookies(a: 1).get("https://httpbin.org/anything", cookies: {_: "b=2"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2")
      end

      it "Session#headers & :headers" do
        resp = subject.headers("Cookie" => "a=1").get("https://httpbin.org/anything", headers: {"Cookie" => "b=2"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2")
      end
    end

    describe "Set-Cookie" do
      it "set" do
        resp = subject.get("https://httpbin.org/cookies/set/a/1")
        expect(resp.code).to eq(302)

        resp = subject.get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end

      it "multiple" do
        resp = subject.get("https://httpbin.org/cookies/set/a/1")
        expect(resp.code).to eq(302)

        resp = subject.get("https://httpbin.org/cookies/set/b/2")
        expect(resp.code).to eq(302)
        expect(resp.request.headers["Cookie"]).to eq("a=1")

        resp = subject.get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1; b=2")
      end

      it "override" do
        resp = subject.get("https://httpbin.org/cookies/set/a/1")
        expect(resp.code).to eq(302)

        resp = subject.get("https://httpbin.org/cookies/set/a/2")
        expect(resp.code).to eq(302)
        expect(resp.request.headers["Cookie"]).to eq("a=1")

        resp = subject.get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=2")
      end

      it "delete" do
        resp = subject.get("https://httpbin.org/cookies/set?a=1")
        expect(resp.code).to eq(302)

        resp = subject.get("https://httpbin.org/cookies/delete?a=")
        expect(resp.code).to eq(302)
        expect(resp.request.headers["Cookie"]).to eq("a=1")

        resp = subject.get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq(nil)
      end
    end

    describe "Cookie & Set-Cookie" do
      it ":cookies & set" do
        resp = subject.get("https://httpbin.org/cookies/set?a=1", cookies: {_: "b=2"})
        expect(resp.code).to eq(302)
        expect(resp.request.headers["Cookie"]).to eq("b=2")

        resp = subject.get("https://httpbin.org/anything", cookies: {_: "b=2"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it ":headers & set" do
        resp = subject.get("https://httpbin.org/cookies/set?a=1", headers: {"Cookie" => "b=2"})
        expect(resp.code).to eq(302)
        expect(resp.request.headers["Cookie"]).to eq("b=2")

        resp = subject.get("https://httpbin.org/anything", headers: {"Cookie" => "b=2"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#cookies & set" do
        sub = subject.cookies(b: 2)

        resp = sub.get("https://httpbin.org/cookies/set?a=1")
        expect(resp.code).to eq(302)
        expect(resp.request.headers["Cookie"]).to eq("b=2")

        resp = sub.get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#headers & set" do
        sub = subject.headers("Cookie" => "b=2")

        resp = sub.get("https://httpbin.org/cookies/set?a=1")
        expect(resp.code).to eq(302)
        expect(resp.request.headers["Cookie"]).to eq("b=2")

        resp = sub.get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#cookies & :cookies & set" do
        sub = subject.cookies(b: 2)

        resp = sub.get("https://httpbin.org/cookies/set?a=1", cookies: {_: "c=3"})
        expect(resp.code).to eq(302)
        expect(resp.request.headers["Cookie"]).to eq("c=3")

        resp = sub.get("https://httpbin.org/anything", cookies: {_: "d=4"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("d=4; a=1")

        resp = sub.get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2; a=1")
      end

      it "Session#headers & :headers & set" do
        sub = subject.headers("Cookie" => "b=2")

        resp = sub.get("https://httpbin.org/cookies/set?a=1", headers: {"Cookie" => "c=3"})
        expect(resp.code).to eq(302)
        expect(resp.request.headers["Cookie"]).to eq("c=3")

        resp = sub.get("https://httpbin.org/anything", headers: {"Cookie" => "d=4"})
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("d=4; a=1")

        resp = sub.get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("b=2; a=1")
      end
    end

    describe "Redirect" do
      it "keep Set-Cookie" do
        resp = subject.get("https://httpbin.org/cookies/set/a/1", follow: true)
        expect(resp.code).to eq(200)

        resp = subject.get("https://httpbin.org/anything")
        expect(resp.code).to eq(200)
        expect(resp.request.headers["Cookie"]).to eq("a=1")
      end
    end
  end

  describe "redirect" do
    it "redirect n times" do
      count = 0
      resp = subject.get("https://httpbin.org/redirect/4", follow: {
        on_redirect: ->(_, _) { count += 1 }
      })
      expect(resp.code).to eq(200)
      expect(count).to eq(4)
    end
  end
end
