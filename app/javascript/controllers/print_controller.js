import { Controller } from "@hotwired/stimulus"

// Ajusta o título do documento antes de imprimir para que o PDF saia com o nome certo
// (equivalente ao onClick do botão "Baixar PDF").
export default class extends Controller {
  static values = { title: String }

  print() {
    const previous = document.title
    document.title = this.titleValue
    window.print()
    document.title = previous
  }
}
