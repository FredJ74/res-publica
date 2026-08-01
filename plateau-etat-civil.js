// plateau-etat-civil.js
// Registre d'etat-civil de Republia — consultable a la Salle des Archives de la Mairie.
// Sert d'abord a l'enigme du Portrait Disparu (genealogie Thibault/Poincon), et sera etendu
// plus tard comme annuaire officiel des PJ (naissance = creation du personnage, deces = depart).

const ETAT_CIVIL_REGISTRE = {
  republic: [
    { nom: 'Pierre Thibault',     naissanceAnnee: 1898, parents: [],                                  mariageAnnee: 1920, conjoint: 'Marie Ravichoux',   decesAnnee: 1949 },
    { nom: 'Marie Ravichoux',     naissanceAnnee: null, parents: [],                                  mariageAnnee: 1920, conjoint: 'Pierre Thibault',    decesAnnee: null },
    { nom: 'Élise Thibault',      naissanceAnnee: 1929, parents: ['Pierre Thibault', 'Marie Ravichoux'], mariageAnnee: 1950, conjoint: 'Bernard Poinçon', decesAnnee: 1991 },
    { nom: 'Bernard Poinçon',     naissanceAnnee: null, parents: [],                                  mariageAnnee: 1950, conjoint: 'Élise Thibault',     decesAnnee: null },
    { nom: 'Gérard Poinçon',      naissanceAnnee: 1960, parents: ['Bernard Poinçon', 'Élise Thibault'], mariageAnnee: null, conjoint: null,               decesAnnee: null },
    { nom: 'Marcel Torcieu',      naissanceAnnee: 1895, parents: [],                                  mariageAnnee: 1915, conjoint: 'Mathilde Bijoux',    decesAnnee: 1958 },
    { nom: 'Mathilde Bijoux',     naissanceAnnee: null, parents: [],                                  mariageAnnee: 1915, conjoint: 'Marcel Torcieu',     decesAnnee: null },
    { nom: 'Maurice Caillon',     naissanceAnnee: 1901, parents: [],                                  mariageAnnee: 1920, conjoint: 'Lucienne Balrasse',  decesAnnee: 1954 },
    { nom: 'Lucienne Balrasse',   naissanceAnnee: null, parents: [],                                  mariageAnnee: 1920, conjoint: 'Maurice Caillon',    decesAnnee: null },
    { nom: 'Jacques Moulin',      naissanceAnnee: 1897, parents: [],                                  mariageAnnee: 1923, conjoint: 'Raymonde Charcot',   decesAnnee: 1965 },
    { nom: 'Raymonde Charcot',    naissanceAnnee: null, parents: [],                                  mariageAnnee: 1923, conjoint: 'Jacques Moulin',     decesAnnee: null },
    { nom: 'Étienne Tintabin',    naissanceAnnee: 1898, parents: [],                                  mariageAnnee: 1921, conjoint: 'Ludivine Girard',    decesAnnee: 1969 },
    { nom: 'Ludivine Girard',     naissanceAnnee: null, parents: [],                                  mariageAnnee: 1921, conjoint: 'Étienne Tintabin',   decesAnnee: null }
  ]
};

// Construit la liste des evenements datables d'une personne : sa naissance, son mariage,
// la naissance de ses enfants (deduits du registre), et son deces. Tries par annee.
function etatCivilConstruireFiche(nomPersonne) {
  const registre = ETAT_CIVIL_REGISTRE[state.country] || [];
  const p = registre.find(function(x) { return x.nom === nomPersonne; });
  if (!p) return null;

  const evenements = [];

  if (p.naissanceAnnee) {
    const parentsTxt = (p.parents && p.parents.length === 2)
      ? ', fils/fille de ' + p.parents[0] + ' et ' + p.parents[1]
      : '';
    evenements.push({ annee: p.naissanceAnnee, texte: p.naissanceAnnee + ' : naissance de ' + p.nom + parentsTxt + '.' });
  }
  if (p.mariageAnnee && p.conjoint) {
    evenements.push({ annee: p.mariageAnnee, texte: p.mariageAnnee + ' : mariage de ' + p.nom + ' avec ' + p.conjoint + '.' });
  }
  // Enfants : toute personne du registre dont p.nom figure dans ses parents.
  registre.forEach(function(autre) {
    if (autre.parents && autre.parents.indexOf(p.nom) !== -1 && autre.naissanceAnnee) {
      const parentsEnfantTxt = autre.parents.join(' et ');
      evenements.push({ annee: autre.naissanceAnnee, texte: autre.naissanceAnnee + ' : naissance de ' + autre.nom + ', fils/fille de ' + parentsEnfantTxt + '.' });
    }
  });
  if (p.decesAnnee) {
    evenements.push({ annee: p.decesAnnee, texte: p.decesAnnee + ' : décès de ' + p.nom + '.' });
  }

  evenements.sort(function(a, b) { return a.annee - b.annee; });
  return { nom: p.nom, evenements: evenements };
}

