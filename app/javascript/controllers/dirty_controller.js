import { Controller } from "@hotwired/stimulus"

// Avisa ao sair com alterações não salvas no formulário do perfil (equivalente ao `dirty`
// do ProfileEditor) e mantém o botão "Salvar" habilitado só quando há mudanças.
export default class extends Controller {
  static targets = ["save"]

  connect() {
    this.dirty = false
    this.onInput = () => this.#mark()
    this.onSubmit = () => { this.dirty = false }
    this.onBeforeVisit = (event) => {
      if (!this.dirty) return
      if (!window.confirm("Você tem alterações não salvas no perfil. Sair mesmo assim?")) {
        event.preventDefault()
      }
    }
    this.onBeforeUnload = (event) => {
      if (this.dirty) event.preventDefault()
    }

    this.element.addEventListener("input", this.onInput)
    this.element.addEventListener("change", this.onInput)
    this.element.addEventListener("app:dirty", this.onInput)
    this.element.addEventListener("submit", this.onSubmit)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    window.addEventListener("beforeunload", this.onBeforeUnload)
  }

  disconnect() {
    this.element.removeEventListener("input", this.onInput)
    this.element.removeEventListener("change", this.onInput)
    this.element.removeEventListener("app:dirty", this.onInput)
    this.element.removeEventListener("submit", this.onSubmit)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
  }

  #mark() {
    this.dirty = true
    if (this.hasSaveTarget) this.saveTarget.disabled = false
  }
}
