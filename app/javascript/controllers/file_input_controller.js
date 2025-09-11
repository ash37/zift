// app/javascript/controllers/file_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "submit"]

  connect() {
    // Initialize state on load
    this.update()
  }

  update() {
    if (!this.hasInputTarget || !this.hasLabelTarget) return
    const files = this.inputTarget.files
    if (!files || files.length === 0) {
      this.labelTarget.textContent = "No file selected"
      this.labelTarget.classList.remove("text-gray-700")
      this.labelTarget.classList.add("text-gray-400")
      if (this.hasSubmitTarget) this.submitTarget.classList.add("hidden")
    } else if (files.length === 1) {
      this.labelTarget.textContent = files[0].name
      this.labelTarget.classList.remove("text-gray-400")
      this.labelTarget.classList.add("text-gray-700")
      if (this.hasSubmitTarget) this.submitTarget.classList.remove("hidden")
    } else {
      this.labelTarget.textContent = `${files.length} files selected`
      this.labelTarget.classList.remove("text-gray-400")
      this.labelTarget.classList.add("text-gray-700")
      if (this.hasSubmitTarget) this.submitTarget.classList.remove("hidden")
    }
  }
}
