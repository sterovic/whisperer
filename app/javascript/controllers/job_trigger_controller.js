import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="job-trigger"
export default class extends Controller {
  static targets = ["button"]

  trigger(event) {
    // Disable button during job execution
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.classList.add("loading")
    }

    // Re-enable after job is queued (optional: could keep disabled until completion)
    setTimeout(() => {
      if (this.hasButtonTarget) {
        this.buttonTarget.disabled = false
        this.buttonTarget.classList.remove("loading")
      }
    }, 1000)
  }

  // Handle job completion events
  handleCompletion(event) {
    console.log("Job completed:", event.detail)
    // You can show notifications or update UI here
  }
}
