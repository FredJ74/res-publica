// plateau-etat-civil.js
// Registre d'etat-civil de Republia — consultable a la Salle des Archives de la Mairie.
// Sert d'abord a l'enigme du Portrait Disparu (genealogie Thibault/Poincon), et sera etendu
// plus tard comme annuaire officiel des PJ (naissance = creation du personnage, deces = depart).

const ETAT_CIVIL_MOIS = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

const ETAT_CIVIL_REGISTRE = {
  republic: [
    { nom: 'Pierre Thibault',     naissanceAnnee: 1898, naissanceJour: 12, naissanceMois: 3,  parents: [],                                  mariageAnnee: 1920, mariageJour: 4,  mariageMois: 6,  conjoint: 'Marie Ravichoux',   decesAnnee: 1949, decesJour: 17, decesMois: 11 },
    { nom: 'Marie Ravichoux',     naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1920, mariageJour: 4,  mariageMois: 6,  conjoint: 'Pierre Thibault',    decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Élise Thibault',      naissanceAnnee: 1929, naissanceJour: 8,  naissanceMois: 8,  parents: ['Pierre Thibault', 'Marie Ravichoux'], mariageAnnee: 1950, mariageJour: 22, mariageMois: 5,  conjoint: 'Bernard Poinçon', decesAnnee: 1991, decesJour: 3, decesMois: 1 },
    { nom: 'Bernard Poinçon',     naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1950, mariageJour: 22, mariageMois: 5,  conjoint: 'Élise Thibault',     decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Gérard Poinçon',      naissanceAnnee: 1960, naissanceJour: 14, naissanceMois: 9,  parents: ['Bernard Poinçon', 'Élise Thibault'], mariageAnnee: null, mariageJour: null, mariageMois: null, conjoint: null,               decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Marcel Torcieu',      naissanceAnnee: 1895, naissanceJour: 5,  naissanceMois: 2,  parents: [],                                  mariageAnnee: 1915, mariageJour: 19, mariageMois: 6,  conjoint: 'Mathilde Bijoux',    decesAnnee: 1958, decesJour: 30, decesMois: 10 },
    { nom: 'Mathilde Bijoux',     naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1915, mariageJour: 19, mariageMois: 6,  conjoint: 'Marcel Torcieu',     decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Maurice Caillon',     naissanceAnnee: 1901, naissanceJour: 21, naissanceMois: 7,  parents: [],                                  mariageAnnee: 1920, mariageJour: 9,  mariageMois: 4,  conjoint: 'Lucienne Balrasse',  decesAnnee: 1954, decesJour: 2, decesMois: 12 },
    { nom: 'Lucienne Balrasse',   naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1920, mariageJour: 9,  mariageMois: 4,  conjoint: 'Maurice Caillon',    decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Jacques Moulin',      naissanceAnnee: 1897, naissanceJour: 16, naissanceMois: 1,  parents: [],                                  mariageAnnee: 1923, mariageJour: 27, mariageMois: 3,  conjoint: 'Raymonde Charcot',   decesAnnee: 1965, decesJour: 8, decesMois: 6 },
    { nom: 'Raymonde Charcot',    naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1923, mariageJour: 27, mariageMois: 3,  conjoint: 'Jacques Moulin',     decesAnnee: null, decesJour: null, decesMois: null },
    { nom: 'Étienne Tintabin',    naissanceAnnee: 1898, naissanceJour: 11, naissanceMois: 5,  parents: [],                                  mariageAnnee: 1921, mariageJour: 14, mariageMois: 9,  conjoint: 'Ludivine Girard',    decesAnnee: 1969, decesJour: 25, decesMois: 4 },
    { nom: 'Ludivine Girard',     naissanceAnnee: null, naissanceJour: null, naissanceMois: null, parents: [],                              mariageAnnee: 1921, mariageJour: 14, mariageMois: 9,  conjoint: 'Étienne Tintabin',   decesAnnee: null, decesJour: null, decesMois: null }
  ]
};

function etatCivilFormaterDate(jour, mois, annee) {
  if (!annee) return '';
  if (jour && mois) return jour + ' ' + ETAT_CIVIL_MOIS[mois - 1] + ' ' + annee;
  return String(annee);
}

// Cache des vrais joueurs (naissance = date de creation du personnage), charge une seule
// fois par session depuis Supabase. Permet au registre de recenser aussi les PJ, pas
// seulement les personnages historiques de l'enigme.
let ETAT_CIVIL_CACHE_JOUEURS = null;

let ETAT_CIVIL_CACHE_MARIAGES = null;
let ETAT_CIVIL_CACHE_DECES = null;
let ETAT_CIVIL_CACHE_NAISSANCES = null;

// Conversion identifiant de ville -> nom RP, mecanisme canonique deja utilise partout ailleurs
// dans le jeu (WORLD[pays][ville].name) -- aucune table parallele creee (17 aout 2026, mini-lot
// etat-civil). Retourne null si city est absent (acte legacy ou migration pas encore appliquee) :
// permet a l'appelant de choisir une formulation neutre plutot que d'inventer une ville.
function etatCivilNomVille(city) {
  if (!city) return null;
  return (typeof WORLD !== 'undefined' && WORLD[state.country]?.[city]?.name) || city;
}

async function etatCivilChargerJoueurs() {
  if (ETAT_CIVIL_CACHE_JOUEURS) return ETAT_CIVIL_CACHE_JOUEURS;
  try {
    const rows = (typeof sbGet === 'function') ? await sbGet('personnages', 'select=name,country,created_at') : [];
    ETAT_CIVIL_CACHE_JOUEURS = rows || [];
  } catch (e) {
    ETAT_CIVIL_CACHE_JOUEURS = [];
  }
  try {
    ETAT_CIVIL_CACHE_MARIAGES = (typeof sbGetTousLesMariages === 'function') ? await sbGetTousLesMariages(state.country) : [];
  } catch (e) {
    ETAT_CIVIL_CACHE_MARIAGES = [];
  }
  try {
    ETAT_CIVIL_CACHE_DECES = (typeof sbGetTousLesDeces === 'function') ? await sbGetTousLesDeces(state.country) : [];
  } catch (e) {
    ETAT_CIVIL_CACHE_DECES = [];
  }
  try {
    ETAT_CIVIL_CACHE_NAISSANCES = (typeof sbGetToutesLesNaissances === 'function') ? await sbGetToutesLesNaissances(state.country) : [];
  } catch (e) {
    ETAT_CIVIL_CACHE_NAISSANCES = [];
  }
  return ETAT_CIVIL_CACHE_JOUEURS;
}

// Construit la liste des evenements datables d'une personne : sa naissance, son mariage,
// la naissance de ses enfants (deduits du registre), et son deces. Tries par annee.
function etatCivilConstruireFiche(nomPersonne) {
  const registre = ETAT_CIVIL_REGISTRE[state.country] || [];
  const p = registre.find(function(x) { return x.nom === nomPersonne; });

  if (!p) {
    // Pas un personnage historique : peut-etre un vrai joueur (naissance = creation du perso).
    const joueur = (ETAT_CIVIL_CACHE_JOUEURS || []).find(function(j) { return j.name === nomPersonne; });
    if (!joueur) return null;

    const evenementsJoueur = [];
    if (joueur.created_at) {
      const d = new Date(joueur.created_at);
      // Ville de naissance (17 aout 2026) : table dediee etat_civil_naissances, absente pour
      // tout personnage cree avant ce correctif (ou avant l'application de la migration) --
      // formulation neutre dans ce cas, jamais de ville inventee.
      const naissance = (ETAT_CIVIL_CACHE_NAISSANCES || []).find(function(x) { return x.nom === nomPersonne; });
      const nomVilleNaissance = etatCivilNomVille(naissance?.city);
      const suffixeNaissance = nomVilleNaissance ? (', née à ' + nomVilleNaissance) : '';
      evenementsJoueur.push({ annee: d.getFullYear(), texte: d.getDate() + ' ' + ETAT_CIVIL_MOIS[d.getMonth()] + ' ' + d.getFullYear() + ' : naissance de ' + joueur.name + suffixeNaissance + '.' });
    }

    (ETAT_CIVIL_CACHE_MARIAGES || []).forEach(function(m) {
      if (m.conjoint1 !== nomPersonne && m.conjoint2 !== nomPersonne) return;
      const conjoint = m.conjoint1 === nomPersonne ? m.conjoint2 : m.conjoint1;
      if (!m.created_at) return;
      const dm = new Date(m.created_at);
      const dateTxt = dm.getDate() + ' ' + ETAT_CIVIL_MOIS[dm.getMonth()] + ' ' + dm.getFullYear();
      const nomVilleMariage = etatCivilNomVille(m.city);
      const suffixeMariage = nomVilleMariage ? (', célébré à ' + nomVilleMariage) : '';
      evenementsJoueur.push({ annee: dm.getFullYear(), texte: dateTxt + ' : mariage de ' + nomPersonne + ' avec ' + conjoint + suffixeMariage + '.' });
      if (m.statut === 'dissous') {
        const motif = m.raison_dissolution === 'veuvage' ? 'veuvage' : 'divorce';
        evenementsJoueur.push({ annee: dm.getFullYear(), texte: 'Union avec ' + conjoint + ' dissoute (' + motif + ').' });
      }
    });

    const deces = (ETAT_CIVIL_CACHE_DECES || []).find(function(x) { return x.nom === nomPersonne; });
    if (deces && deces.created_at) {
      const dd = new Date(deces.created_at);
      const nomVilleDeces = etatCivilNomVille(deces.city);
      const suffixeDeces = nomVilleDeces ? (' à ' + nomVilleDeces) : '';
      evenementsJoueur.push({ annee: dd.getFullYear(), texte: dd.getDate() + ' ' + ETAT_CIVIL_MOIS[dd.getMonth()] + ' ' + dd.getFullYear() + ' : décès de ' + joueur.name + suffixeDeces + '.' });
    }

    evenementsJoueur.sort(function(a, b) { return a.annee - b.annee; });
    return { nom: joueur.name, evenements: evenementsJoueur };
  }

  const evenements = [];

  if (p.naissanceAnnee) {
    const parentsTxt = (p.parents && p.parents.length === 2)
      ? ', fils/fille de ' + p.parents[0] + ' et ' + p.parents[1]
      : '';
    const dateTxt = etatCivilFormaterDate(p.naissanceJour, p.naissanceMois, p.naissanceAnnee);
    evenements.push({ annee: p.naissanceAnnee, texte: dateTxt + ' : naissance de ' + p.nom + parentsTxt + '.' });
  }
  if (p.mariageAnnee && p.conjoint) {
    const dateTxt = etatCivilFormaterDate(p.mariageJour, p.mariageMois, p.mariageAnnee);
    evenements.push({ annee: p.mariageAnnee, texte: dateTxt + ' : mariage de ' + p.nom + ' avec ' + p.conjoint + '.' });
  }
  // Enfants : toute personne du registre dont p.nom figure dans ses parents.
  registre.forEach(function(autre) {
    if (autre.parents && autre.parents.indexOf(p.nom) !== -1 && autre.naissanceAnnee) {
      const parentsEnfantTxt = autre.parents.join(' et ');
      const dateTxt = etatCivilFormaterDate(autre.naissanceJour, autre.naissanceMois, autre.naissanceAnnee);
      evenements.push({ annee: autre.naissanceAnnee, texte: dateTxt + ' : naissance de ' + autre.nom + ', fils/fille de ' + parentsEnfantTxt + '.' });
    }
  });
  if (p.decesAnnee) {
    const dateTxt = etatCivilFormaterDate(p.decesJour, p.decesMois, p.decesAnnee);
    evenements.push({ annee: p.decesAnnee, texte: dateTxt + ' : décès de ' + p.nom + '.' });
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

  // Vrais joueurs (meme empire uniquement) — verifie tous les evenements (naissance,
  // mariage/divorce, deces), pas seulement la naissance, pour la recherche par decennie.
  (ETAT_CIVIL_CACHE_JOUEURS || []).forEach(function(j) {
    if (j.country !== state.country) return;
    if (nomLower && j.name.toLowerCase().indexOf(nomLower) === -1) return;
    if (decDebut !== null) {
      const fiche = etatCivilConstruireFiche(j.name);
      const ok = fiche && fiche.evenements.some(function(e) { return e.annee >= decDebut && e.annee <= decFin; });
      if (!ok) return;
    }
    if (resultats.indexOf(j.name) === -1) resultats.push(j.name);
  });

  return resultats;
}

// =====================
// ACTES OFFICIELS INDIVIDUELS ("Demander un acte officiel", chantier du 3 septembre 2026) --
// distinct de la "Fiche d'état-civil" ci-dessus (synthese complete de tous les evenements) :
// chaque acte est un document UNITAIRE (un type precis, une personne precise), materialise dans
// l'inventaire, jamais un simple renommage de la fiche. Reutilise EXCLUSIVEMENT les donnees deja
// chargees par etatCivilChargerJoueurs() ci-dessus -- aucune donnee inventee, aucun deuxieme
// systeme de lecture d'etat-civil.
// =====================

// Actes REELLEMENT disponibles pour nomPersonne, a partir des seules donnees persistees. Chaque
// entree : { type, id?, titre, texte } -- "texte" est le contenu integral pret a etre appose sur
// l'objet d'inventaire. Un type absent des donnees reelles n'apparait simplement pas (jamais un
// acte "vide" ou invente).
async function etatCivilActesDisponibles(nomPersonne) {
  await etatCivilChargerJoueurs();
  const actes = [];

  // --- Naissance : personnages.created_at (vivant) OU etat_civil_naissances seul (PJ disparu,
  // seule trace persistante restante -- meme doctrine que etat_civil_deces, voir plus bas) ---
  const joueurVivant = (ETAT_CIVIL_CACHE_JOUEURS || []).find(function(j) { return j.name === nomPersonne; });
  const naissanceArchive = (ETAT_CIVIL_CACHE_NAISSANCES || []).find(function(x) { return x.nom === nomPersonne; });
  const dateNaissanceSource = (joueurVivant && joueurVivant.created_at) ? joueurVivant.created_at : (naissanceArchive && naissanceArchive.created_at);
  if (dateNaissanceSource) {
    const d = new Date(dateNaissanceSource);
    const ville = etatCivilNomVille(naissanceArchive?.city);
    const dateTxt = d.getDate() + ' ' + ETAT_CIVIL_MOIS[d.getMonth()] + ' ' + d.getFullYear();
    actes.push({
      type: 'naissance',
      titre: "Extrait d'acte de naissance",
      texte: "EXTRAIT D'ACTE DE NAISSANCE\n\n" + nomPersonne + ', né(e) le ' + dateTxt + (ville ? ' à ' + ville : '') + '.'
    });
  }

  // --- Mariage(s) reels : une entree par union trouvee dans "mariages", dissolution mentionnee
  // le cas echeant (jamais masquee) ---
  (ETAT_CIVIL_CACHE_MARIAGES || []).forEach(function(m) {
    if (m.conjoint1 !== nomPersonne && m.conjoint2 !== nomPersonne) return;
    if (!m.created_at) return;
    const conjoint = m.conjoint1 === nomPersonne ? m.conjoint2 : m.conjoint1;
    const dm = new Date(m.created_at);
    const dateTxt = dm.getDate() + ' ' + ETAT_CIVIL_MOIS[dm.getMonth()] + ' ' + dm.getFullYear();
    const ville = etatCivilNomVille(m.city);
    let texte = "EXTRAIT D'ACTE DE MARIAGE\n\n" + nomPersonne + ' et ' + conjoint + ', union célébrée le ' + dateTxt + (ville ? ' à ' + ville : '') + '.';
    if (m.statut === 'dissous') {
      const motif = m.raison_dissolution === 'veuvage' ? 'veuvage' : 'divorce';
      texte += '\n\nUnion dissoute (' + motif + ').';
    }
    actes.push({ type: 'mariage', id: m.id, titre: "Extrait d'acte de mariage — " + conjoint, texte: texte });
  });

  // --- Deces reel : recherche DIRECTE dans etat_civil_deces, jamais conditionnee a la presence
  // d'une ligne "personnages" (un PJ decede est supprime de personnages -- etat_civil_deces est
  // la SEULE trace qui persiste, voir supabase.js/sbCreerActeDeces). C'est la raison precise pour
  // laquelle ce chantier ne reutilise pas etatCivilConstruireFiche telle quelle pour cet acte :
  // elle exige un match "personnages" ou registre fictif, donc echoue silencieusement pour un PJ
  // reellement decede -- limite documentee, contournee ici en lisant etat_civil_deces directement.
  const deces = (ETAT_CIVIL_CACHE_DECES || []).find(function(x) { return x.nom === nomPersonne; });
  if (deces && deces.created_at) {
    const dd = new Date(deces.created_at);
    const ville = etatCivilNomVille(deces.city);
    const dateTxt = dd.getDate() + ' ' + ETAT_CIVIL_MOIS[dd.getMonth()] + ' ' + dd.getFullYear();
    actes.push({
      type: 'deces',
      titre: "Extrait d'acte de décès",
      texte: "EXTRAIT D'ACTE DE DÉCÈS\n\n" + nomPersonne + ', décédé(e) le ' + dateTxt + (ville ? ' à ' + ville : '') + '.'
    });
  }

  // --- Succession(s) REGLEES ou nomPersonne figure comme beneficiaire d'une disposition --
  // reutilise chargerSuccessionsReelles() (plateau-enigme-portrait.js), deja la seule source de
  // verite pour "une succession publiquement constatable" (filtre statut==='resolue', jamais un
  // dossier encore en_attente -- memes regles que les Archives Notariales publiques). Ne
  // declenche, ne modifie et ne tranche RIEN : lecture seule d'un dossier deja definitivement
  // regle par le systeme d'heritage existant.
  if (typeof chargerSuccessionsReelles === 'function') {
    const successionsReglees = await chargerSuccessionsReelles();
    successionsReglees.forEach(function(s) {
      const dispositionsPourMoi = (s.dispositions || []).filter(function(d) { return d.resultat && d.resultat.beneficiaire === nomPersonne; });
      if (dispositionsPourMoi.length === 0) return;
      const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[s.country]?.cur) || 'FR';
      const lignes = dispositionsPourMoi.map(function(d) {
        if (d.type === 'argent') return '- Somme nette perçue : ' + (d.part_nette || 0) + ' ' + cur;
        return '- ' + (d.type === 'terrain' ? 'Terrain' : 'Entreprise') + ' : ' + (d.libelle || d.id);
      });
      actes.push({
        type: 'succession',
        id: s.id,
        titre: 'Acte de succession — ' + s.defunt,
        texte: 'ACTE DE SUCCESSION\n\nSuccession de ' + s.defunt + ', réglée.\nBénéficiaire : ' + nomPersonne + '\n\n' + lignes.join('\n')
      });
    });
  }

  return actes;
}

// Cle d'unicite d'un acte pour UNE personne concernee donnee -- sert a la fois d'anti-doublon
// (ne jamais empiler deux fois le meme extrait) et de marqueur "quel acte precis est-ce" sur
// l'objet d'inventaire (voir etatCivilDelivrerActe).
function etatCivilCleActe(acte, nomConcerne) {
  return 'acte-' + acte.type + '-' + nomConcerne.replace(/\s+/g, '-').toLowerCase() + (acte.id ? '-' + String(acte.id).replace(/\s+/g, '-').toLowerCase() : '');
}

function etatCivilActeDejaPossede(acte, nomConcerne) {
  const cle = etatCivilCleActe(acte, nomConcerne);
  return (state.inventory || []).some(function(item) { return item.acteCle === cle; });
}

// Ajoute l'acte a l'inventaire de CELUI QUI AGIT (state), jamais celui de nomConcerne -- pour le
// citoyen demandant son propre acte, les deux sont la meme personne ; pour une fonction habilitee
// (maire adjoint/juge) delivrant l'acte d'un tiers, l'extrait rejoint le classeur du fonctionnaire
// qui l'a etabli, exactement le comportement deja existant de l'ancien delivrerActe(). Renvoie
// false sans rien faire si deja possede (anti-doublon).
function etatCivilDelivrerActe(acte, nomConcerne) {
  if (etatCivilActeDejaPossede(acte, nomConcerne)) return false;
  if (!state.inventory) state.inventory = [];
  state.inventory.push({
    id: etatCivilCleActe(acte, nomConcerne) + '-' + Date.now(),
    acteCle: etatCivilCleActe(acte, nomConcerne),
    type: 'acte_officiel_' + acte.type,
    name: acte.titre,
    icon: 'ti-file-certificate',
    legal: true,
    concerne: nomConcerne,
    desc: acte.texte
  });
  return true;
}

// Recherche par nom pour les fonctions habilitees (maire adjoint/juge) : contrairement a
// etatCivilRechercher() (registre fictif + vrais joueurs VIVANTS, pour "Consulter l'état-civil"),
// celle-ci doit aussi retrouver une personne dont la seule trace restante est un deces/mariage
// reel (PJ supprime de "personnages") -- jamais le registre fictif de l'enigme du Portrait
// Disparu, hors de propos pour un acte officiel reel.
function etatCivilRechercherPourActe(nomQuery) {
  const nomLower = (nomQuery || '').trim().toLowerCase();
  if (!nomLower) return [];
  const noms = [];
  const ajouter = function(nom) { if (nom && noms.indexOf(nom) === -1) noms.push(nom); };
  (ETAT_CIVIL_CACHE_JOUEURS || []).forEach(function(j) {
    if (j.country === state.country && j.name.toLowerCase().indexOf(nomLower) !== -1) ajouter(j.name);
  });
  (ETAT_CIVIL_CACHE_DECES || []).forEach(function(d) {
    if (d.nom && d.nom.toLowerCase().indexOf(nomLower) !== -1) ajouter(d.nom);
  });
  (ETAT_CIVIL_CACHE_MARIAGES || []).forEach(function(m) {
    [m.conjoint1, m.conjoint2].forEach(function(n) { if (n && n.toLowerCase().indexOf(nomLower) !== -1) ajouter(n); });
  });
  return noms;
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

async function etatCivilLancerRecherche() {
  await etatCivilChargerJoueurs();
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

  const dejaImprimee = state.inventory.some(function(item) { return item.name === 'Fiche d\'état-civil — ' + fiche.nom; });
  if (dejaImprimee) {
    if (typeof showToast === 'function') showToast('Déjà en poche', 'Vous avez déjà cette fiche dans votre inventaire.', false);
    return;
  }

  const texteComplet = fiche.evenements.map(function(e) { return e.texte; }).join('<br><br>');
  state.inventory.push({
    id: 'fiche-etat-civil-' + fiche.nom.replace(/\s+/g, '-').toLowerCase() + '-' + Date.now(),
    name: 'Fiche d\'état-civil — ' + fiche.nom,
    icon: 'ti-file-text',
    desc: texteComplet
  });
  if (typeof sbSavePersonnage === 'function') sbSavePersonnage(state).catch(function() {});
  if (typeof updateUI === 'function') updateUI();
  if (typeof renderInventory === 'function') renderInventory();
  if (typeof showToast === 'function') showToast('Fiche imprimée', fiche.nom + ' ajouté(e) à votre inventaire.', true);
}
