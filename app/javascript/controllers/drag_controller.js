import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="drag"
export default class extends Controller {
  static values = {
    url: String,
    userId: String,
    date: String,
    enabled: Boolean,
    rosterId: Number
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
    // Add a subtle background to the item being dragged for visibility
    if (event.item) {
      event.item.classList.add('bg-violet-100');
    }
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
    // Remove the temporary drag background class
    if (event.item) {
      event.item.classList.remove('bg-violet-100');
    }

    // --- The rest of the onEnd logic to update the server ---
    const shiftId = event.item.dataset.id;
    const groupIds = (event.item.dataset.groupIds || "").split(',').map(s => s.trim()).filter(Boolean);
    const url = this.urlValue.replace(":id", shiftId);
    const dropTargetController = this.application.getControllerForElementAndIdentifier(event.to, "drag");
    const sourceController = this.application.getControllerForElementAndIdentifier(event.from, "drag");

    if (!dropTargetController) {
      console.error("Could not find Stimulus 'drag' controller on the drop target.");
      return;
    }

    const userId = dropTargetController.userIdValue;
    const date = dropTargetController.dateValue;
    const newRosterId = dropTargetController.rosterIdValue || this.rosterIdValue;
    const oldUserId = sourceController ? sourceController.userIdValue : null;
    const oldDate = sourceController ? sourceController.dateValue : null;
    const oldRosterId = sourceController ? (sourceController.rosterIdValue || this.rosterIdValue) : this.rosterIdValue;

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
    const csrfHeaders = {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken,
      'Accept': 'text/vnd.turbo-stream.html'
    };

    const refreshCells = () => {
      // Refresh destination cell via day_pills (compact view helper)
      if (newRosterId && userId && date) {
        fetch(`/rosters/${newRosterId}/day_pills?user_id=${userId}&date=${encodeURIComponent(date)}&location_id=${encodeURIComponent(locationId || "")}`, {
          headers: { 'Accept': 'text/vnd.turbo-stream.html' }
        }).then(r => r.text()).then(html => Turbo.renderStreamMessage(html));
      }
      // Refresh source cell if changed
      if (oldRosterId && oldUserId && oldDate && (oldUserId !== userId || oldDate !== date)) {
        fetch(`/rosters/${oldRosterId}/day_pills?user_id=${oldUserId}&date=${encodeURIComponent(oldDate)}&location_id=${encodeURIComponent(locationId || "")}`, {
          headers: { 'Accept': 'text/vnd.turbo-stream.html' }
        }).then(r => r.text()).then(html => Turbo.renderStreamMessage(html));
      }
    };

    // If this is an aggregate pill with multiple shift ids, move them all
    if (groupIds.length > 1) {
      const requests = groupIds.map(id => {
        const u = this.urlValue.replace(":id", id);
        return fetch(u, { method: 'PATCH', headers: csrfHeaders, body: JSON.stringify(body) });
      });

      Promise.all(requests).then(responses => {
        const anyError = responses.some(r => !r.ok && r.status === 422);
        if (anyError) {
          const originalSortable = Sortable.get(event.from);
          originalSortable.sort(originalSortable.toArray(), true);
          return Promise.all(responses.map(r => r.text())).then(htmls => htmls.forEach(html => Turbo.renderStreamMessage(html)));
        } else {
          // After all succeed, refresh both source and destination compact cells once
          refreshCells();
        }
      });
      return;
    }

    // Single shift move (default behavior)
    fetch(url, { method: 'PATCH', headers: csrfHeaders, body: JSON.stringify(body) })
      .then(response => {
        if (!response.ok && response.status === 422) {
          const originalSortable = Sortable.get(event.from);
          originalSortable.sort(originalSortable.toArray(), true);
        }
        return response.text();
      })
      .then(html => { Turbo.renderStreamMessage(html); });
  }
}
