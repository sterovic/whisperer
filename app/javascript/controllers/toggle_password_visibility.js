import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "checkbox"];

  toggle() {
    if (this.inputTarget) {
      if (this.checkboxTarget.checked) {
        this.inputTarget.type = "text";
      } else {
        this.inputTarget.type = "password";
      }
    }
  }
}
