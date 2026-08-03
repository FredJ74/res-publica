#!/usr/bin/env python3
PATH = "plateau-pnj.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  // Enigme du portrait disparu : temoignages scriptes des 3 pensionnaires de l'EHPAD."""

new = """  // Enigme du portrait disparu : Clerc Delhune (notaire) et Directeur Mercier (banquier),
  // temoignages parles en complement des archives ecrites.
  const nomCourtEnigme = (pnj.name || '').replace(' (PNJ)', '').trim();
  if (typeof enigme1EtapeActive === 'function' && enigme1EtapeActive()) {
    if (nomCourtEnigme === 'Clerc Delhune' && /thibault/i.test(action)) {
      speech.textContent = "Thibault... Pierre Thibault, c'est ça ? Oui, j'ai eu le dossier de sa succession entre les mains, il y a bien longtemps. De mémoire, il y avait mention d'un coffre à la Banque Nationale, toujours actif d'ailleurs. Pour le détail exact, il faudra consulter les archives notariales.";
      return;
    }
    if (nomCourtEnigme === 'Directeur Mercier' && /coffre|thibault/i.test(action)) {
      speech.textContent = "Un coffre lié à cette succession ? Oui, la location n'a jamais été interrompue depuis... eh bien, depuis très longtemps. Mais je ne peux vous dire qui la règle aujourd'hui — secret bancaire, vous comprenez. Il vous faudrait une autorisation en bonne et due forme pour aller plus loin.";
      return;
    }
  }

  // Enigme du portrait disparu : temoignages scriptes des 3 pensionnaires de l'EHPAD."""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Dialogues du Clerc Delhune et du Directeur Mercier ajoutés (mots-clés : Thibault / coffre).")
