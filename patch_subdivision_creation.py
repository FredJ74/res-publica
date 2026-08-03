#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function getValeurTotaleBien(ts) {"""
new = """// =====================
// SUBDIVISION DES COMMERCES PREMIUM / BUILDING
// =====================
const SURFACE_MIN_SUBDIVISION = { commerce_premium: 600, building: 300 };

function peutDiviser(ts) {
  return ts.niveau_construction === 'commerce_premium' || ts.niveau_construction === 'building';
}

async function doOuvrirDivisionTerrain() {
  const id = state.currentBuilding;
  await chargerTerrainState(id);
  const ts = getTerrainState(id);

  if (ts.proprietaire !== state.char?.name) {
    showToast('Accès refusé', "Vous n'êtes pas propriétaire de ce terrain.", false);
    return;
  }
  if (!peutDiviser(ts)) {
    showToast('Impossible', 'Seuls les Commerces Premium et les Buildings peuvent être divisés.', false);
    return;
  }

  const surfaceMin = SURFACE_MIN_SUBDIVISION[ts.niveau_construction];
  const subdivisions = ts.subdivisions || [];
  const surfaceUtilisee = subdivisions.reduce(function(s, l) { return s + l.surface; }, 0);
  const surfaceRestante = (ts.surface || 0) - surfaceUtilisee;

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.8rem;color:#8a8060;margin-bottom:.8rem">Surface totale : ' + (ts.surface || 0) + ' m² · Surface restante à diviser : ' + surfaceRestante + ' m² · Minimum par lot : ' + surfaceMin + ' m².</div>';

  if (subdivisions.length > 0) {
    html += '<div style="display:flex;flex-direction:column;gap:.3rem;margin-bottom:.8rem">';
    subdivisions.forEach(function(l, i) {
      html += '<div style="padding:.5rem .6rem;border:1px solid #2a2010;background:#0f0d05;display:flex;justify-content:space-between;align-items:center">';
      html += '<span style="font-size:.82rem;color:#c0b090">' + l.label + ' — ' + l.surface + ' m²' + (l.locataire ? ' (loué par ' + l.locataire + ')' : ' (libre)') + '</span>';
      html += '<button onclick="doSupprimerSubdivision(' + i + ')" style="font-size:.68rem;color:#cc5540;background:transparent;border:none;cursor:pointer">Retirer</button>';
      html += '</div>';
    });
    html += '</div>';
  }

  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="subdiv-label" type="text" placeholder="Nom du lot..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="subdiv-surface" type="number" placeholder="Surface m²..." style="width:130px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doAjouterSubdivision()">+ Ajouter ce lot</button>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Diviser le bâtiment';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

async function doAjouterSubdivision() {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const surfaceMin = SURFACE_MIN_SUBDIVISION[ts.niveau_construction];
  const label = (document.getElementById('subdiv-label')?.value || '').trim();
  const surface = parseInt(document.getElementById('subdiv-surface')?.value || 0);

  if (!label) { showToast('Nom manquant', 'Donnez un nom à ce lot.', false); return; }
  if (!surface || surface < surfaceMin) { showToast('Surface trop petite', 'Chaque lot doit faire au moins ' + surfaceMin + ' m².', false); return; }

  const subdivisions = ts.subdivisions || [];
  const surfaceUtilisee = subdivisions.reduce(function(s, l) { return s + l.surface; }, 0);
  if (surfaceUtilisee + surface > (ts.surface || 0)) {
    showToast('Surface insuffisante', 'Il ne reste que ' + ((ts.surface || 0) - surfaceUtilisee) + ' m² disponibles.', false);
    return;
  }

  subdivisions.push({ id: 'lot-' + Date.now(), label: label, surface: surface, locataire: null, loyer: null });
  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});

  showToast('Lot ajouté', label + ' (' + surface + ' m²) créé.', true);
  doOuvrirDivisionTerrain();
}

async function doSupprimerSubdivision(idx) {
  const id = state.currentBuilding;
  const ts = getTerrainState(id);
  const subdivisions = ts.subdivisions || [];
  const lot = subdivisions[idx];
  if (!lot) return;

  if (lot.locataire) {
    const indemnite = (lot.loyer || 0) * 365;
    if (state.arg < indemnite) {
      showToast('Fonds insuffisants', "L'indemnité d'éviction (1 an de loyer, " + indemnite.toLocaleString('fr-FR') + " FR) doit être payée pour retirer ce lot.", false);
      return;
    }
    state.arg -= indemnite;
    if (typeof sbGet === 'function' && typeof sbUpdate === 'function') {
      const rows = await sbGet('personnages', `name=eq.${encodeURIComponent(lot.locataire)}`).catch(function() { return null; });
      const locPerso = rows && rows[0];
      if (locPerso) {
        await sbUpdate('personnages', `name=eq.${encodeURIComponent(lot.locataire)}`, { arg: (locPerso.arg || 0) + indemnite }).catch(function() {});
      }
    }
    if (typeof sendMail === 'function') {
      await sendMail(lot.locataire, "Éviction — indemnité versée", "Le propriétaire a repris le lot « " + lot.label + " ». Une indemnité d'éviction d'un an de loyer (" + indemnite.toLocaleString('fr-FR') + " FR) vous a été versée.");
    }
    showToast('Indemnité versée', indemnite.toLocaleString('fr-FR') + ' FR versés à ' + lot.locataire + '.', true);
  }

  subdivisions.splice(idx, 1);
  const nouvelEtat = setTerrainState(id, { subdivisions: subdivisions });
  if (typeof sbSetTerrainState === 'function') await sbSetTerrainState(state.country, id, nouvelEtat).catch(function() {});
  doOuvrirDivisionTerrain();
}

function getValeurTotaleBien(ts) {"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Système de division créé : ajout/retrait de lots, indemnité d'éviction (1 an de loyer).")
