#!/usr/bin/env python3
PATH = "plateau-organisations-quetes.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// SE RENSEIGNER (halls de Centre d'Affaires / Centre Commercial / Travées du Centre Artisanal)"""

new = """// Verification a l'entree d'un batiment : met en cache l'etat du blocus (async, sur
// state.blocusActifIci) pour une lecture synchrone ulterieure par doOrder(), et affiche la
// popup si un blocus non encore tranche pour cette visite est actif.
async function verifierBlocusEntree(buildingId, roomId) {
  if (typeof sbGetBatimentEtat !== 'function') return;
  const etat = await sbGetBatimentEtat(state.country, state.currentCity, buildingId).catch(() => null);
  state.blocusActifIci = etat?.blocus || null;

  if (!state.blocusActifIci) return;
  if (state.blocusEntreeResolueBuildingId === buildingId) return; // deja tranche pour cette visite
  if (state.currentBuilding !== buildingId) return; // le joueur a change de piece entre temps

  afficherPopupBlocusEntree(buildingId);
}

function afficherPopupBlocusEntree(buildingId) {
  const b = state.blocusActifIci;
  if (!b) return;
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#c0b090;margin-bottom:.6rem"><strong>' + (b.syndicatNom || 'Un syndicat') + '</strong> bloque l\\'accès à ce bâtiment.</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;font-style:italic;margin-bottom:.8rem">"' + b.revendication + '"</div>';
  html += '<div style="font-size:.75rem;color:#6a5a30;margin-bottom:.8rem">Les démarches administratives sont bloquées ici. Les activités illégales y sont facilitées.</div>';
  html += '<div style="display:flex;gap:.5rem">';
  html += '<button class="pnj-action-btn" onclick="doForcerBlocus(\\'' + buildingId + '\\')">Forcer le passage</button>';
  html += '<button class="pnj-action-btn" onclick="sortirBatiment()" style="opacity:.8">Repartir</button>';
  html += '</div></div>';
  document.getElementById('postes-modal-title').textContent = 'Blocus en cours';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doForcerBlocus(buildingId) {
  document.getElementById('modal-postes')?.classList.remove('open');
  const forStat = state.char?.stats?.FOR || 8;
  const volStat = state.char?.stats?.VOL || 8;
  const intensite = state.blocusActifIci?.intensite || 40;
  const taux = Math.max(5, Math.min(90, Math.round(40 + (forStat - 10) * 3 + (volStat - 10) * 3 - intensite / 2)));
  const roll = Math.floor(Math.random() * 100) + 1;

  if (roll <= taux) {
    state.blocusEntreeResolueBuildingId = buildingId;
    state.blocusModificateurLegal = 20; // bonus applique aux ordres legaux pendant cette visite (compense en partie le malus du blocus)
    showToast('Passage forcé !', 'Vous entrez malgré le blocus.', true);
    addJournalEntry('Passage forcé à travers un blocus syndical.', 'event-good');
    if (typeof updateUI === 'function') updateUI();
  } else {
    showToast('Refoulé', 'Les militants vous repoussent.', false);
    addJournalEntry('Tentative de passage en force repoussée par des militants.', 'event-bad');
    if (typeof sortirBatiment === 'function') sortirBatiment();
  }
}

// SE RENSEIGNER (halls de Centre d'Affaires / Centre Commercial / Travées du Centre Artisanal)"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Popup d'entrée du blocus créée (revendication, forcer/repartir avec FOR+VOL).")
