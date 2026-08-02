#!/usr/bin/env python3
PATH = "plateau-enigme-portrait.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """const ENIGME1_MANDAT_TORCIEU = [
  "Évacuation par la force de l'université de Luthécia bloquée par le syndicat étudiant — 11 septembre 1937.",
  "Accord du permis de construire le Tabernacle des Impôts sur la parcelle A-095 — 9 juin 1943.",
  "Vente de la parcelle communale B-231, de type bois, d'une surface de 1ha78, pour la somme de 39 580 FR.",
  "Expropriation de M. Pierre Thibault de la parcelle agricole B-127, d'une surface de 2ha10, pour la somme de 18 000 FR — 14 mars 1947.",
  "Passage de la parcelle B-127 de terrain agricole non constructible à terrain à bâtir en zone industrielle — 20 octobre 1947.",
  "Revente de la parcelle B-127 pour 18 500 FR à l'entrepreneur Jacques Moulin — 6 janvier 1948.",
  "Rénovation de l'Hôtel de Ville lancée le 28 novembre 1948, pour 275 000 FR.",
  "Modernisation du stade de football le 8 août 1951, pour 198 000 FR."
];

// Coche une case du dossier de l'enigme (une seule fois). Etat stocke sur
// state.char.enigme1.dossier = { mairie, commissariat, notaire, presse, ehpad_dubois,
// ehpad_chevillard, ehpad_chauchay }.
function enigme1DossierCocherCase(cle) {
  if (typeof state === 'undefined' || !state.char || !state.char.enigme1) return;
  if (!state.char.enigme1.dossier) state.char.enigme1.dossier = {};
  if (state.char.enigme1.dossier[cle]) return;
  state.char.enigme1.dossier[cle] = true;
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  if (typeof showToast === 'function') showToast('Dossier mis à jour', 'Un élément de plus dans votre enquête.', true);
}

function doConsulterResumesMandats() {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Résumés des mandats successifs des maires de Luthécia.</div>';
  html += '<div onclick="enigme1AfficherMandatTorcieu()" style="cursor:pointer;padding:.5rem .6rem;border:1px solid #2a2010;font-size:.88rem;color:#c0b090">Marcel Torcieu <span style="color:#8a8060;font-size:.8rem">(1935–1958)</span></div>';
  html += '</div>';
  document.getElementById('postes-modal-title').textContent = 'Résumés de mandats';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enigme1AfficherMandatTorcieu() {
  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.2rem">Marcel Torcieu — Maire de Luthécia (1935–1958)</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Recensement des grands chantiers et actes majeurs de son mandat :</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  ENIGME1_MANDAT_TORCIEU.forEach(function(ligne) {
    html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.4">• ' + ligne + '</div>';
  });
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doConsulterResumesMandats()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Retour</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('mairie');
}"""

new = """// Registre extensible des mandats des maires de Luthecia. D'autres maires (avec leurs
// propres actes) pourront etre ajoutes ici plus tard, sans changer le systeme de recherche.
const ENIGME1_REGISTRE_MANDATS = [
  {
    nom: 'Marcel Torcieu',
    debut: 1935,
    fin: 1958,
    actes: [
      "Évacuation par la force de l'université de Luthécia bloquée par le syndicat étudiant — 11 septembre 1937.",
      "Accord du permis de construire le Tabernacle des Impôts sur la parcelle A-095 — 9 juin 1943.",
      "Vente de la parcelle communale B-231, de type bois, d'une surface de 1ha78, pour la somme de 39 580 FR.",
      "Expropriation de M. Pierre Thibault de la parcelle agricole B-127, d'une surface de 2ha10, pour la somme de 18 000 FR — 14 mars 1947.",
      "Passage de la parcelle B-127 de terrain agricole non constructible à terrain à bâtir en zone industrielle — 20 octobre 1947.",
      "Revente de la parcelle B-127 pour 18 500 FR à l'entrepreneur Jacques Moulin — 6 janvier 1948.",
      "Rénovation de l'Hôtel de Ville lancée le 28 novembre 1948, pour 275 000 FR.",
      "Modernisation du stade de football le 8 août 1951, pour 198 000 FR."
    ]
  }
];

