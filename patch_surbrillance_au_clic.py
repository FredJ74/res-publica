#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function queteAccueilSurbrillance(selector, dureeMs) {
  const els = document.querySelectorAll(selector);
  if (!els.length) return;
  els.forEach(function(el) { el.classList.add('quete-accueil-surbrillance'); });
  setTimeout(function() {
    els.forEach(function(el) { el.classList.remove('quete-accueil-surbrillance'); });
  }, dureeMs || 10000);
}"""
new = """function queteAccueilSurbrillance(selector, dureeMs) {
  const els = document.querySelectorAll(selector);
  if (!els.length) return;
  els.forEach(function(el) {
    el.classList.add('quete-accueil-surbrillance');
    // Retire la surbrillance des qu'on clique reellement dessus, plutot que d'attendre
    // un delai fixe qui pouvait disparaitre avant meme que le joueur ait eu le temps de cliquer.
    const retirerAuClic = function() {
      el.classList.remove('quete-accueil-surbrillance');
      el.removeEventListener('click', retirerAuClic);
    };
    el.addEventListener('click', retirerAuClic, { once: true });
  });
  // Filet de securite si le joueur ne clique jamais : on retire quand meme apres un delai.
  setTimeout(function() {
    els.forEach(function(el) { el.classList.remove('quete-accueil-surbrillance'); });
  }, dureeMs || 10000);
}"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ La surbrillance dorée disparaît désormais au clic (délai en simple filet de sécurité).")
