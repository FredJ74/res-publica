#!/usr/bin/env python3
PATH = "plateau-quete-accueil.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function afficherPopupQueteAccueil(opts) {
  const modal = document.getElementById('modal-quete-accueil');
  if (!modal) return;"""
new = """function afficherPopupQueteAccueil(opts) {
  const modal = document.getElementById('modal-quete-accueil');
  if (!modal) return;

  // Ne jamais ouvrir une pop-up de quete par-dessus une fenetre deja ouverte (ex: le minuteur
  // de reprise de contact de Jeremy qui se declenche pendant que le joueur discute avec un PNJ).
  // On reessaie regulierement jusqu'a ce que la voie soit libre.
  const pnjModalOuverte = document.getElementById('modal-pnj')?.classList.contains('open');
  const autreModaleOuverte = Array.from(document.querySelectorAll('.modal-overlay.open'))
    .some(m => m.id !== 'modal-quete-accueil');
  if (pnjModalOuverte || autreModaleOuverte) {
    setTimeout(function() { afficherPopupQueteAccueil(opts); }, 2000);
    return;
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Anti-collision ajouté : nos pop-up attendent qu'aucune autre fenêtre ne soit ouverte.")
