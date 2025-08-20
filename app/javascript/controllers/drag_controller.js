import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="drag"
export default class extends Controller {
  static values = {
    url: String,
    userId: String,
    date: String,
    enabled: Boolean
  }

  connect() {
    if (!this.enabledValue) return;
    this.sortable = Sortable.create(this.element, {
      group: 'shared',
      animation: 150,
      draggable: "turbo-frame[data-id]",
      
      // These custom classes will be added by SortableJS during a drag.
      ghostClass: "sortable-ghost-custom", // For the placeholder
      dragClass: "sortable-drag-custom",   // For the item being dragged
      
      // These functions are called when a drag starts and ends.
      onStart: this.onDragStart.bind(this),
      onEnd: this.onDragEnd.bind(this),
      onMove: this.onMove.bind(this)
    });
  }

  onDragStart(event) {
    // When a drag starts, add a class to all drop zones to highlight them.
    document.querySelectorAll('.shifts-container').forEach(container => {
      container.classList.add('drop-target-active');
    });
  }

  onMove(evt) {
    // Remove hover state from any previously hovered containers
    document.querySelectorAll('.shifts-container.drop-hover').forEach(el => {
      el.classList.remove('drop-hover');
    });

    // Add hover state to the current `to` container, if it is a valid drop target
    if (evt.to && evt.to.classList && evt.to.classList.contains('shifts-container')) {
      evt.to.classList.add('drop-hover');
    }

    return true; // allow move
  }

  onDragEnd(event) {
    // When a drag ends, remove the highlight from all drop zones.
    document.querySelectorAll('.shifts-container').forEach(container => {
      container.classList.remove('drop-target-active', 'drop-hover');
    });

    // --- The rest of the onEnd logic to update the server ---
    const shiftId = event.item.dataset.id;
    const url = this.urlValue.replace(":id", shiftId);
    const dropTargetController = this.application.getControllerForElementAndIdentifier(event.to, "drag");

    if (!dropTargetController) {
      console.error("Could not find Stimulus 'drag' controller on the drop target.");
      return;
    }

    const userId = dropTargetController.userIdValue;
    const date = dropTargetController.dateValue;
    
    const urlParams = new URLSearchParams(window.location.search);
    const locationId = urlParams.get('location_id');

    const body = {
      shift: {
        user_id: userId,
        date: date,
        roster_filter_location_id: locationId
      },
    };

    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

    fetch(url, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        'Accept': 'text/vnd.turbo-stream.html'
      },
      body: JSON.stringify(body)
    })
    .then(response => {
      if (!response.ok && response.status === 422) {
        // If the server responds with a validation error,
        // we need to revert the drag on the frontend.
        // We use SortableJS's native `closest` and `sort` methods to do this.
        const originalSortable = Sortable.get(event.from);
        originalSortable.sort(originalSortable.toArray(), true);
      }
      return response.text()
    })
    .then(html => {
      Turbo.renderStreamMessage(html)
    });
  }
}
