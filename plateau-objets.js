// =====================
// PLATEAU-OBJETS.JS — SCHEMA D'OBJET, EFFETS, ASSOCIATIONS, INSTALLATION (Lot 4.0)
// =====================
// Socle commun a tout ce qui est fabrique, achete, transporte, utilise, installe ou herite.
//
// POURQUOI UN SCHEMA. L'audit du 8 septembre 2026 a etabli qu'aucune convention d'objet n'existe :
// chaque site de creation pousse dans state.inventory les champs qui l'arrangent, et deux
// conventions d'effets se contredisent -- effets:{hp,moral} reellement applique par les recettes,
// et effet:'ip+10' en chaine de caracteres, que le code lui-meme signale comme jamais lue. Ce
// module pose une convention unique, sans casser les objets existants : tout ce qui ne declare
// pas de schema continue de vivre exactement comme avant.
//
// CONTRAT : pur. Aucune ecriture, aucun DOM, aucun reseau, aucune dependance a state. Les
// mouvements reels appartiennent aux appelants et aux RPC.
//
// NOYAU STABLE + EXTENSIONS. Le cahier des charges met en garde contre un "monstre JSON" : le
// noyau ci-dessous tient en sept champs, tout le reste vit dans des extensions nommees et
// facultatives. Une pomme de terre n'emporte jamais le poids d'un tableau de maitre.

// ---------------------------------------------------------------------------
// NOYAU
// ---------------------------------------------------------------------------
// id        : identifiant de la REFERENCE (le modele), pas de l'exemplaire
// nom       : libelle affiche
// famille   : famille de commerce d'origine (voir FAMILLES_COMMERCE, plateau-commerce.js)
// categorie : sous-type FONCTIONNEL, jamais la forme physique (cf. §26 du cahier des charges)
// icone     : icone Tabler, seul visuel garanti
// regime    : 'empilable' | 'individuel'
// qty       : quantite (empilable uniquement ; un individuel vaut toujours 1)
const OBJET_CHAMPS_NOYAU = ['id', 'nom', 'famille', 'categorie', 'icone', 'regime', 'qty'];

// Extensions reconnues. Chacune est facultative et n'est lue que par le sous-systeme qui la
// concerne -- ajouter une extension ne change rien pour les objets qui ne la portent pas.
//   effets       : ce que l'objet fait (voir plus bas)
//   provenance   : d'ou il vient et par qui il est passe
//   exemplaire   : identite individuelle (numero, oeuvre, etat)
//   installation : ce qu'il devient une fois pose dans un lieu
//   prerequis    : ce qu'il faut posseder pour s'en servir
const OBJET_EXTENSIONS = ['effets', 'provenance', 'exemplaire', 'installation', 'prerequis'];

const OBJET_REGIMES = ['empilable', 'individuel'];

function nombreSur(valeur, repli) {
  const n = Number(valeur);
  return (typeof valeur !== 'boolean' && valeur !== null && valeur !== '' && isFinite(n)) ? n : (repli || 0);
}

function texteSur(valeur) {
  return (typeof valeur === 'string' && valeur.trim()) ? valeur.trim() : null;
}

// ---------------------------------------------------------------------------
// REGIME : EMPILABLE OU INDIVIDUEL
// ---------------------------------------------------------------------------
// L'inventaire sait deja faire les deux (audit) : stackable/stackKey d'un cote, une ligne par
// objet de l'autre. On ne remplace pas ce mecanisme, on le NOMME, pour qu'un producteur sache
// lequel il fabrique et qu'un transfert sache ce qu'il doit preserver.

function regimeObjet(objet) {
  if (!objet || typeof objet !== 'object') return null;
  if (OBJET_REGIMES.indexOf(objet.regime) !== -1) return objet.regime;
  // Lecture defensive des objets anterieurs au schema : la presence de stackable fait foi.
  return objet.stackable ? 'empilable' : 'individuel';
}

function estIndividualise(objet) {
  return regimeObjet(objet) === 'individuel';
}

// Un exemplaire porte une identite qui lui est propre et qui SURVIT a tout transfert. C'est elle
// qui distingue le tableau de maitre du kilo de farine.
function estExemplaire(objet) {
  return !!(objet && objet.exemplaire && typeof objet.exemplaire === 'object'
            && texteSur(objet.exemplaire.id));
}

