RSpec.configure do |config|
  config.include(
    Module.new do
      def httpbin(path)
        "https://httpbin.org" + path
      end
    end
  )
end
