#!/usr/bin/env python3
PATH = "plateau-communication.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function donnerTracts(pjName) {"""

new = """// Verifie les objets recus (dons d'un autre joueur, reellement persistes via
// sbDonnerObjetJoueur) et les ajoute a l'inventaire local. Meme rythme que les mails.
async function verifierObjetsRecus() {
  if (typeof sbGetObjetsRecus !== 'function' || !state.char?.name) return;
  try {
    const objets = await sbGetObjetsRecus(state.char.name);
    if (!objets || objets.length === 0) return;

    for (const { id, expediteur, objet } of objets) {
      const qteAjoutee = typeof addToInventory === 'function' ? addToInventory(objet) : 0;
      if (qteAjoutee > 0) {
        if (typeof sbSupprimerObjetRecu === 'function') await sbSupprimerObjetRecu(id).catch(() => {});
        if (typeof showToast === 'function') showToast('Objet reçu !', expediteur + ' vous a donné "' + objet.name + '".', true, true);
        if (typeof addJournalEntry === 'function') addJournalEntry(expediteur + ' vous a donné "' + objet.name + '".', 'event-good');
      }
      // Si l'inventaire est plein (qteAjoutee === 0), l'objet reste en attente en base et
      // sera propose de nouveau au prochain passage, une fois de la place liberee.
    }
  } catch(e) {}
}

function donnerTracts(pjName) {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ verifierObjetsRecus créée.")
