// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import Rails from "@rails/ujs"
import * as ActiveStorage from "@rails/activestorage"
import Alpine from "alpinejs"
window.Alpine = Alpine
Alpine.start()

Rails.start()
ActiveStorage.start()
