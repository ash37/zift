RSpec.configure do |config|
  config.before(:each) do
    ActiveJob::Base.queue_adapter = :test
  end
end
