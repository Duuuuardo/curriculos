import { Controller } from "@hotwired/stimulus"

// Salva o form quando um campo muda (selects/checkboxes) ou quando sai de um campo editado
// (equivalente ao BlurField do fields.tsx). Com Turbo morph, o submit recarrega só o que mudou.
export default class extends Controller {
  blur(event) {
    const field = event.target
    if (field.value !== field.defaultValue) this.element.requestSubmit()
  }

  change() {
    this.element.requestSubmit()
  }
}
