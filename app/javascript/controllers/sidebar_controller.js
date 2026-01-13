import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "text", "logo"]
  static values = { expanded: Boolean }

  connect() {
    this.expandedValue = true
  }

  toggle() {
    this.expandedValue = !this.expandedValue
    this.updateSidebar()
  }

  updateSidebar() {
    if (this.expandedValue) {
      this.sidebarTarget.style.width = "16rem"
      this.textTargets.forEach(el => {
        el.classList.remove("hidden")
        el.classList.add("opacity-100")
      })
    } else {
      this.sidebarTarget.style.width = "4.5rem"
      this.textTargets.forEach(el => {
        el.classList.add("hidden")
        el.classList.remove("opacity-100")
      })
    }
  }
}
