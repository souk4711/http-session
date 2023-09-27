RSpec.describe HTTP::Session::Configurable do
  let(:subject) { HTTP::Session.new }

  it "#timeout" do
    opts = subject.timeout(2).instance_variable_get("@options")
    expect(opts.http.timeout_class).to eq(HTTP::Timeout::Global)
    expect(opts.http.timeout_options).to eq(global_timeout: 2)
  end

  it "#via" do
    opts = subject.via("http://127.0.0.1", 7890).instance_variable_get("@options")
    expect(opts.http.proxy).to eq(proxy_address: "http://127.0.0.1", proxy_port: 7890)
  end

  it "#follow" do
    opts = subject.follow.instance_variable_get("@options")
    expect(opts.http.follow).to eq({})
  end

  it "#headers" do
    opts = subject.headers("User-Agent" => "http-session 0.0.1").instance_variable_get("@options")
    expect(opts.http.headers).to eq("User-Agent" => "http-session 0.0.1")
  end

  it "#cookies" do
    opts = subject.cookies("session_cookie" => "dXNlcl9pZD0xO21hYz1iY2NlYT...").instance_variable_get("@options")
    expect(opts.http.cookies).to eq("session_cookie" => "session_cookie=dXNlcl9pZD0xO21hYz1iY2NlYT...")
  end

  it "#encoding" do
    opts = subject.encoding("utf-8").instance_variable_get("@options")
    expect(opts.http.encoding).to eq(Encoding::UTF_8)
  end

  it "#accept" do
    opts = subject.accept("application/json").instance_variable_get("@options")
    expect(opts.http.headers).to eq("Accept" => "application/json")
  end

  it "#auth" do
    opts = subject.auth("Bearer VGhlIEhUVFAgR2VtLCBST0NLUw").instance_variable_get("@options")
    expect(opts.http.headers).to eq("Authorization" => "Bearer VGhlIEhUVFAgR2VtLCBST0NLUw")
  end

  it "#basic_auth" do
    opts = subject.basic_auth(user: "user", pass: "pass").instance_variable_get("@options")
    expect(opts.http.headers).to eq("Authorization" => "Basic dXNlcjpwYXNz")
  end

  it "#nodelay" do
    opts = subject.nodelay.instance_variable_get("@options")
    expect(opts.http.nodelay).to eq(true)
  end

  it "#use" do
    opts = subject.use(:auto_deflate).instance_variable_get("@options")
    expect(opts.http.features[:auto_deflate]).to be_a(HTTP::Features::AutoDeflate)
  end

  it "chainable" do
    opts = subject
      .timeout(2)
      .via("http://127.0.0.1", 7890)
      .follow
      .encoding("gbk")
      .instance_variable_get("@options")
    expect(opts.http.timeout_class).to eq(HTTP::Timeout::Global)
    expect(opts.http.timeout_options).to eq(global_timeout: 2)
    expect(opts.http.proxy).to eq(proxy_address: "http://127.0.0.1", proxy_port: 7890)
    expect(opts.http.follow).to eq({})
    expect(opts.http.encoding).to eq(Encoding::GBK)
  end
end
