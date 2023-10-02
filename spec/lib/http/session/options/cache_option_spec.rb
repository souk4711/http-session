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

  it "#shared_cache? & #private_cache?" do
    [
      {},
      {shared: true},
      {private: false}
    ].each do |opts|
      sub = described_class.new(opts)
      expect(sub.shared_cache?).to eq(true)
      expect(sub.private_cache?).to eq(false)
    end

    [
      {shared: false},
      {private: true}
    ].each do |opts|
      sub = described_class.new(opts)
      expect(sub.shared_cache?).to eq(false)
      expect(sub.private_cache?).to eq(true)
    end

    [
      {shared: true, private: true},
      {shared: true, private: false},
      {shared: false, private: true},
      {shared: false, private: false}
    ].each do |opts|
      expect {
        described_class.new(opts)
      }.to raise_error(ArgumentError, /cannot be used at the same time/)
    end
  end

  it "#cache" do
    sub = described_class.new(enabled: false)
    expect(sub.store).to eq(nil)

    sub = described_class.new(enabled: true)
    expect(sub.store).to be_a(ActiveSupport::Cache::Store)

    store = Object.new
    sub = described_class.new(store: store)
    expect(sub.store).to eq(store)
  end
end
