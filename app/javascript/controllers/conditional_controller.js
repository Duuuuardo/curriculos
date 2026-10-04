import { Controller } from "@hotwired/stimulus"

// Esconde o campo "Fim" quando "Trabalho aqui atualmente" está marcado.
export default class extends Controller {
  static targets = ["trigger", "collapsible"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.collapsibleTarget.hidden = this.triggerTarget.checked
  }
}
