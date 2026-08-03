#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

# --- 1. Cache + recherche etendue aux vrais terrains ---
old_1 = """function enigme1RechercherArchivesNotariales(nomQuery) {
  const nomLower = (nomQuery || '').trim().toLowerCase();
  if (!nomLower) return { parcelles: [], successions: [] };

  const parcelles = ENIGME1_REGISTRE_PARCELLES.filter(function(p) {
    return p.parcelle.toLowerCase().indexOf(nomLower) !== -1 ||
      p.historique.some(function(h) { return h.toLowerCase().indexOf(nomLower) !== -1; });
  });
  const successions = ENIGME1_REGISTRE_SUCCESSIONS.filter(function(s) {
    return s.defunt.toLowerCase().indexOf(nomLower) !== -1;
  });
  return { parcelles: parcelles, successions: successions };
}

function doConsulterArchivesNotariales() {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Recherchez par nom de personne, ou par numéro de parcelle (ex : B-127).</div>';
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="notariales-recherche" type="text" placeholder="Nom ou parcelle..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="enigme1LancerRechercheNotariale()"><i class="ti ti-search" style="font-size:.85rem"></i> Rechercher</button>';
  html += '<div id="notariales-resultats" style="margin-top:.9rem"></div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Archives Notariales';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}"""

new_1 = """let ETAT_CIVIL_CACHE_TERRAINS = null;

async function enigme1ChargerHistoriqueTerrains() {
  if (ETAT_CIVIL_CACHE_TERRAINS) return ETAT_CIVIL_CACHE_TERRAINS;
  try {
    ETAT_CIVIL_CACHE_TERRAINS = (typeof sbGetToutHistoriqueTerrains === 'function') ? await sbGetToutHistoriqueTerrains(state.country) : [];
  } catch (e) {
    ETAT_CIVIL_CACHE_TERRAINS = [];
  }
  return ETAT_CIVIL_CACHE_TERRAINS;
}

function enigme1RechercherArchivesNotariales(nomQuery) {
  const nomLower = (nomQuery || '').trim().toLowerCase();
  if (!nomLower) return { parcelles: [], successions: [], terrainsReels: [] };

  const parcelles = ENIGME1_REGISTRE_PARCELLES.filter(function(p) {
    return p.parcelle.toLowerCase().indexOf(nomLower) !== -1 ||
      p.historique.some(function(h) { return h.toLowerCase().indexOf(nomLower) !== -1; });
  });
  const successions = ENIGME1_REGISTRE_SUCCESSIONS.filter(function(s) {
    return s.defunt.toLowerCase().indexOf(nomLower) !== -1;
  });

  // Terrains reels achetes par de vrais joueurs (historique permanent, distinct des
  // parcelles fictives de l'enigme).
  const idsVus = [];
  const terrainsReels = [];
  (ETAT_CIVIL_CACHE_TERRAINS || []).forEach(function(t) {
    if (idsVus.indexOf(t.building_id) !== -1) return;
    const nomBatiment = (typeof BUILDINGS !== 'undefined' && BUILDINGS[t.building_id]) ? (BUILDINGS[t.building_id].name || BUILDINGS[t.building_id].shortName || t.building_id) : t.building_id;
    const correspond = nomBatiment.toLowerCase().indexOf(nomLower) !== -1 ||
      t.building_id.toLowerCase().indexOf(nomLower) !== -1 ||
      t.proprietaire.toLowerCase().indexOf(nomLower) !== -1;
    if (correspond) {
      idsVus.push(t.building_id);
      terrainsReels.push({ buildingId: t.building_id, nom: nomBatiment });
    }
  });

  return { parcelles: parcelles, successions: successions, terrainsReels: terrainsReels };
}

function doConsulterArchivesNotariales() {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Recherchez par nom de personne, par numéro de parcelle (ex : B-127), ou par nom de terrain.</div>';
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="notariales-recherche" type="text" placeholder="Nom, parcelle ou terrain..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="enigme1LancerRechercheNotariale()"><i class="ti ti-search" style="font-size:.85rem"></i> Rechercher</button>';
  html += '<div id="notariales-resultats" style="margin-top:.9rem"></div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Archives Notariales';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');

  if (typeof enigme1ChargerHistoriqueTerrains === 'function') enigme1ChargerHistoriqueTerrains();
}"""

assert content.count(old_1) == 1, f"bloc 1 : trouvé {content.count(old_1)} fois (attendu 1)"
content = content.replace(old_1, new_1)

# --- 2. Afficher les resultats de terrains reels dans la liste ---
old_2 = """  const res = enigme1RechercherArchivesNotariales(query);
  if (res.parcelles.length === 0 && res.successions.length === 0) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Aucun résultat.</div>';
    return;
  }"""
new_2 = """  const res = enigme1RechercherArchivesNotariales(query);
  if (res.parcelles.length === 0 && res.successions.length === 0 && res.terrainsReels.length === 0) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Aucun résultat.</div>';
    return;
  }"""
assert content.count(old_2) == 1, f"bloc 2 : trouvé {content.count(old_2)} fois (attendu 1)"
content = content.replace(old_2, new_2)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Recherche des Archives Notariales étendue aux vrais terrains achetés par les joueurs.")
