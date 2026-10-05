#!/usr/bin/env python3
PATH = "plateau-politique.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function confirmerMobilisationPolice(id, label, isn, pop) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';
  if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + isn);
  state.pop = Math.max(0, Math.min(100, state.pop + pop));
  updateUI();
  showToast('Intervention menée', label + ' — +' + isn + ' ISN, ' + (pop<=0?pop:'+'+pop) + ' POP.', pop >= 0, true);
  addJournalEntry('Intervention des forces de l\\'ordre : ' + label + '.', pop < -5 ? 'event-bad' : 'event-info');
  addExternalEvent('🚔 Intervention des forces de l\\'ordre : ' + label + '.');
}"""

new = """async function confirmerMobilisationPolice(id, label, isn, pop) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const pays = state.country || 'republic';

  // Cas special : disperser un blocus reellement en cours dans le batiment ou l'on se trouve
  // (pas seulement decoratif — voir plateau-organisations-quetes.js pour la creation du
  // blocus). Les PNJ militants restent employes du syndicat quelle que soit l'issue.
  if (id === 'blocus') {
    const etatActuel = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, state.currentCity, state.currentBuilding) : null;
    if (!etatActuel?.blocus) {
      showToast('Aucun blocus', "Il n'y a pas de blocus syndical en cours ici.", false);
      return;
    }
    const intensite = etatActuel.blocus.intensite || 40;
    const taux = Math.max(10, Math.min(90, 55 - intensite / 3));
    const roll = Math.floor(Math.random() * 100) + 1;

    if (roll <= taux) {
      const patch = { blocus: null };
      if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(pays, state.currentCity, state.currentBuilding, patch).catch(() => {});
      if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + isn);
      state.pop = Math.max(0, Math.min(100, state.pop + pop));
      updateUI();
      showToast('Blocus dispersé !', 'Les forces de l\\'ordre ont délogé les militants. +' + isn + ' ISN, ' + pop + ' POP.', true, true);
      addJournalEntry('Le blocus syndical a été dispersé par la police.', 'event-info');
      addExternalEvent('🚔 Un blocus syndical a été dispersé par les forces de l\\'ordre.');
      if (typeof sendMail === 'function' && etatActuel.blocus.leaderActuel) {
        await sendMail(etatActuel.blocus.leaderActuel, 'Police', 'Blocus dispersé', 'Les forces de l\\'ordre ont dispersé votre blocus. Vos militants restent employés, libre à vous de les renvoyer ou de retenter ailleurs.');
      }
    } else {
      showToast('Échec', 'Les militants ont tenu bon face aux forces de l\\'ordre.', false);
      addJournalEntry('Tentative de dispersion du blocus syndical échouée.', 'event-bad');
    }
    return;
  }

  if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + isn);
  state.pop = Math.max(0, Math.min(100, state.pop + pop));
  updateUI();
  showToast('Intervention menée', label + ' — +' + isn + ' ISN, ' + (pop<=0?pop:'+'+pop) + ' POP.', pop >= 0, true);
  addJournalEntry('Intervention des forces de l\\'ordre : ' + label + '.', pop < -5 ? 'event-bad' : 'event-info');
  addExternalEvent('🚔 Intervention des forces de l\\'ordre : ' + label + '.');
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Délogement policier réel du blocus créé, connecté à doMobiliserPolice.")