// Identite d'exemplaire. Opaque, comme celle d'un fonds : ni le proprietaire, ni le lieu, ni
// l'oeuvre n'y figurent, puisque tous peuvent changer sans que l'objet cesse d'etre le meme.
function nouvelIdExemplaire(prefixe, horodatage, alea) {
  const p = texteSur(prefixe) || 'ex';
  return p + '-' + Math.max(0, Math.floor(nombreSur(horodatage, 0)))
           + '-' + Math.max(0, Math.floor(nombreSur(alea, 0)));
}

// ---------------------------------------------------------------------------
// OEUVRE ET EXEMPLAIRE
// ---------------------------------------------------------------------------
// Un livre n'est pas son texte : mille exemplaires partagent une oeuvre. La distinction vaut
// pour le livre, la VHS, le tableau, le document, la piece de collection -- partout ou plusieurs
// objets physiques renvoient a une meme creation.
//
// L'oeuvre vit dans sa propre table (oeuvres) ; l'exemplaire n'en porte que la REFERENCE. Recopier
// le contenu dans chaque exemplaire creerait autant de verites divergentes qu'il y a d'objets.

function referenceOeuvre(exemplaire) {
  return (exemplaire && exemplaire.exemplaire) ? texteSur(exemplaire.exemplaire.oeuvreId) : null;
}

function estExemplaireDOeuvre(objet) {
  return !!referenceOeuvre(objet);
}

// ---------------------------------------------------------------------------
// PROVENANCE ET PATRIMOINE
// ---------------------------------------------------------------------------
// Un objet peut devenir interessant parce qu'il a une histoire. Mais l'histoire a un cout de
// stockage : on ne tient un journal que pour ce qui le merite.
//
// REGLE : un objet EMPILABLE ne porte jamais de journal de transferts -- au mieux son origine.
// Seul un exemplaire accumule des etapes, et seulement celles qui SIGNIFIENT quelque chose
// (creation, vente, don, heritage, evenement). Un deplacement de poche a poche n'est pas une
// etape.
const PROVENANCE_ETAPES = ['creation', 'vente', 'don', 'heritage', 'evenement'];
// Garde-fou : au-dela, on ne garde que la creation et les dernieres etapes. Une histoire n'est pas
// une chaine de blocs.
const PROVENANCE_MAX_ETAPES = 20;

function provenanceInitiale(options) {
  const o = options || {};
  return {
    createur: texteSur(o.createur),          // reference typee 'pj:' / 'orga:' / null si PNJ
    fondsId: texteSur(o.fondsId),            // commerce producteur
    jour: (typeof o.jour === 'number') ? o.jour : null,
    etapes: []
  };
}

// Ajoute une etape SIGNIFICATIVE. Pure : renvoie une nouvelle provenance.
function ajouterEtapeProvenance(provenance, etape) {
  const p = provenance || provenanceInitiale({});
  const e = etape || {};
  if (PROVENANCE_ETAPES.indexOf(e.type) === -1) return p;
  const etapes = (Array.isArray(p.etapes) ? p.etapes : []).concat([{
    type: e.type, de: texteSur(e.de), vers: texteSur(e.vers),
    jour: (typeof e.jour === 'number') ? e.jour : null,
    detail: texteSur(e.detail)
  }]);
  // On conserve toujours la creation, puis les plus recentes : le debut et la fin d'une histoire
  // en disent plus que son milieu.
  const tronquees = etapes.length > PROVENANCE_MAX_ETAPES
    ? [etapes[0]].concat(etapes.slice(etapes.length - (PROVENANCE_MAX_ETAPES - 1)))
    : etapes;
  return Object.assign({}, p, { etapes: tronquees });
}

// Un transfert d'exemplaire DOIT preserver son identite et ses metadonnees. Seule la provenance
// s'enrichit. Pure.
function transfererExemplaire(objet, de, vers, typeEtape, jour) {
  if (!estExemplaire(objet)) return objet;
  return Object.assign({}, objet, {
    provenance: ajouterEtapeProvenance(objet.provenance,
      { type: PROVENANCE_ETAPES.indexOf(typeEtape) !== -1 ? typeEtape : 'don',
        de: de, vers: vers, jour: jour })
  });
}

// ---------------------------------------------------------------------------
// EFFETS
// ---------------------------------------------------------------------------
// Une seule convention declarative, qui remplace les deux conventions contradictoires de
// l'existant. Un effet dit CE QU'IL FAIT, jamais COMMENT : aucun `if` par produit.
//
//   cible   : sur quoi il agit
//   nature  : instantane ou temporaire
//   deltas  : { hp, moral, pa, pop, inf, <stat>, <indice> } -- toujours des nombres
//   dureeMs : pour un effet temporaire, en millisecondes REELLES
//   cle     : identite de l'effet, base du NON-CUMUL
const EFFET_CIBLES = ['pj', 'objet', 'lieu', 'collectif'];
const EFFET_NATURES = ['instantane', 'temporaire'];

