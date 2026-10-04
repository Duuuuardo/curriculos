import { Controller } from "@hotwired/stimulus"

// Chips editáveis (palavras-chave, tecnologias…): Enter/vírgula/blur adiciona, × remove.
// Com autosubmit=true o form é enviado a cada mudança (vaga); sem ele só marca dirty (perfil).
export default class extends Controller {
  static targets = ["input", "list"]
  static values = { autosubmit: Boolean }

  commit(event) {
    if (event.type === "keydown") {
      if (event.key !== "Enter" && event.key !== ",") return
      event.preventDefault()
    }
    const draft = this.inputTarget.value
    if (!draft.trim()) return

    draft.split(",").map((tag) => tag.trim()).filter(Boolean).forEach((tag) => {
      if (this.#has(tag)) return
      this.listTarget.insertAdjacentHTML("beforeend", this.#chip(tag))
    })
    this.inputTarget.value = ""
    this.#changed()
  }

  remove(event) {
    event.target.closest(".tag").remove()
    this.#changed()
  }

  #has(tag) {
    return Array.from(this.listTarget.querySelectorAll(`input[name="${this.#name}"]`))
      .some((field) => field.value === tag)
  }

  #chip(tag) {
    const escaped = tag.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll('"', "&quot;")
    return `<span class="tag">${escaped}` +
      `<input type="hidden" name="${this.#name}" value="${escaped}">` +
      `<button type="button" title="Remover" data-action="tags#remove">×</button></span>`
  }

  get #name() {
    return this.inputTarget.dataset.name
  }

  #changed() {
    if (this.autosubmitValue) {
      this.element.requestSubmit()
    } else {
      this.element.dispatchEvent(new CustomEvent("app:dirty", { bubbles: true }))
    }
  }
}
