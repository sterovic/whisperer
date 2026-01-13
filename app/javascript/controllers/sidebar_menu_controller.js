import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submenu"]

  connect() {
    this.closeAllSubmenusOnLoad()
    this.setupSubmenuListeners()
  }

  closeAllSubmenusOnLoad() {
    // Close all submenus on page load
    this.submenuTargets.forEach(submenu => {
      submenu.removeAttribute('open')
    })
  }

  setupSubmenuListeners() {
    // Add click listeners to all submenu summary elements
    this.submenuTargets.forEach(submenu => {
      const summary = submenu.querySelector('summary')
      if (summary) {
        summary.addEventListener('click', (e) => {
          // If clicking to open this submenu, close all others
          if (!submenu.hasAttribute('open')) {
            this.closeAllSubmenusExcept(submenu)
          }
        })
      }
    })

    // Close all dropdowns and submenus when clicking outside
    document.addEventListener('click', (e) => {
      const clickedInsideMenu = e.target.closest('[data-controller="sidebar-menu"]')
      if (!clickedInsideMenu) {
        this.closeAllSubmenus()
      }
    })
  }

  closeAllSubmenus() {
    this.submenuTargets.forEach(submenu => {
      submenu.removeAttribute('open')
    })
  }

  closeAllSubmenusExcept(exceptSubmenu) {
    this.submenuTargets.forEach(submenu => {
      if (submenu !== exceptSubmenu) {
        submenu.removeAttribute('open')
      }
    })
  }
}
