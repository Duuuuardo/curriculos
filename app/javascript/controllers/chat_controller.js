import { Controller } from "@hotwired/stimulus"

// Comportamento do chat do Assistente: auto-scroll, Enter para enviar,
// estado "enviando" no botão, abrir/fechar popup e prefill via evento
// "chat:prefill" (usado por "Revisar com IA" sobre trechos do currículo).
export default class extends Controller {
  static targets = ["log", "input", "send", "window"]

  connect() {
    this.scrollToEnd()
    this.observer = new MutationObserver(() => this.scrollToEnd())
    if (this.hasLogTarget) this.observer.observe(this.logTarget, { childList: true })
    this.onPrefill = (event) => this.prefill(event.detail.text)
    window.addEventListener("chat:prefill", this.onPrefill)
  }

  disconnect() {
    this.observer?.disconnect()
    window.removeEventListener("chat:prefill", this.onPrefill)
  }

  toggle() {
    if (!this.hasWindowTarget) return
    this.windowTarget.hidden = !this.windowTarget.hidden
    if (!this.windowTarget.hidden) {
      this.scrollToEnd()
      this.inputTarget?.focus()
    }
  }

  open() {
    if (this.hasWindowTarget && this.windowTarget.hidden) this.toggle()
  }

  // detail.text preenche a caixa de entrada (não envia — o usuário revisa antes)
  prefill(text) {
    this.open()
    if (this.hasInputTarget) {
      this.inputTarget.value = text
      this.inputTarget.focus()
    }
  }

  keydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      if (event.target.value.trim()) this.element.querySelector("form").requestSubmit()
    }
  }

  sending() {
    if (this.hasSendTarget) {
      this.sendTarget.disabled = true
      this.sendTarget.textContent = "Pensando…"
    }
  }

  scrollToEnd() {
    if (this.hasLogTarget) this.logTarget.scrollTop = this.logTarget.scrollHeight
  }
}
