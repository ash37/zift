require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter "/config/"
  add_filter "/bin/"
  add_filter "/vendor/"
  add_filter "/db/"
  min = Integer(ENV.fetch("COVERAGE_MIN", ENV["CI"] ? "70" : "0"))
  minimum_coverage min
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
