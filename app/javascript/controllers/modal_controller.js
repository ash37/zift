// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

// This controller manages the behavior of the modal dialog.
export default class extends Controller {
  connect() {
    // Listen for the 'keydown' event on the whole document.
    // We bind the function to `this` so it has the correct context.
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("keydown", this.boundCloseOnEscape)
  }

  disconnect() {
    // Clean up the event listener when the controller is removed from the DOM.
    document.removeEventListener("keydown", this.boundCloseOnEscape)
  }

  // This action closes the modal.
  close() {
    // Find the turbo-frame that holds the modal and empty its contents.
    const modalFrame = document.getElementById("assign_shift_modal")
    if (modalFrame) {
      modalFrame.innerHTML = ""
    }
  }

  // This action prevents clicks inside the modal from bubbling up
  // to the background and closing it.
  stopClose(event) {
    event.stopPropagation()
  }

  // This function checks if the pressed key was 'Escape' and closes the modal.
  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}