// Grandeurs qu'un effet a le droit de toucher. Volontairement enumerees : un effet ne doit pas
// pouvoir ecrire un champ arbitraire du personnage.
const EFFET_GRANDEURS_PJ = ['hp', 'moral', 'pa', 'pop', 'inf'];
const EFFET_GRANDEURS_STATS = ['INT', 'CHA', 'VOL', 'PER', 'DUP', 'ENT'];
const EFFET_GRANDEURS_INDICES = ['isn', 'ie', 'social', 'piete', 'moral_ville'];

function grandeurEffetAutorisee(cible, cle) {
  if (cible === 'pj') return EFFET_GRANDEURS_PJ.indexOf(cle) !== -1 || EFFET_GRANDEURS_STATS.indexOf(cle) !== -1;
  if (cible === 'collectif') return EFFET_GRANDEURS_INDICES.indexOf(cle) !== -1;
  return true;                                   // objet / lieu : grandeurs propres au sous-systeme
}

// Normalise et VALIDE un effet declare. Renvoie null si la declaration est inexploitable --
// mieux vaut un objet sans effet qu'un effet qui ecrit n'importe ou.
function normaliserEffet(decl) {
  if (!decl || typeof decl !== 'object') return null;
  const cible = EFFET_CIBLES.indexOf(decl.cible) !== -1 ? decl.cible : 'pj';
  const nature = EFFET_NATURES.indexOf(decl.nature) !== -1 ? decl.nature : 'instantane';
  const deltas = {};
  Object.keys(decl.deltas || {}).forEach(function (k) {
    if (!grandeurEffetAutorisee(cible, k)) return;
    const v = nombreSur(decl.deltas[k], 0);
    if (v !== 0) deltas[k] = v;
  });
  const dureeMs = Math.max(0, Math.floor(nombreSur(decl.dureeMs, 0)));
  if (nature === 'temporaire' && dureeMs <= 0) return null;   // un temporaire sans duree n'existe pas
  if (Object.keys(deltas).length === 0 && !texteSur(decl.capacite)) return null;
  return {
    cle: texteSur(decl.cle) || ('effet_' + cible),
    cible: cible, nature: nature, deltas: deltas,
    dureeMs: nature === 'temporaire' ? dureeMs : 0,
    capacite: texteSur(decl.capacite),           // effet non chiffre : 'ouvre_serrure', 'lecture'...
    libelle: texteSur(decl.libelle)
  };
}

// ---------------------------------------------------------------------------
// EFFETS TEMPORAIRES ACTIFS
// ---------------------------------------------------------------------------
// L'audit a montre la faiblesse de l'existant : bonus purges uniquement au Dormir, cote client,
// donc conserves indefiniment par un joueur qui ne dort pas ; et deux horloges concurrentes
// (state.day, propre a chaque joueur, et Date.now()).
//
// Le nouveau moteur n'utilise QUE l'horloge reelle. Un effet porte sa date d'expiration absolue :
// il est mort quand l'heure est passee, que le joueur dorme, se connecte ou non. Aucun balayage
// n'est necessaire pour que l'expiration soit vraie -- le nettoyage n'est qu'une hygiene.
//
// NON-CUMUL : un meme effet (meme cle) ne s'empile jamais avec lui-meme. Par defaut on REFUSE la
// nouvelle consommation plutot que de gaspiller l'objet du joueur -- le cahier des charges est
// explicite. Des effets de cles differentes coexistent sans contrainte.

function effetsActifs(liste, maintenantMs) {
  const t = nombreSur(maintenantMs, 0);
  return (Array.isArray(liste) ? liste : []).filter(function (e) {
    return e && nombreSur(e.expireA, 0) > t;
  });
}

function effetActifPourCle(liste, cle, maintenantMs) {
  const c = texteSur(cle);
  if (!c) return null;
  return effetsActifs(liste, maintenantMs).find(function (e) { return e.cle === c; }) || null;
}

