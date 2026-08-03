#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """function enigme1AfficherPopupCadreVide(roomId) {"""
new = """// =====================
// ARCHIVES NOTARIALES — historique des parcelles + successions
// Registres extensibles, comme pour l'etat-civil et les mandats. Recherche par nom
// (personne ou parcelle), retrouve aussi bien un historique de propriete qu'une succession.
// =====================

const ENIGME1_REGISTRE_PARCELLES = [
  {
    parcelle: 'B-127',
    historique: [
      "Jusqu'en 1947 : propriété de Pierre Thibault (terrain agricole, 2ha10).",
      "1947 : expropriée par la Mairie de Luthécia (voir résumé du mandat de Marcel Torcieu).",
      "1948 : revendue à l'entrepreneur Jacques Moulin, reclassée terrain à bâtir en zone industrielle."
    ]
  }
];

const ENIGME1_REGISTRE_SUCCESSIONS = [
  {
    defunt: 'Pierre Thibault',
    annee: 1949,
    texte: "Succession de Pierre Thibault, décédé en 1949. La succession fait mention d'un coffre loué à la Banque Nationale de Républia, dont la location demeure active à ce jour."
  }
];

function enigme1RechercherArchivesNotariales(nomQuery) {
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
}

function enigme1LancerRechercheNotariale() {
  const input = document.getElementById('notariales-recherche');
  const query = input ? input.value : '';
  const resultatsEl = document.getElementById('notariales-resultats');
  if (!resultatsEl) return;

  if (!query.trim()) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Indiquez un nom ou une parcelle.</div>';
    return;
  }

  const res = enigme1RechercherArchivesNotariales(query);
  if (res.parcelles.length === 0 && res.successions.length === 0) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Aucun résultat.</div>';
    return;
  }

  let html = '<div style="display:flex;flex-direction:column;gap:.4rem">';
  res.parcelles.forEach(function(p) {
    html += '<div onclick="enigme1AfficherParcelle(\\'' + p.parcelle + '\\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">Parcelle ' + p.parcelle + '</span>';
    html += '</div>';
  });
  res.successions.forEach(function(s) {
    const nomEchap = s.defunt.replace(/'/g, "\\'");
    html += '<div onclick="enigme1AfficherSuccession(\\'' + nomEchap + '\\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">Succession — ' + s.defunt + '</span>';
    html += '</div>';
  });
  html += '</div>';
  resultatsEl.innerHTML = html;
}

function enigme1AfficherParcelle(parcelle) {
  const p = ENIGME1_REGISTRE_PARCELLES.find(function(x) { return x.parcelle === parcelle; });
  if (!p) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.6rem">Historique de la parcelle ' + p.parcelle + '</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  p.historique.forEach(function(ligne) {
    html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.4">• ' + ligne + '</div>';
  });
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doConsulterArchivesNotariales()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Nouvelle recherche</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('notaire');
}

function enigme1AfficherSuccession(defunt) {
  const s = ENIGME1_REGISTRE_SUCCESSIONS.find(function(x) { return x.defunt === defunt; });
  if (!s) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.2rem">Succession — ' + s.defunt + '</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">' + s.annee + '</div>';
  html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.5">' + s.texte + '</div>';
  html += '<button class="pnj-action-btn" onclick="doConsulterArchivesNotariales()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Nouvelle recherche</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('notaire');
}

function enigme1AfficherPopupCadreVide(roomId) {"""
assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Archives Notariales créées : recherche par nom/parcelle, historique de B-127, succession Thibault.")
