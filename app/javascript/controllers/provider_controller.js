import { Controller } from "@hotwired/stimulus"

// Mostra os campos certos conforme o provedor de IA escolhido nas Configurações:
// Ollama usa endereço local; os demais usam chave de API + URL base opcional.
export default class extends Controller {
  static targets = ["select", "apiField", "ollamaField"]

  connect() {
    this.toggle()
  }

  toggle() {
    const ollama = this.selectTarget.value === "ollama"
    this.apiFieldTargets.forEach((field) => (field.hidden = ollama))
    this.ollamaFieldTargets.forEach((field) => (field.hidden = !ollama))
  }
}
