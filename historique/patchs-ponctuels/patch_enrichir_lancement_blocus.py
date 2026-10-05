#!/usr/bin/env python3
PATH = "plateau-organisations-quetes.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function confirmerOrganiserBlocus(syndicatId) {
  const nbMilitants = parseInt(document.getElementById('blocus-nb-militants')?.value || 2);
  const revendication = (document.getElementById('blocus-revendication')?.value || 'Revendications non précisées.').trim();

  const infos = getMonSyndicatEtGrade();
  const syndicat = infos?.syndicat;
  const taux = Math.min(85, 10 + nbMilitants * 6);
  const intensite = taux; // meme echelle : plus le blocus a de chances de reussir, plus il est intense une fois en place

  const roll = Math.floor(Math.random() * 100) + 1;
  document.getElementById('modal-postes')?.classList.remove('open');

  if (roll > taux) {
    showToast('Blocus raté', 'Les militants n\\'ont pas réussi à s\\'organiser cette fois-ci.', false);
    addJournalEntry('Tentative de blocus syndical ratée.', 'event-bad');
    return;
  }"""

new = """async function confirmerOrganiserBlocus(syndicatId) {
  const nbMilitants = parseInt(document.getElementById('blocus-nb-militants')?.value || 2);
  const revendication = (document.getElementById('blocus-revendication')?.value || 'Revendications non précisées.').trim();

  const infos = getMonSyndicatEtGrade();
  const syndicat = infos?.syndicat;
  const puissance = calculerPuissanceSyndicale(syndicat, false);
  const taux = Math.min(90, 10 + nbMilitants * 6 + Math.round(puissance / 5)); // la puissance du syndicat facilite les futurs blocus
  const intensite = Math.min(90, 10 + nbMilitants * 6); // l'intensite reste liee aux seuls militants mobilises, pas au bonus de puissance

  const roll = Math.floor(Math.random() * 100) + 1;
  document.getElementById('modal-postes')?.classList.remove('open');

  if (roll > taux) {
    showToast('Blocus raté', 'Les militants n\\'ont pas réussi à s\\'organiser cette fois-ci.', false);
    addJournalEntry('Tentative de blocus syndical ratée.', 'event-bad');
    return;
  }

  // Palmares : chaque blocus reussi renforce durablement la puissance syndicale
  syndicat.blocusReussis = (syndicat.blocusReussis || 0) + 1;
  if (typeof sauvegarderOrga === 'function') sauvegarderOrga(syndicat);"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Palmarès de blocus réussis + bonus de puissance sur le taux de réussite créés.")
