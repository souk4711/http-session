RSpec.describe HTTP::Session::Options::CookiesOption do
  it "#enabled?" do
    [nil, false, {enabled: false}].each do |opts|
      sub = described_class.new(opts)
      expect(sub.enabled?).to eq(false)
    end

    [true, {}, {enabled: true}].each do |opts|
      sub = described_class.new(opts)
      expect(sub.enabled?).to eq(true)
    end
  end
end
