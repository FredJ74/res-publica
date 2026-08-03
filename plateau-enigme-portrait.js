// plateau-enigme-portrait.js
// Enigme freemium n°1 de Luthecia — Le Portrait Disparu.
// Etat sauvegarde sur le personnage : state.char.enigme1 = { etape, variante, dateDeclenchement }
//
// Etapes :
//   (absent / non_commencee) -> pas encore declenchee (personnage cree il y a moins de 3 jours)
//   declenchee               -> le mystere a ete annonce dans le journal, le joueur peut aller au musee
//   relancee                 -> relance unique a J+6 si le joueur n'a toujours rien fait
//   (suite a coder : resolution de l'enquete)

const ENIGME1_VARIANTES = ['maire', 'criminel', 'entrepreneur', 'plume'];

const ENIGME1_RUMEURS = {
  maire:        "Une rumeur circule en ville : il paraît qu'on chuchote des choses étranges sur d'anciens édiles, à la mairie...",
  criminel:     "Une rumeur circule en ville : un vieux fait divers refait surface, à ce qu'on raconte...",
  entrepreneur: "Une rumeur circule en ville : des rumeurs circulent sur les grandes fortunes d'autrefois...",
  plume:        "Une rumeur circule en ville : on dit que certains articles de presse cachaient bien des choses, jadis..."
};

// Une fois l'enigme declenchee (et tant qu'elle n'est pas resolue), les 4 salles du musee de
// la ville affichent un cadre vide — quel que soit le tirage de variante du joueur (qui ne
// sert qu'a varier le texte de la rumeur ci-dessus).
const ENIGME1_SALLES_CADRE_VIDE = {
  salle_maires: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-maires-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-torcieu-maire.png',
    personnage: 'Marcel Torcieu',
    dates: '1895–1958',
    texteAccroche: "Étrange qu'un portrait manque justement ici... Les archives de la Mairie permettraient sans doute d'en apprendre davantage sur cet homme."
  },
  salle_criminels: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-criminels-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-caillon-criminel.png',
    personnage: 'Maurice Caillon',
    dates: '1901–1954',
    texteAccroche: "Étrange qu'un portrait manque justement ici... Le Commissariat permettrait sans doute d'en apprendre davantage sur cet homme."
  },
  salle_entrepreneurs: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-entrepreneurs-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-moulin-entrepreneur.png',
    personnage: 'Jacques Moulin',
    dates: '1897–1965',
    texteAccroche: "Étrange qu'un portrait manque justement ici... L'Étude Notariale permettrait sans doute d'en apprendre davantage sur cet homme."
  },
  salle_plumes: {
    imageUrl: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/salle-plumes-cadre-vide-luthecia.png',
    imageGrosPlan: 'https://raw.githubusercontent.com/FredJ74/res-publica/main/images/cadre-vide-tintabin-plume.png',
    personnage: 'Étienne Tintabin',
    dates: '1898–1969',
    texteAccroche: "Étrange qu'un portrait manque justement ici... L'Imprimerie L'Autruche Entravée permettrait sans doute d'en apprendre davantage sur cet homme."
  }
};

// L'enigme est "active" (cadres vides visibles) tant qu'elle a ete declenchee et n'est pas
// encore marquee comme resolue (etape future, non geree ici).
function enigme1EtapeActive() {
  return typeof state !== 'undefined' && state.char && state.char.enigme1 &&
    (state.char.enigme1.etape === 'declenchee' || state.char.enigme1.etape === 'relancee');
}

// Renvoie l'image "cadre vide" a afficher pour cette piece, ou null si non concernee.
// Appelee depuis la chaine de priorite d'image dans enterRoom (plateau-navigation.js).
function enigme1ImageSalleVide(buildingId, roomId) {
  if (buildingId !== 'musee-ville-luthecia') return null;
  if (!enigme1EtapeActive()) return null;
  const info = ENIGME1_SALLES_CADRE_VIDE[roomId];
  return info ? info.imageUrl : null;
}

// Injecte (ou retire) une zone cliquable generreuse sur la bande des portraits, permettant
// d'examiner le cadre vide. Appelee juste apres l'affichage de l'image de la piece.
function enigme1InjecterZoneCliquable(buildingId, roomId) {
  const pieceImg = document.getElementById('piece-image');
  if (!pieceImg) return;
  pieceImg.querySelectorAll('.enigme1-zone-cadre').forEach(function(el) { el.remove(); });

  if (buildingId !== 'musee-ville-luthecia') return;
  if (!enigme1EtapeActive()) return;
  const info = ENIGME1_SALLES_CADRE_VIDE[roomId];
  if (!info) return;

  pieceImg.style.position = pieceImg.style.position || 'relative';
  const div = document.createElement('div');
  div.className = 'enigme1-zone-cadre';
  div.style.cssText = 'position:absolute;left:0;right:0;top:25%;height:45%;cursor:pointer;';
  div.title = 'Examiner les portraits';
  div.onclick = function() { enigme1AfficherPopupCadreVide(roomId); };
  pieceImg.appendChild(div);
}

