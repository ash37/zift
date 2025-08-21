import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    setTimeout(() => {
      this.element.classList.add("opacity-0", "transition", "duration-500")
      setTimeout(() => this.element.remove(), 500) // wait for fade before removing
    }, 2000) // visible for 2 seconds
  }
}