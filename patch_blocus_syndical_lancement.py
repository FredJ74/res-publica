#!/usr/bin/env python3
PATH = "plateau-organisations-quetes.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """// SE RENSEIGNER (halls de Centre d'Affaires / Centre Commercial / Travées du Centre Artisanal)"""

new = """// =====================
// BLOCUS SYNDICAL — reserve au Secretaire General et au Secretaire General Adjoint
// (gradeIdx 1 ou 2 sur la hierarchie syndicale republic ['Adherent','Secretaire General
// Adjoint','Secretaire General','Confederal']). Cible n'importe quel batiment (pas
// seulement les chantiers) : bloque les ordres legaux, favorise les illegaux, tant qu'un
// des deux leaders le renouvelle chaque jour. Delogeable par la police (doMobiliserPolice).
// =====================

function getMonSyndicatEtGrade() {
  const orgas = (typeof chargerOrgas === 'function') ? chargerOrgas() : (state.orgas || []);
  const syndicat = orgas.find(o => o.type === 'syndicale' && o.membres?.some(m => m.nom === state.char?.name));
  if (!syndicat) return null;
  const membre = syndicat.membres.find(m => m.nom === state.char?.name);
  return { syndicat, gradeIdx: membre?.gradeIdx ?? -1 };
}

async function doOrganiserBlocusSyndical() {
  const infos = getMonSyndicatEtGrade();
  if (!infos || infos.gradeIdx < 1 || infos.gradeIdx > 2) {
    showToast('Accès refusé', "Réservé au Secrétaire Général et au Secrétaire Général Adjoint d'un syndicat.", false);
    return;
  }
  const { syndicat } = infos;
  const militants = (syndicat.membres || []).filter(m => m.estPnj);
  if (militants.length < 2) {
    showToast('Effectifs insuffisants', 'Il faut au moins 2 militants recrutés pour organiser un blocus.', false);
    return;
  }

  const etatActuel = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, state.currentBuilding) : {};
  if (etatActuel?.blocus) {
    showToast('Déjà bloqué', 'Un blocus est déjà en cours ici.', false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.78rem;color:#8a8060;margin-bottom:.6rem">Militants disponibles : ' + militants.length + '. Plus vous en mobilisez, plus le blocus a de chances de réussir et sera intense.</div>';
  html += '<input id="blocus-nb-militants" type="number" min="2" max="' + militants.length + '" value="' + militants.length + '" style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.85rem;margin-bottom:.6rem" />';
  html += '<div style="font-family:Bebas Neue,sans-serif;font-size:.7rem;letter-spacing:.1em;color:#8a6a20;margin-bottom:.4rem">REVENDICATION SYNDICALE</div>';
  html += '<textarea id="blocus-revendication" rows="2" placeholder="Ex: Contre la précarité des travailleurs du bâtiment..." style="width:100%;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.5rem;font-size:.82rem;box-sizing:border-box"></textarea>';
  html += '<button class="pnj-action-btn" onclick="confirmerOrganiserBlocus(\\'' + syndicat.id + '\\')" style="margin-top:.6rem">Organiser le blocus</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Organiser un blocus';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function confirmerOrganiserBlocus(syndicatId) {
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
  }

  const patch = {
    blocus: {
      syndicatId: syndicatId,
      syndicatNom: syndicat?.nom || 'Syndicat',
      revendication: revendication,
      nbMilitants: nbMilitants,
      intensite: intensite,
      leaderActuel: state.char?.name,
      lanceLe: Date.now(),
      dernierRenouvellementJour: state.day || 1
    }
  };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, state.currentBuilding, patch).catch(() => {});

  updateUI();
  showToast('Blocus organisé !', 'Le bâtiment est maintenant bloqué. Renouvelez chaque jour pour le maintenir.', true, true);
  addJournalEntry('Blocus syndical organisé (' + nbMilitants + ' militants) : "' + revendication + '"', 'event-good');
  if (typeof addExternalEvent === 'function') {
    addExternalEvent('✊ Un blocus syndical a été organisé dans un bâtiment de la ville : "' + revendication + '"', 'local');
  }
}

async function doRenouvelerBlocusSyndical() {
  const infos = getMonSyndicatEtGrade();
  if (!infos || infos.gradeIdx < 1 || infos.gradeIdx > 2) {
    showToast('Accès refusé', "Réservé au Secrétaire Général et au Secrétaire Général Adjoint.", false);
    return;
  }
  const etatActuel = (typeof sbGetBatimentEtat === 'function') ? await sbGetBatimentEtat(state.country, state.currentCity, state.currentBuilding) : {};
  if (!etatActuel?.blocus) {
    showToast('Rien à renouveler', "Aucun blocus en cours ici.", false);
    return;
  }
  if (etatActuel.blocus.syndicatId !== infos.syndicat.id) {
    showToast('Impossible', "Ce blocus n'est pas celui de votre syndicat.", false);
    return;
  }

  const patch = { blocus: { ...etatActuel.blocus, dernierRenouvellementJour: state.day || 1, leaderActuel: state.char?.name } };
  if (typeof sbSetBatimentEtat === 'function') await sbSetBatimentEtat(state.country, state.currentCity, state.currentBuilding, patch).catch(() => {});

  showToast('Blocus renouvelé', 'Le blocus se poursuit pour au moins un jour de plus.', true);
  addJournalEntry('Blocus syndical renouvelé.', 'event-info');
}

// SE RENSEIGNER (halls de Centre d'Affaires / Centre Commercial / Travées du Centre Artisanal)"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Lancement et renouvellement du blocus syndical créés.")
