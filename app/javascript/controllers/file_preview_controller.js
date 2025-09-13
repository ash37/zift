// app/javascript/controllers/file_preview_controller.js
import { Controller } from "@hotwired/stimulus"

// Handles opening a modal to preview image/PDF and download
export default class extends Controller {
  static targets = ["modal", "content", "title", "downloadLink", "removeButton"]

  open(event) {
    event.preventDefault()
    const el = event.currentTarget
    const fileUrl = el.dataset.filePreviewFileUrl
    const downloadUrl = el.dataset.filePreviewDownloadUrl
    const fileName = el.dataset.filePreviewFileName || "Attachment"
    const fileType = (el.dataset.filePreviewFileType || "").toLowerCase()
    this.currentRemoveUrl = el.dataset.filePreviewRemoveUrl || null

    // Set title and download link
    if (this.hasTitleTarget) this.titleTarget.textContent = fileName
    if (this.hasDownloadLinkTarget) this.downloadLinkTarget.setAttribute("href", downloadUrl)
    if (this.hasRemoveButtonTarget) {
      if (this.currentRemoveUrl) {
        this.removeButtonTarget.classList.remove("hidden")
      } else {
        this.removeButtonTarget.classList.add("hidden")
      }
    }

    // Render content with dynamic height
    let html = ""
    if (fileType.startsWith("image/")) {
      html = `<img src="${fileUrl}" alt="${this._escape(fileName)}" class="max-h-80 max-w-full mx-auto rounded object-contain" />`
      if (this.hasContentTarget) this.contentTarget.style.height = '24rem' // ~ h-96
    } else if (fileType === "application/pdf") {
      html = `<iframe src="${fileUrl}" class="w-full h-full border rounded"></iframe>`
      if (this.hasContentTarget) this.contentTarget.style.height = '80vh'
    } else {
      html = `
        <div class="text-center">
          <p class="text-sm text-gray-600 mb-3">Preview not available for this file type.</p>
          <a href="${downloadUrl}" class="px-3 py-1 rounded-md bg-violet-600 text-white hover:bg-violet-700">Download</a>
        </div>`
      if (this.hasContentTarget) this.contentTarget.style.height = '24rem'
    }
    if (this.hasContentTarget) this.contentTarget.innerHTML = html

    // Show modal
    if (this.hasModalTarget) this.modalTarget.classList.remove("hidden")
  }

  close() {
    if (this.hasModalTarget) this.modalTarget.classList.add("hidden")
    if (this.hasContentTarget) this.contentTarget.innerHTML = ""
  }

  remove(event) {
    event.preventDefault()
    if (!this.currentRemoveUrl) return
    if (!confirm("Remove this file?")) return

    // Build and submit a form with DELETE method and CSRF token
    const form = document.createElement("form")
    form.method = "post"
    form.action = this.currentRemoveUrl

    const method = document.createElement("input")
    method.type = "hidden"
    method.name = "_method"
    method.value = "delete"
    form.appendChild(method)

    const token = document.querySelector('meta[name="csrf-token"]').content
    if (token) {
      const auth = document.createElement("input")
      auth.type = "hidden"
      auth.name = "authenticity_token"
      auth.value = token
      form.appendChild(auth)
    }

    document.body.appendChild(form)
    form.submit()
  }

  _escape(text) {
    return (text || "").replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]))
  }
}
