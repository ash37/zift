class WelcomeController < ApplicationController
  # This controller is now public, so no authentication is required.
  def index
    # This will render the public welcome page in app/views/welcome/index.html.erb
  end
end