// Peut-on consommer maintenant ? Refus explicite si le meme effet court deja.
function verdictConsommationEffet(liste, effet, maintenantMs) {
  const e = normaliserEffet(effet);
  if (!e) return { ok: false, raison: 'effet_invalide' };
  if (e.nature !== 'temporaire') return { ok: true, raison: null, effet: e };
  const dejaActif = effetActifPourCle(liste, e.cle, maintenantMs);
  if (dejaActif) {
    return { ok: false, raison: 'effet_deja_actif',
             resteMs: Math.max(0, nombreSur(dejaActif.expireA, 0) - nombreSur(maintenantMs, 0)) };
  }
  return { ok: true, raison: null, effet: e };
}

// Pose l'effet. Pure : renvoie la NOUVELLE liste. Purge au passage ce qui a expire -- l'hygiene
// se fait a l'ecriture, jamais par une tache de fond dont l'absence changerait le resultat.
function appliquerEffetTemporaire(liste, effet, maintenantMs) {
  const v = verdictConsommationEffet(liste, effet, maintenantMs);
  if (!v.ok) return { liste: Array.isArray(liste) ? liste : [], applique: false, raison: v.raison };
  if (v.effet.nature !== 'temporaire') {
    return { liste: effetsActifs(liste, maintenantMs), applique: true, raison: null, effet: v.effet };
  }
  const actifs = effetsActifs(liste, maintenantMs);
  return {
    liste: actifs.concat([{
      cle: v.effet.cle, deltas: v.effet.deltas, capacite: v.effet.capacite,
      libelle: v.effet.libelle, cible: v.effet.cible,
      poseA: nombreSur(maintenantMs, 0),
      expireA: nombreSur(maintenantMs, 0) + v.effet.dureeMs
    }]),
    applique: true, raison: null, effet: v.effet
  };
}

// Somme des bonus temporaires actifs pour une grandeur donnee. C'est ce que lira l'affichage, et
// plus tard les formules -- une seule porte, pour qu'un cap global puisse un jour s'y poser.
function bonusTemporaire(liste, grandeur, maintenantMs) {
  return effetsActifs(liste, maintenantMs).reduce(function (s, e) {
    return s + nombreSur((e.deltas || {})[grandeur], 0);
  }, 0);
}

function capaciteTemporaireActive(liste, capacite, maintenantMs) {
  const c = texteSur(capacite);
  if (!c) return false;
  return effetsActifs(liste, maintenantMs).some(function (e) { return e.capacite === c; });
}

// ---------------------------------------------------------------------------
// PREREQUIS ET ASSOCIATIONS
// ---------------------------------------------------------------------------
// Moteur generique : X x objet A + Y x objet B + contexte -> usage.
// Il remplace les `if` par produit : une association est une DONNEE, pas du code.
//
//   composants : [{ref, quantite, consomme}]  -- ref = id de reference, jamais un exemplaire
//   contexte   : { lieu?, famille?, capaciteRequise? }
//   resultat   : { effet?, produit?, capacite? }
//   visibilite : le cahier des charges tranche -- les possibilites importantes doivent etre
//                LISIBLES. Une association porte donc sa description et son conseil commercial.

function normaliserComposant(c) {
  if (!c || typeof c !== 'object') return null;
  const ref = texteSur(c.ref);
  if (!ref) return null;
  return { ref: ref, quantite: Math.max(1, Math.floor(nombreSur(c.quantite, 1))),
           consomme: c.consomme !== false };      // consomme par defaut
}

function normaliserAssociation(decl) {
  if (!decl || typeof decl !== 'object') return null;
  const id = texteSur(decl.id);
  if (!id) return null;
  const composants = (Array.isArray(decl.composants) ? decl.composants : [])
    .map(normaliserComposant).filter(Boolean);
  if (composants.length === 0) return null;
  return {
    id: id,
    libelle: texteSur(decl.libelle) || id,
    description: texteSur(decl.description),
    conseil: texteSur(decl.conseil),             // ce que le referent du commerce peut expliquer
    composants: composants,
    contexte: decl.contexte && typeof decl.contexte === 'object' ? decl.contexte : {},
    resultat: decl.resultat && typeof decl.resultat === 'object' ? decl.resultat : {},
    legale: decl.legale !== false,
    tracable: decl.tracable === true
  };
}

// Quantite d'une reference reellement detenue. Un exemplaire compte pour 1 ; un empilable compte
// sa quantite.
function quantiteDetenue(inventaire, ref) {
  const r = texteSur(ref);
  if (!r) return 0;
  return (Array.isArray(inventaire) ? inventaire : []).reduce(function (s, o) {
    if (!o) return s;
    const idObjet = texteSur(o.id) || texteSur(o.stackKey);
    if (idObjet !== r) return s;
    return s + (estIndividualise(o) ? 1 : Math.max(0, Math.floor(nombreSur(o.qty, 1))));
  }, 0);
}