// Coche une case du dossier de l'enigme (une seule fois). Etat stocke sur
// state.char.enigme1.dossier = { mairie, commissariat, notaire, presse, ehpad_dubois,
// ehpad_chevillard, ehpad_chauchay }.
function enigme1DossierCocherCase(cle) {
  if (typeof state === 'undefined' || !state.char || !state.char.enigme1) return;
  if (!state.char.enigme1.dossier) state.char.enigme1.dossier = {};
  if (state.char.enigme1.dossier[cle]) return;
  state.char.enigme1.dossier[cle] = true;
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
  if (typeof showToast === 'function') showToast('Dossier mis à jour', 'Un élément de plus dans votre enquête.', true);
}

// Recherche par nom (sous-chaine) et/ou par decennie (le mandat doit chevaucher la decennie).
function enigme1RechercherMandats(nomQuery, decennieDebut) {
  const nomLower = (nomQuery || '').trim().toLowerCase();
  const decDebut = decennieDebut ? parseInt(decennieDebut, 10) : null;
  const decFin = decDebut !== null ? decDebut + 9 : null;

  return ENIGME1_REGISTRE_MANDATS.filter(function(m) {
    if (nomLower && m.nom.toLowerCase().indexOf(nomLower) === -1) return false;
    if (decDebut !== null) {
      const chevauche = m.fin >= decDebut && m.debut <= decFin;
      if (!chevauche) return false;
    }
    return true;
  }).map(function(m) { return m.nom; });
}

function doConsulterResumesMandats() {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Recherchez par nom, par décennie (ex : 1940), ou les deux à la fois.</div>';
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="mandats-nom" type="text" placeholder="Nom..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="mandats-decennie" type="text" placeholder="Décennie (ex: 1940)" style="width:150px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="enigme1LancerRechercheMandats()"><i class="ti ti-search" style="font-size:.85rem"></i> Rechercher</button>';
  html += '<div id="mandats-resultats" style="margin-top:.9rem"></div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Résumés de mandats';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enigme1LancerRechercheMandats() {
  const nomInput = document.getElementById('mandats-nom');
  const decennieInput = document.getElementById('mandats-decennie');
  const nom = nomInput ? nomInput.value : '';
  const decennie = decennieInput ? decennieInput.value : '';

  const resultatsEl = document.getElementById('mandats-resultats');
  if (!resultatsEl) return;

  if (!nom.trim() && !decennie.trim()) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Indiquez au moins un nom ou une décennie.</div>';
    return;
  }

  const resultats = enigme1RechercherMandats(nom, decennie);
  if (resultats.length === 0) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Aucun résultat.</div>';
    return;
  }

  let html = '<div style="font-size:.8rem;color:#c0b090;margin-bottom:.4rem">' + resultats.length + ' résultat(s) :</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.3rem">';
  resultats.forEach(function(nomMaire) {
    const nomEchap = nomMaire.replace(/'/g, "\\'");
    html += '<div onclick="enigme1AfficherMandat(\\'' + nomEchap + '\\')" style="cursor:pointer;padding:.4rem .6rem;border:1px solid #2a2010;font-size:.85rem;color:#c0b090">' + nomMaire + '</div>';
  });
  html += '</div>';
  resultatsEl.innerHTML = html;
}

function enigme1AfficherMandat(nomMaire) {
  const m = ENIGME1_REGISTRE_MANDATS.find(function(x) { return x.nom === nomMaire; });
  if (!m) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.2rem">' + m.nom + ' — Maire de Luthécia (' + m.debut + '–' + m.fin + ')</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Recensement des grands chantiers et actes majeurs de son mandat :</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  m.actes.forEach(function(ligne) {
    html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.4">• ' + ligne + '</div>';
  });
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="doConsulterResumesMandats()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Nouvelle recherche</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (m.nom === 'Marcel Torcieu' && typeof enigme1DossierCocherCase === 'function') {
    enigme1DossierCocherCase('mairie');
  }
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Résumés de mandats transformés en recherche par nom/décennie, registre extensible.")
