#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  document.getElementById('postes-body').innerHTML = html;
}

function getValeurTotaleBien(ts) {"""

new = """  document.getElementById('postes-body').innerHTML = html;
}

// L'agrandissement necessite le consentement du locataire concerne : le proprietaire
// propose, le locataire accepte ou refuse (voir doAccepterFusionLot/doRefuserFusionLot,
// consultables via 'Gérer mon local loué').
async function doFusionnerLot(idxOccupe, idxVide) {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lotOccupe = subdivisions[idxOccupe];
  const lotVide = subdivisions[idxVide];
  if (!lotOccupe || !lotVide || lotVide.locataire) return;

  lotOccupe.propositionAgrandissement = { idxVide: idxVide, surfaceAjoutee: lotVide.surface, labelVide: lotVide.label };
  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  if (typeof sendMail === 'function') {
    await sendMail(lotOccupe.locataire, "Proposition d'agrandissement — " + lotOccupe.label,
      "Le propriétaire vous propose d'agrandir votre local « " + lotOccupe.label + " » de " + lotVide.surface + " m² (" + lotVide.label + "), sans changement de loyer. Rendez-vous sur place, rubrique « Gérer mon local loué », pour accepter ou refuser.");
  }

  showToast('Proposition envoyée', lotOccupe.locataire + ' doit accepter avant que la fusion ne soit effective.', true);
  doOuvrirDivisionTerrain();
}

async function doAccepterFusionLot(idxOccupe) {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lotOccupe = subdivisions[idxOccupe];
  const prop = lotOccupe && lotOccupe.propositionAgrandissement;
  if (!prop) return;

  lotOccupe.surface += prop.surfaceAjoutee;
  delete lotOccupe.propositionAgrandissement;
  subdivisions.splice(prop.idxVide, 1);

  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  showToast('Agrandissement accepté', lotOccupe.label + ' fait désormais ' + lotOccupe.surface + ' m².', true);
  if (typeof addJournalEntry === 'function') addJournalEntry('Vous avez accepté l\\'agrandissement de ' + lotOccupe.label + '.', 'event-good');
}

async function doRefuserFusionLot(idxOccupe) {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lotOccupe = subdivisions[idxOccupe];
  if (!lotOccupe || !lotOccupe.propositionAgrandissement) return;

  delete lotOccupe.propositionAgrandissement;
  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  showToast('Proposition refusée', "L'agrandissement n'aura pas lieu.", false);
}

function getValeurTotaleBien(ts) {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Consentement du locataire ajouté : proposition, acceptation ou refus.")
