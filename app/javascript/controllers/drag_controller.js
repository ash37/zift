import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="drag"
export default class extends Controller {
  static values = {
    url: String,
    userId: String,
    date: String
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      group: 'shared',
      animation: 150,
      draggable: "turbo-frame[data-id]",
      
      // These custom classes will be added by SortableJS during a drag.
      ghostClass: "sortable-ghost-custom", // For the placeholder
      dragClass: "sortable-drag-custom",   // For the item being dragged
      
      onEnd: this.onDragEnd.bind(this)
    });
  }

  onDragEnd(event) {
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
    .then(response => response.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
    });
  }
}
