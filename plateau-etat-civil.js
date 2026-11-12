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
      const suffixeNaissance = nomVilleNaissance ? ecT('birthPlace',{city:nomVilleNaissance}) : '';
      evenementsJoueur.push({ annee: d.getFullYear(), texte: ecT('birthEvent',{date:ecDate(d.getDate(),d.getMonth()+1,d.getFullYear()),name:joueur.name,place:suffixeNaissance,parents:''}) });
    }

    (ETAT_CIVIL_CACHE_MARIAGES || []).forEach(function(m) {
      if (m.conjoint1 !== nomPersonne && m.conjoint2 !== nomPersonne) return;
      const conjoint = m.conjoint1 === nomPersonne ? m.conjoint2 : m.conjoint1;
      if (!m.created_at) return;
      const dm = new Date(m.created_at);
      const dateTxt = ecDate(dm.getDate(),dm.getMonth()+1,dm.getFullYear());
      const nomVilleMariage = etatCivilNomVille(m.city);
      const suffixeMariage = nomVilleMariage ? ecT('marriagePlace',{city:nomVilleMariage}) : '';
      evenementsJoueur.push({ annee: dm.getFullYear(), texte: ecT('marriageEvent',{date:dateTxt,name:nomPersonne,spouse:conjoint,place:suffixeMariage}) });
      if (m.statut === 'dissous') {
        const motif = m.raison_dissolution === 'veuvage' ? ecT('widow') : ecT('divorce');
        evenementsJoueur.push({ annee: dm.getFullYear(), texte: ecT('dissolvedEvent',{spouse:conjoint,reason:motif}) });
      }
    });

    const deces = (ETAT_CIVIL_CACHE_DECES || []).find(function(x) { return x.nom === nomPersonne; });
    if (deces && deces.created_at) {
      const dd = new Date(deces.created_at);
      const nomVilleDeces = etatCivilNomVille(deces.city);
      const suffixeDeces = nomVilleDeces ? ecT('deathPlace',{city:nomVilleDeces}) : '';
      evenementsJoueur.push({ annee: dd.getFullYear(), texte: ecT('deathEvent',{date:ecDate(dd.getDate(),dd.getMonth()+1,dd.getFullYear()),name:joueur.name,place:suffixeDeces}) });
    }

    evenementsJoueur.sort(function(a, b) { return a.annee - b.annee; });
    return { nom: joueur.name, evenements: evenementsJoueur };
  }

  const evenements = [];

  if (p.naissanceAnnee) {
    const parentsTxt = (p.parents && p.parents.length === 2)
      ? ecT('birthParents',{parents:p.parents[0]+' et '+p.parents[1]})
      : '';
    const dateTxt = ecDate(p.naissanceJour,p.naissanceMois,p.naissanceAnnee);
    evenements.push({ annee: p.naissanceAnnee, texte: ecT('birthEvent',{date:dateTxt,name:p.nom,place:'',parents:parentsTxt}) });
  }
  if (p.mariageAnnee && p.conjoint) {
    const dateTxt = ecDate(p.mariageJour,p.mariageMois,p.mariageAnnee);
    evenements.push({ annee: p.mariageAnnee, texte: ecT('marriageEvent',{date:dateTxt,name:p.nom,spouse:p.conjoint,place:''}) });
  }
  // Enfants : toute personne du registre dont p.nom figure dans ses parents.
  registre.forEach(function(autre) {
    if (autre.parents && autre.parents.indexOf(p.nom) !== -1 && autre.naissanceAnnee) {
      const parentsEnfantTxt = autre.parents.join(' et ');
      const dateTxt = ecDate(autre.naissanceJour,autre.naissanceMois,autre.naissanceAnnee);
      evenements.push({ annee: autre.naissanceAnnee, texte: ecT('birthEvent',{date:dateTxt,name:autre.nom,place:'',parents:ecT('birthParents',{parents:parentsEnfantTxt})}) });
    }
  });
  if (p.decesAnnee) {
    const dateTxt = ecDate(p.decesJour,p.decesMois,p.decesAnnee);
    evenements.push({ annee: p.decesAnnee, texte: ecT('deathEvent',{date:dateTxt,name:p.nom,place:''}) });
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
async function etatCivilDelivrerActe(acte, nomConcerne, pa, cost) {
  return await executerReceptionInventaire('etat_civil_document_recevoir', { p_nom: nomConcerne, p_type: acte.type,
    p_reference: acte.id || null, p_pa: pa, p_cost: cost });
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

function ecT(key,vars){return window.RPCivilRegistryI18n?.text?.(key,vars||{})||key;}
function ecDate(jour,mois,annee){
 if(!annee)return '';
 if(!jour||!mois)return String(annee);
 const locale=window.RP_I18N_GAME_ENABLED===true?(window.RPPlateauI18n?.language?.()||'fr'):'fr';
 if(locale==='fr')return etatCivilFormaterDate(jour,mois,annee);
 const formats={en:'en-US',es:'es-ES','zh-TW':'zh-TW',ru:'ru-RU',ko:'ko-KR',ar:'ar','pt-BR':'pt-BR',de:'de-DE'};
 return new Date(annee,mois-1,jour).toLocaleDateString(formats[locale]||'fr-FR',{year:'numeric',month:'long',day:'numeric'});
}

function ecH(str){return String(str).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function ecLabel(key,vars){return ecH(ecT(key,vars));}
function ecSpan(key,vars){
 return '<span data-ec-i18n="'+key+'" data-ec-args="'+ecH(JSON.stringify(vars||{}))+'">'+ecLabel(key,vars)+'</span>';
}
function doConsulterEtatCivil() {
  document.getElementById('postes-modal-title').textContent = ecT('title');
  document.getElementById('postes-body').innerHTML = etatCivilHtmlRecherche();
  document.getElementById('modal-postes').classList.add('open');
}

function etatCivilHtmlRecherche(messageErreur) {
  let html = '<div style="padding:1rem">';
  html += '<div style="font-size:.85rem;color:#8a8060;margin-bottom:.8rem">'+ecSpan('instructions')+'</div>';
  html += '<div style="display:flex;gap:.4rem;margin-bottom:.4rem">';
  html += '<input id="etat-civil-nom" type="text" data-ec-placeholder="name" placeholder="'+ecLabel('name')+'" style="flex:1;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '<input id="etat-civil-decennie" type="text" data-ec-placeholder="decade" placeholder="'+ecLabel('decade')+'" style="width:150px;background:#121005;border:1px solid #2a2010;color:#f0ead6;padding:.4rem .6rem;font-family:Crimson Pro,serif;font-size:.82rem;outline:none" />';
  html += '</div>';
  html += '<button class="pnj-action-btn" onclick="etatCivilLancerRecherche()"><i class="ti ti-search" style="font-size:.85rem"></i> '+ecSpan('search')+'</button>';
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
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">'+ecSpan('needSearch')+'</div>';
    return;
  }
  if (resultats.length === 0) {
    resultatsEl.innerHTML = '<div style="font-size:.8rem;color:#8a3a20;font-style:italic">'+ecSpan('noResults')+'</div>';
    return;
  }

  let html = '<div style="font-size:.8rem;color:#c0b090;margin-bottom:.4rem">' + ecSpan('results',{count:resultats.length}) + '</div>';
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
  html += '<div style="font-size:1rem;color:#C9A84C;font-family:Bebas Neue,sans-serif;letter-spacing:.06em;margin-bottom:.7rem">'+ecSpan('record',{name:fiche.nom})+'</div>';
  html += '<div style="display:flex;flex-direction:column;gap:.35rem;margin-bottom:1rem">';
  if (fiche.evenements.length === 0) {
    html += '<div style="font-size:.82rem;color:#5a5040;font-style:italic">'+ecSpan('noEvent')+'</div>';
  }
  fiche.evenements.forEach(function(e) {
    html += '<div style="font-size:.85rem;color:#e0d8c0">' + e.texte + '</div>';
  });
  html += '</div>';
  const nomEchap = fiche.nom.replace(/'/g, "\\'");
  html += '<button class="pnj-action-btn" onclick="etatCivilImprimerFiche(\'' + nomEchap + '\')"><i class="ti ti-printer" style="font-size:.85rem"></i> '+ecSpan('print')+'</button> ';
  html += '<button class="pnj-action-btn" onclick="doConsulterEtatCivil()" style="opacity:.8"><i class="ti ti-arrow-left" style="font-size:.85rem"></i> '+ecSpan('newSearch')+'</button>';
  html += '</div>';

  document.getElementById('postes-body').innerHTML = html;
}

async function etatCivilImprimerFiche(nomPersonne) {
  const v = await executerReceptionInventaire('etat_civil_document_recevoir', { p_nom: nomPersonne, p_type: 'fiche', p_reference: null, p_pa: 0, p_cost: 0 });
  if (!v) return;
  updateUI(); renderInventory(); showToast(ecT('printed'), ecT('added',{object:v.objet}), true);
}

(window.RP_I18N_CHANGE_CALLBACKS=window.RP_I18N_CHANGE_CALLBACKS||[]).push(function(){
 const body=document.getElementById('postes-body');
 const modal=document.getElementById('modal-postes');
 if(!modal?.classList?.contains('open')||!body?.querySelector?.('[data-ec-i18n],[data-ec-placeholder]'))return;
 const titre=document.getElementById('postes-modal-title');
 if(titre)titre.textContent=ecT('title');
 body.querySelectorAll('[data-ec-i18n]').forEach(node=>{
  let args={};try{args=JSON.parse(node.getAttribute('data-ec-args')||'{}');}catch(_){}
  node.textContent=ecT(node.getAttribute('data-ec-i18n'),args);
 });
 body.querySelectorAll('[data-ec-placeholder]').forEach(node=>{
  node.placeholder=ecT(node.getAttribute('data-ec-placeholder'));
 });
});
