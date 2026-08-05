#!/usr/bin/env python3
PATH = "plateau-politique.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + isn);
  state.pop = Math.max(0, Math.min(100, state.pop + pop));
  updateUI();
  showToast('Intervention menée', label + ' — +' + isn + ' ISN, ' + (pop<=0?pop:'+'+pop) + ' POP.', pop >= 0, true);
  addJournalEntry('Intervention des forces de l\\'ordre : ' + label + '.', pop < -5 ? 'event-bad' : 'event-info');
  addExternalEvent('🚔 Intervention des forces de l\\'ordre : ' + label + '.');
}"""

new = """  // Repression violente ('reprimer') sur un batiment en blocus syndical : la manière forte
  // nourrit la cause plutot que de l'eteindre (sympathie pour les opprimes), sur demande
  // explicite de Fred le 5 aout 2026.
  if (id === 'reprimer') {
    const etatBatiment = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(pays, state.currentCity, state.currentBuilding) : null;
    if (etatBatiment?.blocus) {
      const orgas = (typeof chargerOrgas === 'function') ? chargerOrgas() : (state.orgas || []);
      const syndicat = orgas.find(o => o.id === etatBatiment.blocus.syndicatId);
      if (syndicat) {
        syndicat.repressionsSubies = (syndicat.repressionsSubies || 0) + 1;
        if (typeof sauvegarderOrga === 'function') sauvegarderOrga(syndicat);
      }
      if (INDICES_NATIONAUX[pays]) INDICES_NATIONAUX[pays].ISN = Math.min(100, INDICES_NATIONAUX[pays].ISN + isn);
      state.pop = Math.max(0, Math.min(100, state.pop + pop));
      updateUI();
      showToast('Répression menée', 'La manière forte nourrit la cause syndicale plutôt que de l\\'éteindre. +' + isn + ' ISN, ' + pop + ' POP — mais le syndicat en sort renforcé.', false, true);
      addJournalEntry('Répression violente d\\'un blocus syndical : la sympathie publique bascule en faveur des grévistes.', 'event-bad');
      addExternalEvent('🚔 Répression violente d\\'un blocus syndical — l\\'opinion publique s\\'émeut.');
      return;
    }
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

print("✅ Répression violente enrichie : nourrit la puissance syndicale via repressionsSubies.")
