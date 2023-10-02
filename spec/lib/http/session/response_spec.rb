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
end
