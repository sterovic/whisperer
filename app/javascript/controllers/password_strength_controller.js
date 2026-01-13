import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="password-strength"
export default class extends Controller {
  static targets = ["password", "requirements", "strengthBar", "strengthText"]

  checkStrength() {
    const password = this.passwordTarget.value
    const requirements = {
      length: password.length >= 8,
      lowercase: /[a-z]/.test(password),
      uppercase: /[A-Z]/.test(password),
      number: /\d/.test(password),
      special: /[!@#$%^&*]/.test(password)
    }

    // Update requirement indicators
    this.requirementsTarget.querySelectorAll("[data-requirement]").forEach(el => {
      const requirement = el.dataset.requirement
      const met = requirements[requirement]
      const icon = el.querySelector("span:first-child")

      if (met) {
        icon.textContent = "✓"
        icon.classList.remove("text-error")
        icon.classList.add("text-success")
      } else {
        icon.textContent = "✗"
        icon.classList.remove("text-success")
        icon.classList.add("text-error")
      }
    })

    // Calculate strength score
    const score = Object.values(requirements).filter(Boolean).length
    this.updateStrengthBar(score, password.length > 0)
  }

  updateStrengthBar(score, hasPassword) {
    if (!hasPassword) {
      // Reset
      this.strengthBarTargets.forEach(bar => {
        bar.classList.remove("bg-error", "bg-warning", "bg-info", "bg-success")
        bar.classList.add("bg-base-300")
      })
      this.strengthTextTarget.textContent = "Enter a password"
      this.strengthTextTarget.classList.remove("text-error", "text-warning", "text-info", "text-success")
      return
    }

    // Clear all bars first
    this.strengthBarTargets.forEach(bar => {
      bar.classList.remove("bg-error", "bg-warning", "bg-info", "bg-success")
      bar.classList.add("bg-base-300")
    })

    let strength = ""
    let colorClass = ""
    let textClass = ""

    if (score <= 2) {
      strength = "Weak"
      colorClass = "bg-error"
      textClass = "text-error"
      this.strengthBarTargets.slice(0, 1).forEach(bar => {
        bar.classList.remove("bg-base-300")
        bar.classList.add(colorClass)
      })
    } else if (score === 3) {
      strength = "Fair"
      colorClass = "bg-warning"
      textClass = "text-warning"
      this.strengthBarTargets.slice(0, 2).forEach(bar => {
        bar.classList.remove("bg-base-300")
        bar.classList.add(colorClass)
      })
    } else if (score === 4) {
      strength = "Good"
      colorClass = "bg-info"
      textClass = "text-info"
      this.strengthBarTargets.slice(0, 3).forEach(bar => {
        bar.classList.remove("bg-base-300")
        bar.classList.add(colorClass)
      })
    } else {
      strength = "Strong"
      colorClass = "bg-success"
      textClass = "text-success"
      this.strengthBarTargets.forEach(bar => {
        bar.classList.remove("bg-base-300")
        bar.classList.add(colorClass)
      })
    }

    this.strengthTextTarget.textContent = `Password strength: ${strength}`
    this.strengthTextTarget.classList.remove("text-error", "text-warning", "text-info", "text-success")
    this.strengthTextTarget.classList.add(textClass)
  }
}
