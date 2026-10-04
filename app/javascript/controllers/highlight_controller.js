import { Controller } from "@hotwired/stimulus"

// Liga/desliga o destaque <mark> das palavras-chave na prévia do currículo.
export default class extends Controller {
  static targets = ["page"]

  toggle(event) {
    this.pageTarget.classList.toggle("marks-off", !event.target.checked)
  }
}
