// app/javascript/controllers/color_picker_controller.js
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="color-picker"
export default class extends Controller {
  static targets = [ "input" ]

  connect() {
    this.selectedSwatch = null;
    // Pre-select the first color by default
    const firstSwatch = this.element.querySelector('[data-color]');
    if (firstSwatch) {
      this.select({ currentTarget: firstSwatch });
    }
  }

  select(event) {
    const swatch = event.currentTarget;
    const color = swatch.dataset.color;

    // Update the hidden input's value
    this.inputTarget.value = color;

    // Remove the border from the previously selected swatch
    if (this.selectedSwatch) {
      this.selectedSwatch.classList.remove('ring-2', 'ring-offset-2', 'ring-zinc-500');
    }

    // Add a border to the newly selected swatch for visual feedback
    swatch.classList.add('ring-2', 'ring-offset-2', 'ring-zinc-500');

    // Keep track of the currently selected swatch
    this.selectedSwatch = swatch;
  }
}
