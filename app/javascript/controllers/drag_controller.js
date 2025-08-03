// This Stimulus controller handles the drag-and-drop logic.
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  connect() {
    // Initializes SortableJS on the element this controller is connected to (each <td>).
    this.sortable = Sortable.create(this.element, {
      group: 'shared', // Allows dragging between elements in the same group.
      animation: 150,  // Animation speed.
      onEnd: this.end.bind(this) // Callback function when a drag operation ends.
    });
  }

  // Called when a shift is dropped into a new cell.
  end(event) {
    // Get the shift ID from the dragged item's data attribute.
    let id = event.item.dataset.id
    // The URL to send the update request to.
    let url = `/shifts/${id}`
    let data = new FormData()

    // Append the new user_id and date from the target cell's data attributes.
    data.append("shift[user_id]", event.to.dataset.userId)
    data.append("shift[date]", event.to.dataset.date)

    // Get the CSRF token to include in the request headers for security.
    const csrfToken = document.querySelector("[name='csrf-token']").content

    // Use the Fetch API to send a PATCH request to update the shift.
    fetch(url, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'text/vnd.turbo-stream.html' // Important for Turbo to process the response
      },
      body: data
    })
    .then(response => response.text())
    .then(html => {
      // Let Turbo process the returned stream message to update the DOM.
      Turbo.renderStreamMessage(html)
    })
    .catch(error => console.error("Drag and drop failed:", error))
  }
}