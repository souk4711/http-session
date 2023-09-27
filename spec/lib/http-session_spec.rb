RSpec.describe HTTP do
  describe ".session" do
    it "returns a Session instance" do
      session = described_class.session
      expect(session).to be_a(HTTP::Session)
    end
  end
end