// Affiche la pop-up du cadre vide (reutilise le modal generique #modal-postes).
// =====================
// SALLE DES ARCHIVES (MAIRIE) — resume du mandat de Torcieu
// =====================

// Registre extensible des mandats des maires de Luthecia. D'autres maires (avec leurs
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
    const nomEchap = nomMaire.replace(/'/g, "\'");
    html += '<div onclick="enigme1AfficherMandat(\'' + nomEchap + '\')" style="cursor:pointer;padding:.4rem .6rem;border:1px solid #2a2010;font-size:.85rem;color:#c0b090">' + nomMaire + '</div>';
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
}

// =====================
// ARCHIVES NOTARIALES — historique des parcelles + successions
// Registres extensibles, comme pour l'etat-civil et les mandats. Recherche par nom
// (personne ou parcelle), retrouve aussi bien un historique de propriete qu'une succession.
// =====================

const ENIGME1_REGISTRE_PARCELLES = [
  {
    parcelle: 'B-127',
    historique: [
      "Jusqu'en 1947 : propriété de Pierre Thibault, qui y cultivait des pommes de terre (terrain agricole, 2ha10).",
      "1947 : expropriée par la Mairie de Luthécia (voir résumé du mandat de Marcel Torcieu).",
      "1948 : revendue à l'entrepreneur Jacques Moulin, reclassée terrain à bâtir en zone industrielle.",
      "Suite à l'arrêt de l'usine, la parcelle a été rachetée pour l'aménagement du Centre Multimodal (aéroport)."
    ]
  },
  {
    parcelle: 'A-095',
    historique: [
      "1943 : permis de construire accordé par la Mairie de Luthécia pour le Tabernacle des Impôts (voir résumé du mandat de Marcel Torcieu)."
    ]
  },
  {
    parcelle: 'B-231',
    historique: [
      "Ancienne parcelle communale de type bois, d'une surface de 1ha78.",
      "Vendue par la Mairie de Luthécia pour la somme de 39 580 FR (voir résumé du mandat de Marcel Torcieu)."
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
    html += '<div onclick="enigme1AfficherParcelle(\'' + p.parcelle + '\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<span style="font-family:Playfair Display,serif;font-size:.82rem;color:#c0b090">Parcelle ' + p.parcelle + '</span>';
    html += '</div>';
  });
  res.successions.forEach(function(s) {
    const nomEchap = s.defunt.replace(/'/g, "\'");
    html += '<div onclick="enigme1AfficherSuccession(\'' + nomEchap + '\')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
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

// =====================
// ARCHIVES DE PRESSE (L'AUTRUCHE ENTRAVEE) — articles d'Etienne Tintabin
// =====================

const ENIGME1_ARCHIVES_PRESSE = [
  {
    titre: "Un nouvel élan industriel pour Luthécia",
    auteur: 'Étienne Tintabin',
    annee: 1948,
    texte: "L'installation de la nouvelle usine de M. Jacques Moulin sur d'anciens terrains agricoles récemment aménagés, à l'est de la ville, marque un tournant pour l'emploi local. L'usine produira des frites surgelées, à partir de pommes de terre importées de Sovarka via le port industriel de Port-Sainte-Marie. Une trentaine de postes seront créés dès l'ouverture. Un beau succès pour le maire Marcel Torcieu, malgré l'opposition farouche du conseiller municipal Gaston Blanaz. Luthécia entre enfin dans l'ère moderne."
  },
  {
    titre: "L'affaire Caillon : un doute raisonnable ?",
    auteur: 'Étienne Tintabin',
    annee: 1949,
    texte: "Les éléments retenus contre M. Maurice Caillon, gardien du site industriel, apparaissent aujourd'hui bien minces. La victime, Gaston Blanaz, s'était fait de nombreux ennemis dans la commune — autant de suspects potentiels que M. Caillon. Rien ne prouve formellement sa présence sur les lieux au moment des faits. La justice, si elle veut rester juste, se doit d'examiner ce dossier avec la plus grande prudence."
  }
];

function doConsulterArchivesPresse() {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Articles archivés de L\'Autruche Entravée.</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.4rem">';
  ENIGME1_ARCHIVES_PRESSE.forEach(function(a, i) {
    html += '<div onclick="enigme1AfficherArticlePresse(' + i + ')" style="cursor:pointer;padding:.6rem;border:1px solid #2a2010;background:#0f0d05">';
    html += '<div style="display:flex;justify-content:space-between"><span style="font-family:Playfair Display,serif;font-size:.85rem;color:#c0b090">' + a.titre + '</span><span style="font-size:.7rem;color:#5a4030">' + a.annee + '</span></div>';
    html += '<div style="font-size:.72rem;color:#6a5a30">Par ' + a.auteur + '</div>';
    html += '</div>';
  });
  html += '</div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = "Archives de L'Autruche Entravée";
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function enigme1AfficherArticlePresse(idx) {
  const a = ENIGME1_ARCHIVES_PRESSE[idx];
  if (!a) return;

  let html = '<div style="padding:1.2rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Playfair Display,serif;font-style:italic;margin-bottom:.2rem">« ' + a.titre + ' »</div>';
  html += '<div style="font-size:.82rem;color:#8a8060;margin-bottom:.8rem">Par ' + a.auteur + ' — ' + a.annee + '</div>';
  html += '<div style="font-size:.85rem;color:#e0d8c0;line-height:1.6">' + a.texte + '</div>';
  html += '<button class="pnj-action-btn" onclick="doConsulterArchivesPresse()" style="margin-top:1rem;opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Retour</button>';
  html += '</div>';
  document.getElementById('postes-body').innerHTML = html;

  if (typeof enigme1DossierCocherCase === 'function') enigme1DossierCocherCase('presse');
}

function enigme1AfficherPopupCadreVide(roomId) {
  const info = ENIGME1_SALLES_CADRE_VIDE[roomId];
  if (!info) return;

  let html = '<div style="padding:1.2rem">';
  if (info.imageGrosPlan) {
    html += '<img src="' + info.imageGrosPlan + '" style="width:100%;border-radius:4px;margin-bottom:.9rem;display:block" />';
  }
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.05em;margin-bottom:.3rem">Un cadre vide</div>';
  html += '<div style="font-size:.9rem;color:#e0d8c0;margin-bottom:.5rem">Seule la plaque subsiste : <strong>' + info.personnage + '</strong> (' + info.dates + ').</div>';
  html += '<div style="font-size:.85rem;color:#8a8060;font-style:italic;line-height:1.5">' + info.texteAccroche + '</div>';
  html += '</div>';

  document.getElementById('postes-modal-title').textContent = 'Cadre vide';
  document.getElementById('postes-body').innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}
const ENIGME1_DELAI_DECLENCHEMENT_JOURS = 3;
const ENIGME1_DELAI_RELANCE_JOURS = 6; // 3 jours apres le declenchement

// Appelee a chaque synchronisation du personnage (hook dans plateau-core.js). Verifie si le
// delai est ecoule et declenche/relance le mystere du musee si besoin. Base sur la vraie date
// de creation du personnage (createdAt), pas sur un minuteur JS ni sur state.day (qui pourrait
// etre partage/different selon le contexte).
function enigme1VerifierDeclenchement() {
  if (typeof state === 'undefined' || !state.char || !state.char.createdAt) return;

  if (!state.char.enigme1) {
    state.char.enigme1 = { etape: 'non_commencee', variante: null };
  }
  const e = state.char.enigme1;

  const maintenant = Date.now();
  const creation = new Date(state.char.createdAt).getTime();
  const joursEcoules = (maintenant - creation) / (1000 * 60 * 60 * 24);

  if (e.etape === 'non_commencee' && joursEcoules >= ENIGME1_DELAI_DECLENCHEMENT_JOURS) {
    // Tirage aleatoire de la variante — fixe definitivement pour ce joueur. Ne change RIEN
    // aux salles affichees (les 4 sont toujours vides pour un joueur concerne) : sert
    // uniquement a varier le texte de la rumeur/du journal, pour alimenter les echanges
    // entre joueurs sans changer la mecanique de jeu.
    const variante = ENIGME1_VARIANTES[Math.floor(Math.random() * ENIGME1_VARIANTES.length)];
    state.char.enigme1 = { etape: 'declenchee', variante: variante, dateDeclenchement: new Date().toISOString() };
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof addJournalEntry === 'function') {
      const rumeur = ENIGME1_RUMEURS[variante] || ENIGME1_RUMEURS.maire;
      addJournalEntry(rumeur, 'event-secret');
    }
    return;
  }

  if (e.etape === 'declenchee' && joursEcoules >= ENIGME1_DELAI_RELANCE_JOURS) {
    state.char.enigme1.etape = 'relancee';
    if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(() => {});
    if (typeof addJournalEntry === 'function') {
      addJournalEntry("La rumeur persiste : le mystère du musée de la ville n'est toujours pas éclairci...", 'event-secret');
    }
  }
}
