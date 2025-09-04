

import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="ts-note"
export default class extends Controller {
  static targets = ["display", "form", "textarea", "error"];
  static values = { id: Number, updateUrl: String };

  connect() {
    // Ensure initial state is display mode
    this.showDisplay();
  }

  // Enter edit mode
  start() {
    this.showForm();
    // Put cursor at end
    const el = this.textareaTarget;
    el.focus();
    el.selectionStart = el.value.length;
    el.selectionEnd = el.value.length;
  }

  // Cancel edit
  cancel() {
    this.clearError();
    this.showDisplay();
  }

  // Save via PATCH to updateUrlValue with timesheet[notes]
  async save() {
    this.clearError();
    const note = this.textareaTarget.value;

    // CSRF token for Rails
    const token = document.querySelector('meta[name="csrf-token"]')?.content;

    // Build standard Rails form-encoded body so strong params parse naturally
    const body = new URLSearchParams();
    body.append("timesheet[notes]", note);

    // Optional UI disable while saving
    this.disableForm(true);

    try {
      const response = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": token || "",
          "Accept": "text/vnd.turbo-stream.html, text/html, application/json",
          "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        },
        credentials: "same-origin",
        body: body.toString(),
      });

      if (!response.ok) {
        const text = await response.text();
        this.showError(this.extractError(text) || `Save failed (${response.status})`);
        return;
      }

      // Update display text optimistically
      const p = this.displayTarget.querySelector("p");
      if (p) {
        p.textContent = note && note.trim().length > 0 ? note : "No note yet";
        p.classList.toggle("italic", !(note && note.trim().length > 0));
        p.classList.toggle("text-gray-400", !(note && note.trim().length > 0));
      }

      this.showDisplay();
    } catch (e) {
      this.showError("Network error. Please try again.");
    } finally {
      this.disableForm(false);
    }
  }

  // Helpers
  showDisplay() {
    this.displayTarget.classList.remove("hidden");
    this.formTarget.classList.add("hidden");
  }

  showForm() {
    this.formTarget.classList.remove("hidden");
    this.displayTarget.classList.add("hidden");
  }

  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = "";
      this.errorTarget.classList.add("hidden");
    }
  }

  showError(msg) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = msg;
      this.errorTarget.classList.remove("hidden");
    }
  }

  disableForm(disabled) {
    // Disable buttons inside the form section while saving
    this.formTarget.querySelectorAll("button").forEach((btn) => {
      btn.disabled = disabled;
      btn.classList.toggle("opacity-50", disabled);
      btn.classList.toggle("cursor-not-allowed", disabled);
    });
    this.textareaTarget.readOnly = disabled;
  }

  extractError(text) {
    // Try to pull a meaningful message if JSON came back
    try {
      const json = JSON.parse(text);
      if (json?.error) return json.error;
      if (json?.errors) return Array.isArray(json.errors) ? json.errors.join(", ") : String(json.errors);
    } catch (_) { /* ignore parse errors */ }
    return null;
  }
}