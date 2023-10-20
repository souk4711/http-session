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

  it "#jar", skip: (RUBY_ENGINE == "jruby" && "gem 'sqlite3' not works in JRuby") do
    sub = described_class.new(nil)
    expect(sub.jar).to eq(nil)

    sub = described_class.new(enabled: false)
    expect(sub.jar).to eq(nil)

    sub = described_class.new(enabled: true)
    expect(sub.jar).to be_a(HTTP::CookieJar)

    sub = described_class.new(jar: nil)
    expect(sub.jar).to be_a(HTTP::CookieJar)

    Dir.mkdir("./tmp") unless Dir.exist?("./tmp")
    sub = described_class.new(jar: {store: :mozilla, filename: "./tmp/cookies.sqlite"})
    expect(sub.jar).to be_a(HTTP::CookieJar)

    sub = described_class.new(jar: HTTP::CookieJar.new)
    expect(sub.jar).to be_a(HTTP::CookieJar)
  end
end
