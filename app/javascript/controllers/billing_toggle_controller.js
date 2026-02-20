import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthlyBtn", "yearlyBtn", "monthlyPrice", "yearlyPrice"]

  connect() {
    this.showYearly()
  }

  showMonthly() {
    this.monthlyBtnTarget.classList.add("btn-active")
    this.yearlyBtnTarget.classList.remove("btn-active")
    this.monthlyPriceTargets.forEach(el => el.classList.remove("hidden"))
    this.yearlyPriceTargets.forEach(el => el.classList.add("hidden"))
  }

  showYearly() {
    this.yearlyBtnTarget.classList.add("btn-active")
    this.monthlyBtnTarget.classList.remove("btn-active")
    this.yearlyPriceTargets.forEach(el => el.classList.remove("hidden"))
    this.monthlyPriceTargets.forEach(el => el.classList.add("hidden"))
  }
}
