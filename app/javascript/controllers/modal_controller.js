import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Close on escape key
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  close() {
    // Clear the turbo frame by replacing with empty content
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.innerHTML = ""
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}