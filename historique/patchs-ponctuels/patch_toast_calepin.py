#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof updateUI === 'function') updateUI();
    if (typeof renderInventory === 'function') renderInventory();
    if (typeof addJournalEntry === 'function') {
      const rumeur = ENIGME1_RUMEURS[variante] || ENIGME1_RUMEURS.maire;
      addJournalEntry(rumeur, 'event-secret');
    }
    return;
  }"""
new = """    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof updateUI === 'function') updateUI();
    if (typeof renderInventory === 'function') renderInventory();
    if (typeof showToast === 'function') {
      showToast("L'enquête commence", "Un calepin pour recueillir vos notes est apparu dans votre inventaire.", true);
    }
    if (typeof addJournalEntry === 'function') {
      const rumeur = ENIGME1_RUMEURS[variante] || ENIGME1_RUMEURS.maire;
      addJournalEntry(rumeur, 'event-secret');
    }
    return;
  }"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Infobulle ajoutée pour l'apparition du calepin.")
