RSpec.configure do |config|
  mod = Module.new do
    def httpbin(path)
      "https://httpbin.org" + path
    end

    def jsdelivr(path)
      "https://cdn.jsdelivr.net" + path
    end
  end

  config.include mod
end
