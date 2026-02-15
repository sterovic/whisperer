import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="video-selection"
export default class extends Controller {
  static targets = ["selectAll", "checkbox", "bulkActions", "selectionInfo", "videoIdsContainer", "form"]

  connect() {
    this.updateSelection()
  }

  toggleAll() {
    const isChecked = this.selectAllTarget.checked
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    this.updateSelection()
  }

  updateSelection() {
    const selectedCheckboxes = this.checkboxTargets.filter(cb => cb.checked)
    const selectedCount = selectedCheckboxes.length
    const totalCount = this.checkboxTargets.length

    // Update select all checkbox state
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = selectedCount === totalCount && totalCount > 0
      this.selectAllTarget.indeterminate = selectedCount > 0 && selectedCount < totalCount
    }

    // Show/hide bulk actions
    if (this.hasBulkActionsTarget) {
      this.bulkActionsTarget.classList.toggle("hidden", selectedCount === 0)
    }

    // Update selection info
    if (this.hasSelectionInfoTarget) {
      if (selectedCount > 0) {
        this.selectionInfoTarget.textContent = `${selectedCount} selected`
      } else {
        this.selectionInfoTarget.textContent = ""
      }
    }

    // Update hidden inputs with selected video IDs in all containers
    this.videoIdsContainerTargets.forEach(container => {
      container.innerHTML = ""
      selectedCheckboxes.forEach(checkbox => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "video_ids[]"
        input.value = checkbox.dataset.videoId
        container.appendChild(input)
      })
    })
  }

  // Clear selection after form submit
  clearSelection() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
    }
    this.updateSelection()
  }
}