// Verdict d'une association : tout ce qui manque est NOMME, pour que l'interface puisse le dire
// au joueur au lieu d'un refus opaque.
function verdictAssociation(association, inventaire, contexte) {
  const a = normaliserAssociation(association);
  if (!a) return { ok: false, raison: 'association_invalide' };
  const ctx = contexte || {};

  if (a.contexte.famille && ctx.famille !== a.contexte.famille) {
    return { ok: false, raison: 'contexte_famille', attendu: a.contexte.famille };
  }
  if (a.contexte.lieu && ctx.lieu !== a.contexte.lieu) {
    return { ok: false, raison: 'contexte_lieu', attendu: a.contexte.lieu };
  }
  if (a.contexte.capaciteRequise && !capaciteTemporaireActive(ctx.effetsActifs, a.contexte.capaciteRequise, ctx.maintenantMs)) {
    return { ok: false, raison: 'capacite_absente', attendu: a.contexte.capaciteRequise };
  }

  const manquants = [];
  a.composants.forEach(function (c) {
    const detenu = quantiteDetenue(inventaire, c.ref);
    if (detenu < c.quantite) manquants.push({ ref: c.ref, requis: c.quantite, detenu: detenu });
  });
  if (manquants.length > 0) return { ok: false, raison: 'composants_manquants', manquants: manquants };

  return { ok: true, raison: null, association: a,
           consommes: a.composants.filter(function (c) { return c.consomme; }),
           conserves: a.composants.filter(function (c) { return !c.consomme; }) };
}

// Associations REALISABLES avec ce que l'on detient. C'est ce que le referent d'un Bazar doit
// pouvoir enoncer -- le moteur calcule les faits, le PNJ ne fait que les dire.
function associationsPossibles(registre, inventaire, contexte) {
  return Object.keys(registre || {}).map(function (k) {
    const v = verdictAssociation(registre[k], inventaire, contexte);
    return { id: k, ok: v.ok, raison: v.raison, manquants: v.manquants || null,
             libelle: (registre[k] || {}).libelle || k,
             conseil: (registre[k] || {}).conseil || null };
  });
}

// Ce qui COMPLETERAIT l'assortiment : les associations a un seul composant manquant. C'est le
// conseil commercial le plus utile qu'un referent puisse donner a un proprietaire de Bazar.
function referencesQuiCompleteraient(registre, inventaire, contexte) {
  const manque = {};
  associationsPossibles(registre, inventaire, contexte).forEach(function (a) {
    if (a.ok || !a.manquants || a.manquants.length !== 1) return;
    const m = a.manquants[0];
    if (!manque[m.ref]) manque[m.ref] = { ref: m.ref, debloque: [] };
    manque[m.ref].debloque.push(a.libelle);
  });
  return Object.keys(manque).map(function (k) { return manque[k]; });
}

// ---------------------------------------------------------------------------
// INSTALLATION DANS UN LIEU
// ---------------------------------------------------------------------------
// Un objet durable peut quitter l'inventaire pour etre POSE quelque part. Il n'est alors plus
// transportable, mais il agit : effet permanent, prerequis pour une association, piece d'une
// collection.
//
// Le lieu porte ses installations ; l'objet installe garde son identite complete, de sorte qu'un
// retrait le rende tel qu'il etait -- un tableau decroche reste le meme tableau.

function estInstallable(objet) {
  return !!(objet && objet.installation && typeof objet.installation === 'object'
            && objet.installation.installable === true);
}

function verdictInstallation(objet, installationsLieu, capaciteLieu) {
  if (!estInstallable(objet)) return { ok: false, raison: 'non_installable' };
  const posees = Array.isArray(installationsLieu) ? installationsLieu : [];
  const cap = Math.max(0, Math.floor(nombreSur(capaciteLieu, 0)));
  if (cap > 0 && posees.length >= cap) return { ok: false, raison: 'lieu_sature', capacite: cap };
  if (estExemplaire(objet) && posees.some(function (p) {
        return p && p.exemplaire && p.exemplaire.id === objet.exemplaire.id; })) {
    return { ok: false, raison: 'deja_installe' };
  }
  return { ok: true, raison: null };
}

// Effets cumules des objets installes dans un lieu. Un lieu ne "produit" rien de lui-meme : il
// n'est que la somme de ce qu'on y a pose.
function effetsDuLieu(installationsLieu) {
  const total = {};
  (Array.isArray(installationsLieu) ? installationsLieu : []).forEach(function (o) {
    const e = normaliserEffet((o && o.effets) ? o.effets.installe : null);
    if (!e) return;
    Object.keys(e.deltas).forEach(function (k) { total[k] = nombreSur(total[k], 0) + e.deltas[k]; });
  });
  return total;
}

