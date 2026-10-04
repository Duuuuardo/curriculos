import { Controller } from "@hotwired/stimulus"

// Seleção de texto dentro do preview do currículo: mostra um botão
// "Revisar com IA" que abre o popup do Assistente com o trecho preenchido.
export default class extends Controller {
  static values = { jobTitle: String }

  connect() {
    this.button = document.createElement("button")
    this.button.type = "button"
    this.button.className = "selection-ai no-print"
    this.button.textContent = "✨ Revisar com IA"
    this.button.hidden = true
    this.button.addEventListener("mousedown", (e) => e.preventDefault()) // mantém a seleção
    this.button.addEventListener("click", () => this.askAi())
    document.body.appendChild(this.button)

    this.onMouseUp = (event) => this.show(event)
    this.onMouseDown = (event) => {
      if (!this.button.contains(event.target)) this.hide()
    }
    this.element.addEventListener("mouseup", this.onMouseUp)
    document.addEventListener("mousedown", this.onMouseDown)
  }

  disconnect() {
    this.element.removeEventListener("mouseup", this.onMouseUp)
    document.removeEventListener("mousedown", this.onMouseDown)
    this.button.remove()
  }

  show(event) {
    const selection = window.getSelection()
    const text = selection?.toString().trim() || ""
    if (text.length < 8 || !this.element.contains(selection.anchorNode)) {
      this.hide()
      return
    }
    this.selectedText = text.slice(0, 800)
    const rect = selection.getRangeAt(0).getBoundingClientRect()
    this.button.style.left = `${Math.min(rect.right - 140, window.innerWidth - 190)}px`
    this.button.style.top = `${rect.bottom + 8}px`
    this.button.hidden = false
  }

  hide() {
    if (this.button) this.button.hidden = true
  }

  askAi() {
    const context = this.jobTitleValue ? ` do currículo da vaga "${this.jobTitleValue}"` : " do meu currículo"
    window.dispatchEvent(new CustomEvent("chat:prefill", {
      detail: { text: `Trecho${context}:\n\n"${this.selectedText}"\n\n` }
    }))
    this.hide()
    window.getSelection()?.removeAllRanges()
  }
}
