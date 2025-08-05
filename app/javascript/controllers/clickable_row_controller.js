// app/javascript/controllers/clickable_row_controller.js
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clickable-row"
export default class extends Controller {
  static values = { url: String }

  connect() {
    if (this.hasUrlValue) {
      this.element.classList.add("cursor-pointer")
    }
  }

  visit(event) {
    // Prevent clicks on buttons or links inside the row from triggering the row click
    if (event.target.closest('a, button')) {
      return
    }

    if (this.hasUrlValue && this.urlValue) {
      Turbo.visit(this.urlValue)
    }
  }
}
