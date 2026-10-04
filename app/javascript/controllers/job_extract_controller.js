import { Controller } from "@hotwired/stimulus"
import { toast } from "application"

// Botão "Preencher com IA" no formulário de nova vaga: lê a descrição colada,
// chama POST /ai/extract_job e preenche título, empresa, link e idioma.
export default class extends Controller {
  static targets = ["description", "title", "company", "url", "language"]
  static values = { url: String }

  async run(event) {
    const button = event.target.closest("button")
    const description = this.descriptionTarget.value.trim()
    if (!description) {
      toast("Cole a descrição da vaga primeiro.", "error")
      return
    }

    button.disabled = true
    const original = button.textContent
    button.textContent = "Analisando…"
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "application/json"
        },
        body: new URLSearchParams({ description })
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error || "Falha na extração")

      if (data.title) this.titleTarget.value = data.title
      if (data.company) this.companyTarget.value = data.company
      if (data.url) this.urlTarget.value = data.url
      if (data.language) this.languageTarget.value = data.language
      toast("Campos preenchidos pela IA — confira antes de criar.")
    } catch (error) {
      toast(error.message, "error")
    } finally {
      button.disabled = false
      button.textContent = original
    }
  }
}
