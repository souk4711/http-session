RSpec.describe HTTP::Session::Requestable, vcr: true do
  let(:subject) { HTTP::Session.new.freeze }

  it "#head" do
    r = subject.head(httpbin("/get"))
    expect(r.code).to eq(200)
  end

  it "#get" do
    r = subject.get(httpbin("/get"))
    expect(r.code).to eq(200)
  end

  it "#post" do
    r = subject.post(httpbin("/post"))
    expect(r.code).to eq(200)
  end

  it "#put" do
    r = subject.put(httpbin("/put"))
    expect(r.code).to eq(200)
  end

  it "#delete" do
    r = subject.delete(httpbin("/delete"))
    expect(r.code).to eq(200)
  end

  it "#options" do
    r = subject.options(httpbin("/get"))
    expect(r.code).to eq(200)
  end

  it "#patch" do
    r = subject.patch(httpbin("/patch"))
    expect(r.code).to eq(200)
  end
end
