require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = RSPEC_ROOT.join("fixtures/vcr_cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!
end
