#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function doTentativeEvasion() {
  if (!state.estEmprisonne) {
    showToast('Non emprisonne', 'Vous devez etre emprisonne pour tenter de vous evader.', false);
    return;
  }
  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= 5) {
    state.estEmprisonne = null;
    state.recherche = [];
    showToast('Evasion reussie !', 'Vous etes libre ! Restez discret.', true, true);
    addJournalEntry('Evasion reussie !', 'event-good');
  } else {
    const cur = COUNTRIES[state.country]?.cur || 'FR';
    if (state.estEmprisonne) {
      state.estEmprisonne.jours += 1;
      state.estEmprisonne.jourFin += 1;
    }
    state.arg = Math.max(0, (state.arg || 0) - 500);
    updateUI();
    showToast('Evasion echouee', 'Tentative echouee. +1 jour de detention, -500 ' + cur + '.', false);
    addJournalEntry('Tentative d\\'evasion echouee. Peine aggravee de 1 jour, amende de 500 ' + cur + '.', 'event-bad');
  }
}"""

new = """// Une tentative d'evasion par jour maximum (bug de spam remonte le 4 aout 2026 : les PA
// illimites de la phase de test permettaient de retenter indefiniment). Taux de base 10%,
// modifie par DUP et l'indice de securite du pays — meme formule que le vol/cambriolage.
function doTentativeEvasion() {
  if (!state.estEmprisonne) {
    showToast('Non emprisonne', 'Vous devez etre emprisonne pour tenter de vous evader.', false);
    return;
  }

  const jourActuel = state.day || 1;
  if (state.estEmprisonne.dernierJourEvasion === jourActuel) {
    showToast('Trop tôt', 'Une seule tentative d\\'évasion par jour.', false);
    return;
  }
  state.estEmprisonne.dernierJourEvasion = jourActuel;

  const pays = state.country;
  const dup = state.char?.stats?.DUP || 8;
  const isEmpire = (typeof INDICES_NATIONAUX !== 'undefined' && INDICES_NATIONAUX[pays]?.IS) || 45;
  let taux = 10 + (dup - 10) * 2 - (isEmpire - 45) / 3;
  taux = Math.max(2, Math.min(40, Math.round(taux)));

  const roll = Math.floor(Math.random() * 100) + 1;
  if (roll <= taux) {
    state.estEmprisonne = null;
    state.recherche = [];
    showToast('Evasion reussie !', 'Vous etes libre ! Restez discret.', true, true);
    addJournalEntry('Evasion reussie !', 'event-good');
  } else {
    const cur = COUNTRIES[state.country]?.cur || 'FR';
    if (state.estEmprisonne) {
      state.estEmprisonne.jours += 1;
      state.estEmprisonne.jourFin += 1;
    }
    state.arg = Math.max(0, (state.arg || 0) - 500);
    updateUI();
    showToast('Evasion echouee', 'Tentative echouee. +1 jour de detention, -500 ' + cur + '.', false);
    addJournalEntry('Tentative d\\'evasion echouee. Peine aggravee de 1 jour, amende de 500 ' + cur + '.', 'event-bad');
  }
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Évasion limitée à une tentative par jour, taux 10% modifié par DUP/indice de sécurité.")
