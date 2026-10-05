#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function getValeurTotaleBien(ts) {"""
new = """// =====================
// LOCATION D'UN LOT (visiteur) + GESTION DU LOCATAIRE
// =====================

async function doOuvrirLouerLot() {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (ts.proprietaire === state.char?.name) {
    showToast('Impossible', "Vous êtes déjà propriétaire de ce terrain — utilisez « Diviser / gérer les lots ».", false);
    return;
  }
  const lotsLibres = subdivisions.filter(function(l) { return !l.locataire; });
  if (lotsLibres.length === 0) {
    showToast('Aucun lot disponible', "Ce terrain n'a pas (encore) été divisé, ou tous les lots sont déjà loués.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  lotsLibres.forEach(function(l) {
    html += '<div onclick="doLouerCeLot(\\'' + l.id + '\\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-size:.85rem;color:#c0b090">' + l.label + '</span> — ' + l.surface + ' m² — <span style="color:#4a9a6a">' + l.loyer + ' ' + cur + '/jour</span>';
    html += '</div>';
  });
  html += '</div></div>';

  document.getElementById('postes-modal-title').textContent = 'Louer un lot';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doLouerCeLot(lotId) {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lot = subdivisions.find(function(l) { return l.id === lotId; });
  if (!lot || lot.locataire) { showToast('Indisponible', 'Ce lot vient d\\'être loué par quelqu\\'un d\\'autre.', false); return; }

  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < lot.loyer) {
    showToast('Fonds insuffisants', lot.loyer + ' ' + cur + ' requis pour le premier loyer.', false);
    return;
  }

  state.arg -= lot.loyer;
  lot.locataire = state.char?.name;

  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Bail signé !', lot.label + ' loué. -' + lot.loyer + ' ' + cur + '/jour.', true, true);
  addJournalEntry('Location signée : ' + lot.label + ' (' + (BUILDINGS[id]?.shortName || id) + '). -' + lot.loyer + ' ' + cur + '/jour.', 'event-good');
}

async function doGererLotLoue() {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  const mesLots = subdivisions
    .map(function(l, i) { return { l: l, i: i }; })
    .filter(function(x) { return x.l.locataire === state.char?.name; });

  if (mesLots.length === 0) {
    showToast('Aucun local', "Vous ne louez aucun lot sur ce terrain.", false);
    return;
  }

  let html = '<div style="padding:1rem">';
  mesLots.forEach(function(x) {
    html += '<div style="padding:.6rem;border:1px solid #2a2010;background:#0f0d05;margin-bottom:.5rem">';
    html += '<div style="font-size:.85rem;color:#c0b090">' + x.l.label + ' — ' + x.l.surface + ' m² — ' + x.l.loyer + ' ' + cur + '/jour</div>';
    if (x.l.propositionAgrandissement) {
      html += '<div style="margin-top:.5rem;font-size:.8rem;color:#e0d8c0">Le propriétaire propose d\\'agrandir ce local de ' + x.l.propositionAgrandissement.surfaceAjoutee + ' m² (' + x.l.propositionAgrandissement.labelVide + '), sans changement de loyer.</div>';
      html += '<div style="display:flex;gap:.5rem;margin-top:.4rem">';
      html += '<button onclick="doAccepterFusionLot(' + x.i + ')" style="font-size:.75rem;color:#4a9a6a;background:transparent;border:1px solid #4a9a6a;padding:.3rem .6rem;cursor:pointer">Accepter</button>';
      html += '<button onclick="doRefuserFusionLot(' + x.i + ')" style="font-size:.75rem;color:#cc5540;background:transparent;border:1px solid #cc5540;padding:.3rem .6rem;cursor:pointer">Refuser</button>';
      html += '</div>';
    }
    html += '</div>';
  });
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Mon local loué';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function getValeurTotaleBien(ts) {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Location d'un lot + gestion du locataire (dont acceptation/refus d'agrandissement) créées.")