// ---------------------------------------------------------------------------
// COLLECTIONS ET SYNERGIES
// ---------------------------------------------------------------------------
// Le cahier des charges est net : le meuble seul ne doit pas creer le gros bonus. Une collection
// vaut par ce qu'elle REUNIT, et le support n'est qu'un prerequis.
//
//   support   : reference qui doit etre installee pour que la collection compte
//   pieces    : references qui comptent comme pieces
//   paliers   : [{ seuil, effet }] -- l'effet du palier le plus haut atteint, jamais leur somme

function verdictCollection(collection, installationsLieu, inventaire) {
  const c = collection || {};
  const support = texteSur(c.support);
  const posees = Array.isArray(installationsLieu) ? installationsLieu : [];
  if (support && !posees.some(function (o) { return texteSur(o && o.id) === support; })) {
    return { ok: false, raison: 'support_absent', support: support, pieces: 0 };
  }
  const refs = Array.isArray(c.pieces) ? c.pieces : [];
  // Une piece compte si elle est POSEE dans le lieu, ou detenue quand la collection l'admet.
  const compteDetenues = c.comptePossession === true;
  const pieces = refs.reduce(function (s, ref) {
    const dansLieu = posees.filter(function (o) { return texteSur(o && o.id) === ref; }).length;
    return s + dansLieu + (compteDetenues ? quantiteDetenue(inventaire, ref) : 0);
  }, 0);

  const paliers = (Array.isArray(c.paliers) ? c.paliers : [])
    .slice().sort(function (a, b) { return nombreSur(b.seuil, 0) - nombreSur(a.seuil, 0); });
  const atteint = paliers.find(function (p) { return pieces >= Math.max(1, nombreSur(p.seuil, 1)); });
  if (!atteint) return { ok: false, raison: 'seuil_non_atteint', pieces: pieces };
  return { ok: true, raison: null, pieces: pieces, palier: atteint.seuil,
           effet: normaliserEffet(atteint.effet) };
}

// ---------------------------------------------------------------------------
// FICHE OFFICIELLE — RENDU (L2)
// ---------------------------------------------------------------------------
// PROTECTION DE L'ACHETEUR. Un commercant peut mentir en RP sur le nom et la
// description de ce qu'il vend ; la fiche officielle dit la verite mecanique.
//
// SEPARATION STRICTE DES RESPONSABILITES :
//   - le SERVEUR est autoritaire sur le CONTENU (RPC objet_fiche_officielle) ;
//   - ce fichier ne fait que la PRESENTATION : traduire des cles techniques en
//     libelles francais. Il n'invente aucun effet et n'en deduit aucun.
// Une cle inconnue de la table de libelles est affichee TELLE QUELLE : mieux vaut
// un intitule technique visible qu'une formulation devinee.
//
// Contrat de ce module respecte : fonctions PURES, aucun DOM, aucun reseau.

// Libelles de presentation. Aucune valeur, aucun effet : uniquement des mots.
const FICHE_LIBELLES_EFFETS = {
  hp: 'Santé', moral: 'Moral', pa: 'Points d\'action', ent: 'ENT', inf: 'INF',
  pop: 'POP', dis: 'DIS',
  pa_differe: 'PA au prochain sommeil', pa_lendemain: 'PA le lendemain',
  bonus_combat_feu: 'Bonus de combat au tir', bonus_detection: 'Bonus de détection',
  ferme_batiment_jours: 'Ferme le bâtiment (jours)',
  blesse_presents: 'Blesse les personnes présentes',
  voix_pnj: 'Voix d\'un PNJ', pop_cible: 'POP de la cible', inf_cible: 'INF de la cible',
  moral_lecteur: 'Moral du lecteur', moral_expediteur: 'Moral de l\'expéditeur',
  plafond_quotidien_lecteur: 'Plafond quotidien (lecteur)',
  plafond_quotidien_expediteur: 'Plafond quotidien (expéditeur)',
  pa_si_frais: 'PA si le produit est frais', pa_si_perime: 'PA si le produit est périmé',
  fraicheur_jours_reels: 'Fraîcheur (jours réels)',
  max_par_jour: 'Maximum par jour', plafond_pa: 'Plafond de PA',
  usage_unique: 'Usage unique',
  absorption_tir_probabilite: 'Chance d\'absorber un tir',
  une_seule_fois: 'Une seule fois', garantit_pa_minimum: 'Garantit au minimum (PA)',
  capacite_personnes: 'Capacité (personnes)',
  pa_bivouac_par_soldat: 'PA de bivouac par soldat',
  pa_repos_section: 'PA au repos de section', pa_repos_nocturne_pj: 'PA au repos nocturne',
  consommee: 'Consommée à l\'usage', usure: 'Usure',
  camouflage_groupe: 'Camouflage du groupe',
  non_cumulable: 'Non cumulable', condition: 'Condition', plancher: 'Plancher',
  pa_formule: 'Calcul', pa_min: 'PA minimum', pa_max: 'PA maximum'
};

