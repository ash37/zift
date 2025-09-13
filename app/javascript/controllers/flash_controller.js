// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 3000 }
  }

  connect() {
    // Auto dismiss after timeout with a fade-out
    this.dismissTimer = setTimeout(() => {
      this.element.classList.add("opacity-0")
      // Remove after transition completes
      this._removeTimer = setTimeout(() => {
        this.element.remove()
      }, 500)
    }, this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.dismissTimer)
    clearTimeout(this._removeTimer)
  }
}

