unless ENV["NOVCR"]
  require "vcr"
  require "webmock/rspec"

  VCR.configure do |config|
    config.cassette_library_dir = RSPEC_ROOT.join("fixtures/vcr_cassettes")
    config.hook_into :webmock
    config.configure_rspec_metadata!
    config.preserve_exact_body_bytes do |http_message|
      http_message.body.encoding.name == Encoding::ASCII_8BIT ||
        !http_message.body.valid_encoding?
    end
  end
end
