// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Toast flutuante (equivalente ao estado `toasts` do App.tsx) para ações em JS puro,
// como "carta copiada".
export function toast(text, kind = "ok") {
  let box = document.querySelector(".toasts")
  if (!box) {
    box = document.createElement("div")
    box.className = "toasts no-print"
    document.body.appendChild(box)
  }
  const el = document.createElement("div")
  el.className = `toast ${kind}`
  el.textContent = text
  el.setAttribute("data-controller", "toast")
  box.appendChild(el)
}
