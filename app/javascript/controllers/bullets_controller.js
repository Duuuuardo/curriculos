import { Controller } from "@hotwired/stimulus"

// Adiciona/remove linhas de tópicos dentro de um item do perfil (equivalente ao BulletsField).
export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
    this.listTarget.lastElementChild?.querySelector("textarea")?.focus()
    this.#changed()
  }

  remove(event) {
    event.target.closest(".bullet-row").remove()
    this.#changed()
  }

  #changed() {
    this.element.dispatchEvent(new CustomEvent("app:dirty", { bubbles: true }))
  }
}
