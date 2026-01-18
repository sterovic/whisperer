import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["trigger", "content", "icon"];
  static values = { expanded: Boolean };

  toggle() {
    this.expandedValue = !this.expandedValue;
  }

  expandedValueChanged() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden", !this.expandedValue);
    }

    if (this.hasIconTarget) {
      this.iconTarget.classList.toggle("rotate-90", this.expandedValue);
    }
  }
}