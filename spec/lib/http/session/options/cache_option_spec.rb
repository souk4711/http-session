RSpec.describe HTTP::Session::Options::CacheOption do
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

  it "#private_cache? & #shared_cache?" do
    [
      {private: true},
      {shared: false}
    ].each do |opts|
      sub = described_class.new(opts)
      expect(sub.private_cache?).to eq(true)
      expect(sub.shared_cache?).to eq(false)
    end

    [
      {},
      {shared: true},
      {private: false}
    ].each do |opts|
      sub = described_class.new(opts)
      expect(sub.private_cache?).to eq(false)
      expect(sub.shared_cache?).to eq(true)
    end

    [
      {private: true, shared: true},
      {private: true, shared: false},
      {private: false, shared: true},
      {private: false, shared: false}
    ].each do |opts|
      expect {
        described_class.new(opts)
      }.to raise_error(ArgumentError, /cannot be used at the same time/)
    end
  end
end
