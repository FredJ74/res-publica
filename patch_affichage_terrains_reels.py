#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """  res.successions.forEach(function(s) {
    const nomEchap = s.defunt.replace(/'/g, "\\'");
    html += '<div onclick="enigme1AfficherSuccession(\\'' + nomEchap + '\\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">Succession — ' + s.defunt + '</span>';
    html += '</div>';
  });
  html += '</div>';
  resultatsEl.innerHTML = html;
}"""

new = """  res.successions.forEach(function(s) {
    const nomEchap = s.defunt.replace(/'/g, "\\'");
    html += '<div onclick="enigme1AfficherSuccession(\\'' + nomEchap + '\\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">Succession — ' + s.defunt + '</span>';
    html += '</div>';
  });
  res.terrainsReels.forEach(function(t) {
    html += '<div onclick="enigme1AfficherTerrainReel(\\'' + t.buildingId + '\\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">' + t.nom + '</span>';
    html += '</div>';
  });
  html += '</div>';
  resultatsEl.innerHTML = html;
}

function enigme1AfficherTerrainReel(buildingId) {
  const historique = (ETAT_CIVIL_CACHE_TERRAINS || []).filter(function(t) { return t.building_id === buildingId; });
  const nomBatiment = (typeof BUILDINGS !== 'undefined' && BUILDINGS[buildingId]) ? (BUILDINGS[buildingId].name || BUILDINGS[buildingId].shortName || buildingId) : buildingId;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.6rem">Historique — ' + nomBatiment + '</div>';
  if (historique.length === 0) {
    html += '<div style="font-size:.85rem;color:#5a5040;font-style:italic">Aucune vente enregistrée.</div>';
  } else {
    html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
    historique.forEach(function(t) {
      const d = t.created_at ? new Date(t.created_at) : null;
      const dateTxt = d ? (d.getDate() + ' ' + ETAT_CIVIL_MOIS[d.getMonth()] + ' ' + d.getFullYear()) : '?';
      const prixTxt = t.prix ? (' pour ' + t.prix.toLocaleString('fr-FR') + ' FR') : '';
      html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.4">• ' + dateTxt + ' : acquis par ' + t.proprietaire + prixTxt + '.</div>';
    });
    html += '</div>';
  }
  html += '<button class="pnj-action-btn" onclick="doConsulterArchivesNotariales()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Nouvelle recherche</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Affichage et fiche de détail des vrais terrains ajoutés aux Archives Notariales.")
