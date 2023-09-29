RSpec.describe HTTP::Session::Requestable, vcr: true do
  let(:subject) { HTTP::Session.new.freeze }

  it "#head" do
    r = subject.head("https://httpbin.org/get")
    expect(r.code).to eq(200)
  end

  it "#get" do
    r = subject.get("https://httpbin.org/get")
    expect(r.code).to eq(200)
  end

  it "#post" do
    r = subject.post("https://httpbin.org/post")
    expect(r.code).to eq(200)
  end

  it "#put" do
    r = subject.put("https://httpbin.org/put")
    expect(r.code).to eq(200)
  end

  it "#delete" do
    r = subject.delete("https://httpbin.org/delete")
    expect(r.code).to eq(200)
  end

  it "#options" do
    r = subject.options("https://httpbin.org/get")
    expect(r.code).to eq(200)
  end

  it "#patch" do
    r = subject.patch("https://httpbin.org/patch")
    expect(r.code).to eq(200)
  end
end
