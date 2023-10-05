require "http-session"
require "http-session/webmock"

require "active_support/cache"
require "active_support/notifications"
require "active_support/isolated_execution_state"
require "brotli" unless RUBY_ENGINE == "jruby"

RSPEC_ROOT = Pathname.new(__dir__)

# Requires supporting ruby files with custom matchers and macros, etc.
Dir[RSPEC_ROOT.join("support", "**", "*.rb")].sort.each { |f| require f }

# Congigure RSpec
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
