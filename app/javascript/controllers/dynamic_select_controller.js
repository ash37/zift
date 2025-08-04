// app/javascript/controllers/dynamic_select_controller.js
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dynamic-select"
export default class extends Controller {
  static targets = ["source", "target"]

  connect() {
    this.updateTarget();
  }

  updateTarget() {
    const selectedSourceId = this.sourceTarget.value;
    const targetSelect = this.targetTarget;

    // Clear existing options
    targetSelect.innerHTML = '<option value="">Select an Area</option>';

    if (selectedSourceId) {
      // The areas data is embedded in the page as a data attribute
      const areasData = JSON.parse(this.element.dataset.areas);
      const filteredAreas = areasData.filter(area => area.location_id == selectedSourceId);

      filteredAreas.forEach(area => {
        const option = document.createElement("option");
        option.value = area.id;
        option.textContent = area.name;
        targetSelect.appendChild(option);
      });
    }
  }
}
