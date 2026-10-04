import { Controller } from "@hotwired/stimulus"

// Lista de itens do perfil (experiências, formação, habilidades…): adicionar a partir de
// um <template>, remover, reordenar e expandir/recolher (equivalente ao ListEditor).
export default class extends Controller {
  static targets = ["items", "template", "empty"]

  add() {
    const html = this.templateTarget.innerHTML.replaceAll("__key__", `new_${Date.now()}`)
    this.itemsTarget.insertAdjacentHTML("beforeend", html)
    this.itemsTarget.lastElementChild.classList.add("open")
    this.#changed()
  }

  toggle(event) {
    event.target.closest("li")?.classList.toggle("open")
  }

  remove(event) {
    if (!window.confirm("Remover este item?")) return
    event.target.closest("li").remove()
    this.#changed()
  }

  up(event) {
    this.#move(event, -1)
  }

  down(event) {
    this.#move(event, 1)
  }

  #move(event, direction) {
    const item = event.target.closest("li")
    const sibling = direction < 0 ? item.previousElementSibling : item.nextElementSibling
    if (!sibling) return
    direction < 0 ? sibling.before(item) : sibling.after(item)
    this.#changed()
  }

  #changed() {
    if (this.hasEmptyTarget) this.emptyTarget.hidden = this.itemsTarget.children.length > 0
    this.element.dispatchEvent(new CustomEvent("app:dirty", { bubbles: true }))
  }
}