// Recherche par nom (sous-chaine, insensible a la casse) et/ou par decennie (ex: 1940 pour
// 1940-1949). Retourne la liste des noms de personnes correspondantes, sans doublon.
function etatCivilRechercher(nomQuery, decennieDebut) {
  const registre = ETAT_CIVIL_REGISTRE[state.country] || [];
  const nomLower = (nomQuery || '').trim().toLowerCase();
  const decDebut = decennieDebut ? parseInt(decennieDebut, 10) : null;
  const decFin = decDebut !== null ? decDebut + 9 : null;

  const resultats = [];
  registre.forEach(function(p) {
    if (nomLower && p.nom.toLowerCase().indexOf(nomLower) === -1) return;

    if (decDebut !== null) {
      const fiche = etatCivilConstruireFiche(p.nom);
      const aUnEvenementDansLaDecennie = fiche && fiche.evenements.some(function(e) {
        return e.annee >= decDebut && e.annee <= decFin;
      });
      if (!aUnEvenementDansLaDecennie) return;
    }

    if (resultats.indexOf(p.nom) === -1) resultats.push(p.nom);
  });
  return resultats;
}

// =====================
// INTERFACE (reutilise le modal generique #modal-postes, comme l'organigramme des supporters)
// =====================

function doConsulterEtatCivil() {
  document.getElementById('postes-modal-title').textContent = "Registre d'État-Civil de Republia";
  document.getElementById('postes-body').innerHTML = etatCivilHtmlRecherche();
  document.getElementById('modal-postes').classList.add('open');
}

function etatCivilHtmlRecherche(messageErreur) {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">Recherchez par nom, par décennie (ex : 1940), ou les deux à la fois.</div>';
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="etat-civil-nom" type="text" placeholder="Nom..." style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="etat-civil-decennie" type="text" placeholder="Décennie (ex: 1940)" style="width:150px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="etatCivilLancerRecherche()"><i class="ti ti-search" style="font-size:.85rem"></i> Rechercher</button>';
  if (messageErreur) {
    html += '<div style="margin-top:.7rem;font-size:.8rem;color:#8a3a20;font-style:italic">' + messageErreur + '</div>';
  }
  html += '<div id="etat-civil-resultats" style="margin-top:.9rem"></div>';
  html += '</div>';
  return html;
}

function etatCivilLancerRecherche() {
  const nomInput = document.getElementById('etat-civil-nom');
  const decennieInput = document.getElementById('etat-civil-decennie');
  const nom = nomInput ? nomInput.value : '';
  const decennie = decennieInput ? decennieInput.value : '';

  const resultats = etatCivilRechercher(nom, decennie);
  const resultatsEl = document.getElementById('etat-civil-resultats');
  if (!resultatsEl) return;

  if (!nom.trim() && !decennie.trim()) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Indiquez au moins un nom ou une décennie.</div>';
    return;
  }
  if (resultats.length === 0) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">Aucun résultat.</div>';
    return;
  }

  let html = '<div style="font-size:.8rem;color:#c0b090;margin-bottom:.4rem">' + resultats.length + ' résultat(s) :</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.3rem">';
  resultats.forEach(function(nomPersonne) {
    const nomEchap = nomPersonne.replace(/'/g, "\\'");
    html += '<div onclick="etatCivilAfficherFiche(\'' + nomEchap + '\')" style="cursor:pointer;padding:.4rem .6rem;border:1px solid #2a2010;font-size:.85rem;color:#c0b090">' + nomPersonne + '</div>';
  });
  html += '</div>';
  resultatsEl.innerHTML = html;
}

function etatCivilAfficherFiche(nomPersonne) {
  const fiche = etatCivilConstruireFiche(nomPersonne);
  if (!fiche) return;

  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;margin-bottom:.7rem">Fiche — ' + fiche.nom + '</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.35rem;margin-bottom:1rem">';
  if (fiche.evenements.length === 0) {
    html += '<div style="font-size:.82rem;color:#5a5040;font-style:italic">Aucun événement connu.</div>';
  }
  fiche.evenements.forEach(function(e) {
    html += '<div style="font-size:.85rem;color:#e0d8c0">' + e.texte + '</div>';
  });
  html += '</div>';
  const nomEchap = fiche.nom.replace(/'/g, "\\'");
  html += '<button class="pnj-action-btn" onclick="etatCivilImprimerFiche(\'' + nomEchap + '\')"><i class="ti ti-printer" style="font-size:.85rem"></i> Imprimer cette fiche</button> ';
  html += '<button class="pnj-action-btn" onclick="doConsulterEtatCivil()" style="opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> Nouvelle recherche</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
}

function etatCivilImprimerFiche(nomPersonne) {
  const fiche = etatCivilConstruireFiche(nomPersonne);
  if (!fiche) return;
  if (!state.inventory) state.inventory = [];

  const dejaImprimee = state.inventory.some(function(item) { return item.nom === 'Fiche d\'état-civil — ' + fiche.nom; });
  if (dejaImprimee) {
    if (typeof showToast === 'function') showToast('Déjà en poche', 'Vous avez déjà cette fiche dans votre inventaire.', false);
    return;
  }

  const texteComplet = fiche.evenements.map(function(e) { return e.texte; }).join('\\n');
  state.inventory.push({
    nom: 'Fiche d\'état-civil — ' + fiche.nom,
    icon: 'ti-file-text',
    description: texteComplet
  });
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
  if (typeof showToast === 'function') showToast('Fiche imprimée', fiche.nom + ' ajouté(e) à votre inventaire.', true);
}