const FICHE_LIBELLES_CAPACITES = {
  transmettre_ordre_collectif_a_distance: 'Transmettre un ordre collectif à distance',
  abriter_bivouac: 'Abriter un bivouac',
  reposer_section: 'Faire reposer une section',
  observer_secteur: 'Observer un secteur',
  soigner_co_present: 'Soigner une personne présente',
  absorber_tir_en_bataille: 'Absorber un tir en bataille',
  nourrir_soldat_pnj: 'Nourrir des soldats'
};

const FICHE_LIBELLES_REGIMES = {
  libre: 'Libre', reglemente: 'Réglementé',
  illegal: 'Illégal', institutionnel: 'Institutionnel'
};

function ficheEchapper(v) {
  return String(v == null ? '' : v)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// Valeur lisible : un booleen devient Oui/Non, un nombre positif recoit son signe.
function ficheValeurLisible(cle, valeur) {
  if (valeur === true) return 'Oui';
  if (valeur === false) return 'Non';
  if (valeur === null) return 'Aucune';
  if (typeof valeur === 'number') {
    const signee = ['hp','moral','pa','ent','inf','pop','dis','pa_differe','pa_lendemain',
                    'voix_pnj','pop_cible','inf_cible','moral_lecteur','moral_expediteur',
                    'pa_si_frais','pa_si_perime','bonus_combat_feu','bonus_detection',
                    'camouflage_groupe','pa_bivouac_par_soldat'];
    return (signee.indexOf(cle) !== -1 && valeur > 0 ? '+' : '') + valeur;
  }
  return String(valeur);
}

// Lignes d'effets prêtes à afficher. PURE : rend un tableau, jamais du HTML.
function ficheLignesEffets(effets) {
  if (!effets || typeof effets !== 'object') return [];
  return Object.keys(effets).map(function (k) {
    return { libelle: FICHE_LIBELLES_EFFETS[k] || k, valeur: ficheValeurLisible(k, effets[k]) };
  });
}

// Bloc OFFICIEL. `fiche` est le retour brut de la RPC objet_fiche_officielle.
// fiche.resolu === false  ->  objet hors catalogue : AUCUN generique de repli n'est
// affiche, et rien n'est invente.
function ficheOfficielleHtml(fiche) {
  const cadre = 'border:1px solid #2a2010;background:#0b0a05;padding:.6rem .7rem;margin-top:.7rem';
  const titre = '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.45rem">'
              + '<i class="ti ti-certificate" style="font-size:.8rem"></i> FICHE OFFICIELLE — INFORMATIONS SYSTÈME</div>';

  if (!fiche || fiche.resolu !== true) {
    return '<div style="' + cadre + '">' + titre
      + '<div style="font-size:.8rem;color:#8a8060;line-height:1.5">Cet objet ne figure pas au catalogue officiel des commerces. '
      + 'Ses propriétés ne sont pas garanties par une fiche système.</div></div>';
  }

  const ligne = function (l, v) {
    return '<div style="display:flex;gap:.5rem;font-size:.8rem;line-height:1.55">'
         + '<span style="color:#6a5a30;min-width:8.5rem;flex-shrink:0">' + ficheEchapper(l) + '</span>'
         + '<span style="color:#c0b090">' + ficheEchapper(v) + '</span></div>';
  };

  let h = '<div style="' + cadre + '">' + titre;

  h += ligne(fiche.est_service ? 'Prestation' : 'Objet', fiche.generique);
  if (fiche.variante) h += ligne('Configuration', fiche.variante);
  h += ligne('Famille', fiche.famille);
  if (Array.isArray(fiche.types) && fiche.types.length) {
    h += ligne(fiche.types.length > 1 ? 'Types de commerce' : 'Type de commerce', fiche.types.join(', '));
  }
  if (fiche.regime && fiche.regime !== 'libre') {
    h += ligne('Régime', FICHE_LIBELLES_REGIMES[fiche.regime] || fiche.regime);
  }

  // « Aucun effet » est AFFICHE EXPLICITEMENT : c'est la garantie donnee a l'acheteur.
  // On s'appuie sur le drapeau `aucun_effet` calcule PAR LE SERVEUR, qui tient compte des
  // effets ET des capacites. Un objet sans delta mais porteur d'une capacite (la radio
  // militaire, par exemple) ne doit pas afficher « Effets : Aucun » a cote de ce qu'il
  // permet de faire : ce serait exact sur les chiffres et trompeur sur le fond.
  const lignes = ficheLignesEffets(fiche.effets);
  if (fiche.aucun_effet === true) {
    h += '<div style="margin-top:.4rem;font-size:.82rem;color:#8a8060"><b style="color:#a09070">Effets : Aucun</b></div>';
  } else if (lignes.length > 0) {
    h += '<div style="margin-top:.45rem;font-size:.7rem;letter-spacing:.08em;color:#6a5a30;font-family:Bebas Neue,sans-serif">EFFETS RÉELS</div>';
    lignes.forEach(function (l) { h += ligne(l.libelle, l.valeur); });
  }

  if (Array.isArray(fiche.capacites) && fiche.capacites.length) {
    h += '<div style="margin-top:.45rem;font-size:.7rem;letter-spacing:.08em;color:#6a5a30;font-family:Bebas Neue,sans-serif">CE QU\'IL PERMET</div>';
    fiche.capacites.forEach(function (c) {
      h += '<div style="font-size:.8rem;color:#c0b090;line-height:1.55">• ' + ficheEchapper(FICHE_LIBELLES_CAPACITES[c] || c) + '</div>';
    });
  }

  // Proprietes d'usage : affichees UNIQUEMENT quand elles portent une information.
  let usage = '';
  if (fiche.consommable)   usage += ligne('Consommable', 'Oui');
  if (fiche.equipable)     usage += ligne('Peut être affecté', 'Oui');
  if (fiche.encombrement)  usage += ligne('Encombrement', fiche.encombrement + ' emplacement(s)');
  if (fiche.durabilite)    usage += ligne('Durabilité', JSON.stringify(fiche.durabilite));
  if (fiche.conditions)    usage += ligne('Conditions', JSON.stringify(fiche.conditions));
  if (fiche.contraintes)   usage += ligne('Contraintes', JSON.stringify(fiche.contraintes));
  if (usage) {
    h += '<div style="margin-top:.45rem;font-size:.7rem;letter-spacing:.08em;color:#6a5a30;font-family:Bebas Neue,sans-serif">USAGE</div>' + usage;
  }

  h += '</div>';
  return h;
}

// Bloc COMMERCIAL / RP. N'affiche que ce qui existe reellement : un produit
// historique n'a pas encore les champs d'une future reference personnalisee, et
// aucun champ absent n'est comble.
function ficheCommercialeHtml(infos) {
  const i = infos || {};
  const cadre = 'border:1px solid #2a2010;background:#0f0d05;padding:.6rem .7rem';
  let h = '<div style="' + cadre + '">'
        + '<div style="font-family:Bebas Neue,sans-serif;font-size:.68rem;letter-spacing:.12em;color:#8a6a20;margin-bottom:.45rem">'
        + '<i class="ti ti-tag" style="font-size:.8rem"></i> PRÉSENTATION COMMERCIALE</div>';
  if (texteSur(i.nom))       h += '<div style="font-family:Playfair Display,serif;font-size:.98rem;color:#e0d5b8">' + ficheEchapper(i.nom) + '</div>';
  if (texteSur(i.description)) h += '<div style="font-size:.82rem;color:#a0a080;line-height:1.55;margin-top:.25rem">' + ficheEchapper(i.description) + '</div>';
  if (i.prix != null)        h += '<div style="font-size:.85rem;color:#C9A84C;margin-top:.35rem">' + Number(i.prix).toLocaleString('fr-FR') + ' ' + ficheEchapper(i.devise || 'FR') + '</div>';
  if (texteSur(i.vendeur))   h += '<div style="font-size:.76rem;color:#6a5a30;margin-top:.2rem">Vendu par ' + ficheEchapper(i.vendeur) + '</div>';
  if (i.stock != null)       h += '<div style="font-size:.76rem;color:#6a5a30">Stock : ' + Number(i.stock) + '</div>';
  h += '</div>';
  return h;
}
