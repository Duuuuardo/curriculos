import { Controller } from "@hotwired/stimulus"

// Remove toasts automaticamente após alguns segundos.
export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => this.element.remove(), 4000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
