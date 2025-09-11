RSpec.configure do |config|
  config.include Warden::Test::Helpers, type: :system

  config.after(type: :system) do
    Warden.test_reset!
  end
end
