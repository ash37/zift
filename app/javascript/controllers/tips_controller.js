import { Controller } from "@hotwired/stimulus"

// Provides a toggleable tips panel for clock-off notes guidance
export default class extends Controller {
  static targets = ["panel"]

  toggle(event) {
    event.preventDefault()
    if (!this.hasPanelTarget) return

    this.panelTarget.classList.toggle("hidden")
  }
}
