// app/javascript/controllers/file_preview_controller.js
import { Controller } from "@hotwired/stimulus"

// Handles opening a modal to preview image/PDF and download
export default class extends Controller {
  static targets = ["modal", "content", "title", "downloadLink"]

  open(event) {
    event.preventDefault()
    const el = event.currentTarget
    const fileUrl = el.dataset.filePreviewFileUrl
    const downloadUrl = el.dataset.filePreviewDownloadUrl
    const fileName = el.dataset.filePreviewFileName || "Attachment"
    const fileType = (el.dataset.filePreviewFileType || "").toLowerCase()

    // Set title and download link
    if (this.hasTitleTarget) this.titleTarget.textContent = fileName
    if (this.hasDownloadLinkTarget) this.downloadLinkTarget.setAttribute("href", downloadUrl)

    // Render content
    let html = ""
    if (fileType.startsWith("image/")) {
      html = `<img src="${fileUrl}" alt="${this._escape(fileName)}" class="max-h-[70vh] w-auto mx-auto rounded" />`
    } else if (fileType === "application/pdf") {
      html = `<iframe src="${fileUrl}" class="w-full h-[70vh] border rounded"></iframe>`
    } else {
      html = `
        <div class="text-center">
          <p class="text-sm text-gray-600 mb-3">Preview not available for this file type.</p>
          <a href="${downloadUrl}" class="px-3 py-1 rounded-md bg-violet-600 text-white hover:bg-violet-700">Download</a>
        </div>`
    }
    if (this.hasContentTarget) this.contentTarget.innerHTML = html

    // Show modal
    if (this.hasModalTarget) this.modalTarget.classList.remove("hidden")
  }

  close() {
    if (this.hasModalTarget) this.modalTarget.classList.add("hidden")
    if (this.hasContentTarget) this.contentTarget.innerHTML = ""
  }

  _escape(text) {
    return (text || "").replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]))
  }
}

