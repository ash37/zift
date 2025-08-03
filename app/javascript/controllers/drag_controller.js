import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"
// We no longer need to import from '@rails/request.js'
// import { patch } from '@rails/request.js'

// Connects to data-controller="drag"
export default class extends Controller {
  // Define the values the controller will accept from the HTML data attributes.
  static values = {
    url: String,
    userId: String,
    date: String
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      group: 'shared', // Allows dragging between elements with the same group name
      animation: 150,
      
      // This is the key change: We explicitly tell SortableJS that only
      // turbo-frames with a 'data-id' attribute (our shifts) can be dragged.
      // It will now ignore clicks on all other elements, like the "Add Shift" link.
      draggable: "turbo-frame[data-id]", 
      
      onEnd: this.onDragEnd.bind(this) // Bind the onEnd event to our method
    });
  }

  onDragEnd(event) {
    // event.item: the dragged element (the shift)
    // event.to: the container the element was dropped into (the cell's div)

    const shiftId = event.item.dataset.id;
    const url = this.urlValue.replace(":id", shiftId);
    const dropTargetController = this.application.getControllerForElementAndIdentifier(event.to, "drag");

    if (!dropTargetController) {
      console.error("Could not find Stimulus 'drag' controller on the drop target.");
      return;
    }

    const userId = dropTargetController.userIdValue;
    const date = dropTargetController.dateValue;

    const body = {
      shift: {
        user_id: userId,
        date: date,
      },
    };

    // Find the CSRF token from the page's meta tags. Rails includes this for security.
    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

    // Use the browser's built-in fetch API to send the request.
    fetch(url, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        // This header tells Rails to respond with a Turbo Stream
        'Accept': 'text/vnd.turbo-stream.html'
      },
      body: JSON.stringify(body)
    })
    .then(response => response.text())
    .then(html => {
      // Use Turbo to process the stream response from the server
      Turbo.renderStreamMessage(html)
    });
  }
}
