import { Controller } from "@hotwired/stimulus"
import { toast } from "application"

// Copia a carta de apresentação para a área de transferência.
export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue)
      .then(() => toast("Carta copiada!"))
      .catch(() => toast("Não foi possível copiar", "error"))
  }
}
