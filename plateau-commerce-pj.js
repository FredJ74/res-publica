// =====================
// PLATEAU-COMMERCE-PJ.JS — INTERFACE DE LA VERTICALE COMMERCE PJ (C5)
// =====================
// LE NAVIGATEUR N'EST PAS LE MOTEUR. Ce fichier affiche, recueille une intention,
// appelle une primitive serveur, affiche le resultat. Il ne calcule aucun prix,
// aucun cout, aucun plafond, aucun stock, aucun effet : tout cela vient du
// serveur, qui reste seul juge.
//
// EN PARTICULIER, ET C'EST LE POINT LE PLUS IMPORTANT : aucune valeur mecanique
// n'est jamais RENVOYEE au serveur comme autorite. « Produire » n'envoie que
// l'identifiant de la reference ; « Acheter » n'envoie que la reference et une
// quantite. Un navigateur modifie ne peut donc rien obtenir de plus qu'un
// navigateur honnete.
//
// PAS DE CAS PARTICULIER PAR PRODUIT. L'interface lit generique -> recettes
// systeme -> proprietes officielles. Ajouter demain une recette a un generique la
// fera apparaitre ici sans qu'une seule ligne de ce fichier change -- c'est le
// critere de reussite du lot.
//
// LE LOCAL N'EST PAS LE FONDS. Un local locatif donne acces au commerce qui s'y
// exploite ; il ne porte jamais ses donnees. Le seul lien est le bail, qui
// designe le fonds par son identifiant.

// ---------------------------------------------------------------------------
// LIBELLES
// ---------------------------------------------------------------------------
// Meme convention que plateau-entrepots.js, seul ecran du plateau dont les
// libelles sont extraits : table locale plus accesseur unique. i18next n'est PAS
// charge par plateau.html (verifie : aucune occurrence) -- le jour ou il le sera,
// il suffira de deplacer cette table sous la cle racine `commercepj.` et de
// retirer le repli, sans qu'aucun appelant change.
const I18N_COMMERCE_PJ_FR = {
  'commercepj.titre.gestion':        "Mon commerce",
  'commercepj.titre.boutique':       "Boutique",
  'commercepj.titre.creation':       "Installer un commerce",
  'commercepj.titre.produit':        "Fiche produit",
  'commercepj.titre.reference':      "Nouvelle référence",

  'commercepj.local.libre':          "Ce local est libre. Louez-le pour pouvoir y installer un commerce.",
  'commercepj.local.pasLocataire':   "Ce local est loué par quelqu'un d'autre, et aucun commerce n'y est encore ouvert.",
  'commercepj.local.aucunCommerce':  "Aucun commerce n'est exploité ici pour l'instant.",
  'commercepj.local.vousLouez':      "Vous louez ce local. Vous pouvez y installer votre commerce.",

  'commercepj.creer.enseigne':       "Nom de votre commerce",
  'commercepj.creer.enseignePh':     "Manga Paradise",
  'commercepj.creer.apport':         "Apport de départ (facultatif)",
  'commercepj.creer.bouton':         "Installer le commerce",
  'commercepj.creer.typesTitre':     "Quelles activités exercez-vous ?",
  'commercepj.creer.typesAide':      "Vos activités déterminent ce que vous pourrez vendre.",
  'commercepj.creer.typesValider':   "Valider mes activités",
  'commercepj.creer.typesMax':       "Vous pouvez choisir jusqu'à {n} activité(s).",

  'commercepj.gestion.caisse':       "Caisse",
  'commercepj.gestion.local':        "Local",
  'commercepj.gestion.activites':    "Activités",
  'commercepj.gestion.aucuneActivite': "Aucune activité déclarée. Choisissez-en avant de créer un produit.",
  'commercepj.gestion.produits':     "Mes produits",
  'commercepj.gestion.aucunProduit': "Vous ne proposez encore aucun produit.",
  'commercepj.gestion.nouveau':      "Créer un produit",
  'commercepj.gestion.modifierActivites': "Modifier mes activités",

  'commercepj.ref.enVente':          "En vente",
  'commercepj.ref.retire':           "Retiré de la vente",
  'commercepj.ref.rupture':          "Rupture de stock",
  'commercepj.ref.stock':            "En stock",
  'commercepj.ref.cout':             "Coût de revient",
  'commercepj.ref.prix':             "Prix de vente",
  'commercepj.ref.plafond':          "Prix maximal autorisé",
  'commercepj.ref.sansPrix':         "Prix non fixé",
  'commercepj.ref.produire':         "Produire",
  'commercepj.ref.tarifer':          "Fixer le prix",
  'commercepj.ref.mettreEnVente':    "Mettre en vente",
  'commercepj.ref.retirer':          "Retirer de la vente",
  'commercepj.ref.unite':            "l'unité",

  'commercepj.nouvelle.generique':   "Que voulez-vous vendre ?",
  'commercepj.nouvelle.generiqueAide': "Choisissez la nature de votre produit. C'est elle qui détermine ce qu'il est réellement.",
  'commercepj.nouvelle.recette':     "Comment le fabriquez-vous ?",
  'commercepj.nouvelle.recetteAide': "Le mode de fabrication est fixé par le système. Choisissez celui que vous voulez commercialiser.",
  'commercepj.nouvelle.habillage':   "Votre présentation",
  'commercepj.nouvelle.habillageAide': "Le nom et la description sont à vous. Ils n'ont aucun effet sur ce que le produit fait réellement.",
  'commercepj.nouvelle.nom':         "Nom commercial",
  'commercepj.nouvelle.nomPh':       "Porte-clé présidentiel Collector",
  'commercepj.nouvelle.desc':        "Description",
  'commercepj.nouvelle.descPh':      "Édition limitée, numérotée à la main.",
  'commercepj.nouvelle.creer':       "Créer ce produit",
  'commercepj.nouvelle.aucunGenerique': "Vos activités ne donnent accès à aucun produit pour l'instant.",

  'commercepj.recette.necessite':    "Nécessite",
  'commercepj.recette.produit':      "Produit",
  'commercepj.recette.pa':           "point(s) d'action",
  'commercepj.recette.unites':       "unité(s)",
  'commercepj.recette.aucune':       "Ce produit ne se fabrique pas.",

  'commercepj.produire.titre':       "Lancer une fabrication",
  'commercepj.produire.vosStocks':   "Vos matières",
  'commercepj.produire.confirmer':   "Lancer la fabrication",
  'commercepj.produire.fait':        "Fabrication terminée",

  'commercepj.prix.titre':           "Fixer le prix",
  'commercepj.prix.saisie':          "Votre prix",
  'commercepj.prix.valider':         "Valider le prix",
  'commercepj.prix.sansCout':        "Fabriquez d'abord un lot : c'est lui qui établit votre coût de revient, et donc le prix maximal autorisé.",

  'commercepj.boutique.aucun':       "Ce commerce ne propose aucun produit pour l'instant.",
  'commercepj.boutique.tenu':        "Tenu par",
  'commercepj.boutique.voir':        "Voir",
  'commercepj.boutique.acheter':     "Acheter",
  'commercepj.boutique.indisponible': "Indisponible",

  'commercepj.fiche.presentation':   "PRÉSENTATION DU VENDEUR",
  'commercepj.fiche.vente':          "ACHAT",
  'commercepj.fiche.quantite':       "Quantité",
  'commercepj.fiche.achete':         "Achat effectué",
  'commercepj.fiche.recu':           "L'objet vous attend. Il apparaîtra dans votre inventaire.",

  'commercepj.retour.gestion':       "← Retour à mon commerce",
  'commercepj.retour.boutique':      "← Retour à la boutique",

  'commercepj.refus.defaut':                      "L'opération n'a pas abouti. Rien n'a été modifié.",
  'commercepj.refus.pas_proprietaire':            "Ce commerce n'est pas le vôtre.",
  'commercepj.refus.pas_un_fonds_pj':             "Ce n'est pas un commerce de joueur.",
  'commercepj.refus.fonds_absent':                "Ce commerce n'existe pas.",
  'commercepj.refus.fonds_inactif':               "Ce commerce n'est plus exploité.",
  'commercepj.refus.reference_absente':           "Ce produit n'existe pas.",
  'commercepj.refus.reference_inactive':          "Ce produit n'est pas en vente.",
  'commercepj.refus.rupture_de_stock':            "Ce produit est en rupture de stock.",
  'commercepj.refus.stock_insuffisant':           "Il n'y en a pas assez en stock.",
  'commercepj.refus.prix_non_fixe':               "Le prix de ce produit n'a pas été fixé.",
  'commercepj.refus.prix_invalide':               "Ce prix n'est pas valide.",
  'commercepj.refus.prix_au_dessus_du_plafond':   "Ce prix dépasse le maximum autorisé.",
  'commercepj.refus.prix_devenu_hors_plafond':    "Le prix affiché dépasse désormais le maximum autorisé. Le vendeur doit le revoir.",
  'commercepj.refus.cout_de_revient_indisponible':"Aucun coût de revient n'est encore établi pour ce produit.",
  'commercepj.refus.aucun_cout_de_production':    "Aucun lot n'a encore été fabriqué.",
  'commercepj.refus.fonds_insuffisants':          "Vous n'avez pas cette somme.",
  'commercepj.refus.matieres_insuffisantes':      "Il vous manque des matières premières.",
  'commercepj.refus.pa_insuffisants':             "Vous n'avez pas assez de points d'action.",
  'commercepj.refus.cout_matiere_inconnu':        "Le coût d'une matière est inconnu : achetez-en d'abord pour votre commerce.",
  'commercepj.refus.generique_hors_perimetre':    "Vos activités ne permettent pas ce produit.",
  'commercepj.refus.recette_systeme_requise':     "Vous devez choisir un mode de fabrication.",
  'commercepj.refus.recette_hors_generique':      "Ce mode de fabrication ne correspond pas à ce produit.",
  'commercepj.refus.nom_absent':                  "Donnez un nom à votre produit.",
  'commercepj.refus.nom_trop_long':               "Ce nom est trop long (80 caractères maximum).",
  'commercepj.refus.description_trop_longue':     "Cette description est trop longue (400 caractères maximum).",
  'commercepj.refus.trop_de_types':               "Vous avez choisi trop d'activités.",
  'commercepj.refus.type_inconnu':                "Cette activité n'existe pas.",
  'commercepj.refus.local_non_commercial':        "On ne peut pas installer un commerce dans ce local.",
  'commercepj.refus.bail_absent':                 "Vous ne louez pas ce local.",
  'commercepj.refus.pas_titulaire':               "Ce bail n'est pas le vôtre.",
  'commercepj.refus.generique_regime_indetermine':"Ce produit ne peut pas encore être vendu à emporter.",
  'commercepj.refus.generique_est_un_service':    "Ce produit est un service : sa vente n'est pas encore ouverte.",
  // Motifs metier reels que la table ne couvrait pas : ils retombaient donc sur la phrase
  // generique, ce qui rendait un vrai refus du serveur indiscernable d'une panne (28/09/2026).
  'commercepj.refus.parametres_invalides':        "Cette demande est incomplète. Rouvrez l'écran et recommencez.",
  'commercepj.refus.generique_sans_recette':      "Ce produit ne se fabrique pas : il n'a aucun mode de fabrication.",
  'commercepj.refus.recette_inexistante':         "Ce mode de fabrication n'existe pas.",
  // Echecs de TRANSPORT, nommes par sbRpcVerdict. Ce ne sont pas des regles du jeu : le dire
  // franchement evite de faire croire au joueur que son commerce ou son produit est en faute.
  'commercepj.refus.session_perdue':              "Votre session a expiré. Reconnectez-vous puis réessayez.",
  'commercepj.refus.transport_indisponible':      "Le service n'a pas répondu. Rien n'a été modifié — réessayez.",
  'commercepj.refus.reseau_indisponible':         "Connexion interrompue. Rien n'a été modifié — réessayez.",
  'commercepj.refus.inconnu':                     "Refusé par le serveur ({motif}). Rien n'a été modifié."
};

// Accesseur unique. Aucune chaine visible n'est ecrite ailleurs dans ce fichier.
function tCommercePJ(cle, remplacements) {
  let texte;
  if (typeof i18next !== 'undefined' && i18next.isInitialized && i18next.exists(cle)) {
    texte = i18next.t(cle, remplacements);
  } else {
    texte = I18N_COMMERCE_PJ_FR[cle] || cle;
    if (remplacements) {
      Object.keys(remplacements).forEach(function (k) {
        texte = texte.split('{' + k + '}').join(String(remplacements[k]));
      });
    }
  }
  return texte;
}

// Traduit un refus serveur. Le code interne reste disponible pour le diagnostic,
// mais il n'est jamais montre au joueur.
function commercePjRefus(v) {
  if (!v) return tCommercePJ('commercepj.refus.defaut');
  const r = v.raison || (v.detail && v.detail.raison);
  const cle = 'commercepj.refus.' + r;
  const texte = tCommercePJ(cle);
  if (texte !== cle) {
    if (r === 'prix_au_dessus_du_plafond' && v.maximum != null) {
      return texte + ' ' + commercePjMontant(v.maximum) + ' ' + commercePjDevise() + ' ' + tCommercePJ('commercepj.ref.unite') + '.';
    }
    if (r === 'matieres_insuffisantes' && Array.isArray(v.manquantes)) {
      return texte + ' ' + v.manquantes.map(function (m) {
        return commercePjLibelleMatiere(m.matiere) + ' : ' + m.dispo + ' / ' + m.requis;
      }).join(' · ');
    }
    if (r === 'pa_insuffisants' && v.requis != null) return texte + ' (' + v.requis + ' requis)';
    return texte;
  }
  // MOTIF NON TRADUIT (28 septembre 2026). Il retombait jusqu'ici sur « Rien n'a ete modifie »,
  // qui masquait entierement l'information : c'est ainsi qu'un 401 de transport et un vrai refus
  // metier devenaient indiscernables a l'ecran. On nomme desormais le motif -- c'est un code
  // interne court, jamais un message SQL ni une donnee d'autrui -- et on pousse le detail
  // technique en console, la ou il sert au diagnostic sans encombrer le joueur.
  if (r) {
    console.error('[commerce PJ] motif de refus non traduit : ' + r, v);
    return tCommercePJ('commercepj.refus.inconnu', { motif: String(r) });
  }
  return tCommercePJ('commercepj.refus.defaut');
}

// ---------------------------------------------------------------------------
// OUTILS D'AFFICHAGE
// ---------------------------------------------------------------------------
function commercePjEchapper(s) {
  if (typeof escapeHtmlText === 'function') return escapeHtmlText(String(s == null ? '' : s));
  return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  });
}

function commercePjDevise() {
  return (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country] && COUNTRIES[state.country].cur) || 'FR';
}

// Arrondi d'AFFICHAGE seulement. Le serveur garde la precision complete : ce
// nombre n'est jamais renvoye ni recalcule comme autorite.
function commercePjMontant(n) {
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return (Math.round(v * 100) / 100).toLocaleString('fr-FR', { maximumFractionDigits: 2 });
}

function commercePjLibelleMatiere(cle) {
  if (typeof RESSOURCES_ECONOMIE !== 'undefined' && RESSOURCES_ECONOMIE[cle] && RESSOURCES_ECONOMIE[cle].label) {
    return RESSOURCES_ECONOMIE[cle].label;
  }
  return String(cle || '').replace(/_/g, ' ');
}

function commercePjModale(titre, html) {
  const t = document.getElementById('postes-modal-title');
  const b = document.getElementById('postes-body');
  if (!t || !b) return;
  t.textContent = titre;
  b.innerHTML = html;
  document.getElementById('modal-postes').classList.add('open');
}

function commercePjChargement(titre) {
  commercePjModale(titre, '<div style="padding:1.2rem;color:#8a8060;font-style:italic">…</div>');
}

function commercePjBouton(onclick, libelle, primaire, desactive) {
  const bord = desactive ? '#2a2620' : (primaire ? '#8a6a20' : '#3a3a30');
  const couleur = desactive ? '#5a5448' : (primaire ? '#E8C97A' : '#c0b090');
  return '<button ' + (desactive ? 'disabled ' : 'onclick="' + onclick + '" ') +
    'style="padding:.45rem .8rem;font-family:Bebas Neue,sans-serif;font-size:.78rem;letter-spacing:.07em;' +
    'border:1px solid ' + bord + ';background:transparent;color:' + couleur + ';' +
    'cursor:' + (desactive ? 'default' : 'pointer') + '">' + commercePjEchapper(libelle) + '</button>';
}

function commercePjLigne(label, valeur) {
  return '<div style="display:flex;justify-content:space-between;gap:1rem;padding:.2rem 0;font-size:.84rem">' +
    '<span style="color:#8a8060">' + commercePjEchapper(label) + '</span>' +
    '<span style="color:#e0d8c0;text-align:right">' + valeur + '</span></div>';
}

// ---------------------------------------------------------------------------
// CONTEXTE : DU LOCAL AU FONDS
// ---------------------------------------------------------------------------
// Le bail est le seul lien. On ne recopie jamais les donnees du fonds dans le
// batiment, et on ne devine jamais un fonds depuis une piece.
async function commercePjContexte() {
  const pays = state.country, ville = state.currentCity;
  const batiment = state.currentBuilding, piece = state.currentRoom;
  const bailId = sbBailIdDeLocal(pays, batiment, piece, ville);
  const bail = await sbGetBail(bailId).catch(function () { return null; });
  const moi = state.char && state.char.name;
  let fonds = null;
  if (bail && bail.fondsId && typeof sbGetFonds === 'function') {
    fonds = await sbGetFonds(bail.fondsId).catch(function () { return null; });
  }
  const proprio = fonds && fonds.proprietaire;
  return {
    bailId: bailId, bail: bail, fondsId: bail && bail.fondsId, fonds: fonds, moi: moi,
    jeLoue: !!(bail && bail.locataire === moi),
    jeSuisProprietaire: !!(proprio && (proprio === moi || proprio === 'pj:' + moi))
  };
}

// ---------------------------------------------------------------------------
// POINT D'ENTREE UNIQUE
// ---------------------------------------------------------------------------
// Un seul ordre sur le local. L'ecran decide : local libre, installation, gestion
// ou boutique. Le joueur n'a pas a savoir lequel choisir.
async function ouvrirCommercePJ() {
  commercePjChargement(tCommercePJ('commercepj.titre.boutique'));
  const ctx = await commercePjContexte();
  if (ctx.fonds && ctx.jeSuisProprietaire) return commercePjEcranGestion(ctx);
  if (ctx.fonds)                           return commercePjEcranBoutique(ctx);
  if (ctx.jeLoue)                          return commercePjEcranInstaller(ctx);

  let html = '<div style="padding:1.1rem">';
  html += '<p style="color:#c0b090;font-size:.9rem;line-height:1.6">' +
    commercePjEchapper(ctx.bail ? tCommercePJ('commercepj.local.pasLocataire')
                                : tCommercePJ('commercepj.local.libre')) + '</p></div>';
  commercePjModale(tCommercePJ('commercepj.titre.boutique'), html);
}

// ---------------------------------------------------------------------------
// INSTALLATION D'UN COMMERCE DANS UN LOCAL DEJA LOUE
// ---------------------------------------------------------------------------
// C1 fournissait la primitive sans interface. On branche la plus petite qui
// permette de comprendre : vous louez, vous pouvez installer, voici le nom.
// Aucun systeme immobilier n'est ajoute -- le bail existe deja.
function commercePjEcranInstaller(ctx) {
  let html = '<div style="padding:1.1rem">';
  html += '<p style="color:#c0b090;font-size:.88rem;line-height:1.6;margin-bottom:1rem">' +
    commercePjEchapper(tCommercePJ('commercepj.local.vousLouez')) + '</p>';
  html += '<label style="display:block;font-size:.78rem;color:#8a8060;margin-bottom:.3rem">' +
    commercePjEchapper(tCommercePJ('commercepj.creer.enseigne')) + '</label>';
  html += '<input id="cpj-enseigne" type="text" maxlength="60" placeholder="' +
    commercePjEchapper(tCommercePJ('commercepj.creer.enseignePh')) + '" ' +
    'style="width:100%;padding:.5rem;background:#0e0c08;border:1px solid #3a3a30;color:#e0d8c0;margin-bottom:.8rem"/>';
  html += '<label style="display:block;font-size:.78rem;color:#8a8060;margin-bottom:.3rem">' +
    commercePjEchapper(tCommercePJ('commercepj.creer.apport')) + ' (' + commercePjDevise() + ')</label>';
  html += '<input id="cpj-apport" type="number" min="0" step="1" value="0" ' +
    'style="width:100%;padding:.5rem;background:#0e0c08;border:1px solid #3a3a30;color:#e0d8c0;margin-bottom:1rem"/>';
  html += commercePjBouton('commercePjInstaller()', tCommercePJ('commercepj.creer.bouton'), true);
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.titre.creation'), html);
}

async function commercePjInstaller() {
  const ctx = await commercePjContexte();
  if (!ctx.jeLoue) { showToast('—', commercePjRefus({ raison: 'pas_titulaire' }), false); return; }
  const enseigne = (document.getElementById('cpj-enseigne') || {}).value || '';
  const apport = Math.max(0, Math.floor(Number((document.getElementById('cpj-apport') || {}).value) || 0));
  const id = (typeof nouvelIdFonds === 'function')
    ? nouvelIdFonds(state.country, Date.now(), Math.floor(Math.random() * 1000000))
    : 'fonds-' + Date.now().toString(36);
  const r = await sbCreerFondsCommerce(state.char.name, ctx.bailId, id, apport, enseigne);
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  if (typeof addJournalEntry === 'function') {
    addJournalEntry('Commerce installé : ' + (enseigne || 'Fonds de commerce') + '.', 'event-good');
  }
  if (typeof updateUI === 'function') updateUI();
  const ctx2 = await commercePjContexte();
  commercePjEcranTypes(ctx2);
}

// ---------------------------------------------------------------------------
// CHOIX DES ACTIVITES
// ---------------------------------------------------------------------------
// Les types viennent du referentiel, jamais d'une liste ecrite dans le HTML : la
// meme interface servira n'importe quel empire. Le plafond vient du serveur.
async function commercePjEcranTypes(ctx) {
  commercePjChargement(tCommercePJ('commercepj.titre.creation'));
  const types = await sbGetCatalogueTypes();
  const actuels = (ctx.fonds && ctx.fonds.typesAutorises) || [];
  let html = '<div style="padding:1.1rem">';
  html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.3rem">' +
    commercePjEchapper(tCommercePJ('commercepj.creer.typesTitre')) + '</div>';
  html += '<p style="color:#8a8060;font-size:.82rem;margin-bottom:.9rem">' +
    commercePjEchapper(tCommercePJ('commercepj.creer.typesAide')) + '</p>';
  html += '<div style="display:flex;flex-direction:column;gap:.35rem;margin-bottom:1rem">';
  types.forEach(function (t) {
    const coche = actuels.indexOf(t.id) !== -1 ? ' checked' : '';
    html += '<label style="display:flex;align-items:center;gap:.5rem;font-size:.86rem;color:#c0b090;cursor:pointer">' +
      '<input type="checkbox" class="cpj-type" value="' + commercePjEchapper(t.id) + '"' + coche + '/>' +
      commercePjEchapper(t.libelle) + '</label>';
  });
  html += '</div>';
  html += commercePjBouton('commercePjValiderTypes()', tCommercePJ('commercepj.creer.typesValider'), true);
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.titre.creation'), html);
}

async function commercePjValiderTypes() {
  const ctx = await commercePjContexte();
  if (!ctx.fonds) { showToast('—', commercePjRefus({ raison: 'fonds_absent' }), false); return; }
  const choisis = Array.prototype.slice.call(document.querySelectorAll('.cpj-type:checked'))
    .map(function (e) { return e.value; });
  const r = await sbFondsDefinirTypes(state.char.name, ctx.fondsId, choisis);
  if (!r || !r.ok) {
    showToast('—', commercePjRefus(r) + (r && r.maximum ? ' ' + tCommercePJ('commercepj.creer.typesMax', { n: r.maximum }) : ''), false);
    return;
  }
  ouvrirCommercePJ();
}

// ---------------------------------------------------------------------------
// ECRAN PROPRIETAIRE
// ---------------------------------------------------------------------------
async function commercePjEcranGestion(ctx) {
  commercePjChargement(tCommercePJ('commercepj.titre.gestion'));
  if (!ctx || !ctx.fonds) ctx = await commercePjContexte();
  const f = ctx.fonds, cur = commercePjDevise();
  const refs = f.references || {};
  const stocks = f.stockReferences || {};
  const cles = Object.keys(refs);

  // Le cout et le plafond viennent du serveur, reference par reference.
  const couts = {};
  for (let i = 0; i < cles.length; i++) {
    couts[cles[i]] = await sbFondsCoutRevientReference(ctx.fondsId, cles[i]).catch(function () { return null; });
  }
  const types = await sbGetCatalogueTypes();
  const libelleType = {};
  types.forEach(function (t) { libelleType[t.id] = t.libelle; });
  const mesTypes = (f.typesAutorises || []).map(function (id) { return libelleType[id] || id; });

  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.05rem;color:#E8C97A;margin-bottom:.5rem">' +
    commercePjEchapper(f.enseigne || '—') + '</div>';
  html += '<div style="border:1px solid #2a2620;padding:.6rem .8rem;margin-bottom:1rem">';
  html += commercePjLigne(tCommercePJ('commercepj.gestion.local'),
    commercePjEchapper((f.implantation && f.implantation.roomId) || '—'));
  html += commercePjLigne(tCommercePJ('commercepj.gestion.activites'),
    mesTypes.length ? commercePjEchapper(mesTypes.join(' · ')) : '<i style="color:#6a6050">—</i>');
  html += commercePjLigne(tCommercePJ('commercepj.gestion.caisse'),
    commercePjMontant(f.caisse || 0) + ' ' + cur);
  html += '</div>';
  html += '<div style="margin-bottom:1rem">' +
    commercePjBouton('commercePjEcranTypes()', tCommercePJ('commercepj.gestion.modifierActivites')) + '</div>';

  html += '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.1em;color:#a09070;font-size:.85rem;margin-bottom:.5rem">' +
    commercePjEchapper(tCommercePJ('commercepj.gestion.produits')) + '</div>';

  if (!mesTypes.length) {
    html += '<p style="color:#8a8060;font-size:.85rem;font-style:italic">' +
      commercePjEchapper(tCommercePJ('commercepj.gestion.aucuneActivite')) + '</p>';
  } else if (!cles.length) {
    html += '<p style="color:#8a8060;font-size:.85rem;font-style:italic;margin-bottom:.8rem">' +
      commercePjEchapper(tCommercePJ('commercepj.gestion.aucunProduit')) + '</p>';
  }

  cles.forEach(function (id) {
    const r = refs[id] || {};
    const stock = Math.max(0, Number(stocks[id]) || 0);
    const c = couts[id];
    const dispo = c && c.disponible === true;
    let etat, couleur;
    if (r.active !== true)   { etat = tCommercePJ('commercepj.ref.retire');  couleur = '#6a6050'; }
    else if (stock <= 0)     { etat = tCommercePJ('commercepj.ref.rupture'); couleur = '#8c6a3a'; }
    else                     { etat = tCommercePJ('commercepj.ref.enVente'); couleur = '#6fa07a'; }

    html += '<div style="border:1px solid #2a2620;padding:.7rem .8rem;margin-bottom:.6rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:.6rem;margin-bottom:.4rem">' +
      '<b style="color:#e0d8c0;font-size:.95rem">' + commercePjEchapper(r.nom || '—') + '</b>' +
      '<span style="font-size:.72rem;color:' + couleur + ';white-space:nowrap">' + commercePjEchapper(etat) + '</span></div>';
    if (r.description) {
      html += '<div style="font-size:.8rem;color:#8a8060;font-style:italic;margin-bottom:.4rem">' +
        commercePjEchapper(r.description) + '</div>';
    }
    html += commercePjLigne(tCommercePJ('commercepj.ref.stock'), stock + ' ' + tCommercePJ('commercepj.recette.unites'));
    html += commercePjLigne(tCommercePJ('commercepj.ref.cout'),
      dispo ? (commercePjMontant(c.coutUnitaire) + ' ' + cur + ' / ' + tCommercePJ('commercepj.ref.unite'))
            : '<i style="color:#6a6050">—</i>');
    html += commercePjLigne(tCommercePJ('commercepj.ref.prix'),
      (Number(r.prixVente) > 0) ? (commercePjMontant(r.prixVente) + ' ' + cur)
                                : '<i style="color:#6a6050">' + commercePjEchapper(tCommercePJ('commercepj.ref.sansPrix')) + '</i>');
    if (dispo) {
      html += commercePjLigne(tCommercePJ('commercepj.ref.plafond'), commercePjMontant(c.prixMaximum) + ' ' + cur);
    }
    html += '<div style="display:flex;flex-wrap:wrap;gap:.4rem;margin-top:.6rem">';
    html += commercePjBouton("commercePjEcranProduire('" + id + "')", tCommercePJ('commercepj.ref.produire'), true);
    html += commercePjBouton("commercePjEcranPrix('" + id + "')", tCommercePJ('commercepj.ref.tarifer'));
    if (r.active === true) {
      html += commercePjBouton("commercePjActiver('" + id + "',false)", tCommercePJ('commercepj.ref.retirer'));
    } else {
      html += commercePjBouton("commercePjActiver('" + id + "',true)", tCommercePJ('commercepj.ref.mettreEnVente'));
    }
    html += '</div></div>';
  });

  if (mesTypes.length) {
    html += '<div style="margin-top:.8rem">' +
      commercePjBouton('commercePjNouvelleReference()', tCommercePJ('commercepj.gestion.nouveau'), true) + '</div>';
  }
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.titre.gestion'), html);
}

// ---------------------------------------------------------------------------
// CREER UN PRODUIT : generique, puis recette systeme, puis habillage
// ---------------------------------------------------------------------------
// Aucun cas particulier par produit : la liste des generiques et celle des
// recettes viennent du serveur. Une recette ajoutee demain apparait ici seule.
async function commercePjNouvelleReference() {
  commercePjChargement(tCommercePJ('commercepj.titre.reference'));
  const ctx = await commercePjContexte();
  const gens = await sbFondsGeneriquesAccessibles(ctx.fondsId);
  let html = '<div style="padding:1.1rem">';
  html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.3rem">' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.generique')) + '</div>';
  html += '<p style="color:#8a8060;font-size:.82rem;margin-bottom:.9rem">' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.generiqueAide')) + '</p>';
  if (!gens.length) {
    html += '<p style="color:#8a8060;font-size:.85rem;font-style:italic">' +
      commercePjEchapper(tCommercePJ('commercepj.nouvelle.aucunGenerique')) + '</p>';
  }
  let familleCourante = null;
  gens.forEach(function (g) {
    if (g.famille !== familleCourante) {
      familleCourante = g.famille;
      html += '<div style="font-size:.72rem;letter-spacing:.09em;color:#6a6050;margin:.7rem 0 .3rem">' +
        commercePjEchapper(familleCourante) + '</div>';
    }
    html += '<div onclick="commercePjChoisirGenerique(\'' + commercePjEchapper(g.generique_id) + '\')" ' +
      'style="border:1px solid #2a2620;padding:.5rem .7rem;margin-bottom:.3rem;cursor:pointer;color:#c0b090;font-size:.88rem">' +
      commercePjEchapper(g.libelle) + '</div>';
  });
  html += '<div style="margin-top:1rem">' +
    commercePjBouton('commercePjEcranGestion()', tCommercePJ('commercepj.retour.gestion')) + '</div>';
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.titre.reference'), html);
}

// Rendu lisible d'une recette systeme : jamais d'identifiant, jamais de JSON.
function commercePjRecetteLisible(rec) {
  const mats = rec.materiaux || {};
  const parts = Object.keys(mats).map(function (m) {
    return mats[m] + ' × ' + commercePjLibelleMatiere(m);
  });
  if (Number(rec.pa) > 0) parts.push(rec.pa + ' ' + tCommercePJ('commercepj.recette.pa'));
  let h = '<div style="font-size:.8rem;color:#8a8060;line-height:1.5">';
  h += '<div>' + commercePjEchapper(tCommercePJ('commercepj.recette.necessite')) + ' : ' +
       commercePjEchapper(parts.join(' · ') || '—') + '</div>';
  h += '<div>' + commercePjEchapper(tCommercePJ('commercepj.recette.produit')) + ' : ' +
       rec.portions + ' ' + commercePjEchapper(tCommercePJ('commercepj.recette.unites')) + '</div>';
  return h + '</div>';
}

async function commercePjChoisirGenerique(generiqueId) {
  commercePjChargement(tCommercePJ('commercepj.titre.reference'));
  const recs = await sbGeneriqueRecettesSysteme(generiqueId);
  let html = '<div style="padding:1.1rem">';
  if (recs.length) {
    html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.3rem">' +
      commercePjEchapper(tCommercePJ('commercepj.nouvelle.recette')) + '</div>';
    html += '<p style="color:#8a8060;font-size:.82rem;margin-bottom:.9rem">' +
      commercePjEchapper(tCommercePJ('commercepj.nouvelle.recetteAide')) + '</p>';
    recs.forEach(function (rec) {
      html += '<div onclick="commercePjEcranHabillage(\'' + commercePjEchapper(generiqueId) + '\',\'' +
        commercePjEchapper(rec.recette_id) + '\')" ' +
        'style="border:1px solid #2a2620;padding:.6rem .7rem;margin-bottom:.4rem;cursor:pointer">' +
        '<div style="color:#e0d8c0;font-size:.9rem;margin-bottom:.25rem">' + commercePjEchapper(rec.label) + '</div>' +
        commercePjRecetteLisible(rec) + '</div>';
    });
  } else {
    html += '<p style="color:#8a8060;font-size:.85rem;font-style:italic;margin-bottom:.8rem">' +
      commercePjEchapper(tCommercePJ('commercepj.recette.aucune')) + '</p>';
    html += commercePjBouton("commercePjEcranHabillage('" + commercePjEchapper(generiqueId) + "','')",
      tCommercePJ('commercepj.nouvelle.creer'), true);
  }
  html += '<div style="margin-top:1rem">' +
    commercePjBouton('commercePjNouvelleReference()', tCommercePJ('commercepj.retour.gestion')) + '</div>';
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.titre.reference'), html);
}

// L'habillage est visuellement separe : le joueur voit qu'il personnalise le
// texte, et rien d'autre. Formule sans reproche, seulement claire.
function commercePjEcranHabillage(generiqueId, recetteId) {
  let html = '<div style="padding:1.1rem">';
  html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.3rem">' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.habillage')) + '</div>';
  html += '<p style="color:#8a8060;font-size:.82rem;margin-bottom:.9rem">' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.habillageAide')) + '</p>';
  html += '<label style="display:block;font-size:.78rem;color:#8a8060;margin-bottom:.3rem">' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.nom')) + '</label>';
  html += '<input id="cpj-nom" type="text" maxlength="80" placeholder="' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.nomPh')) + '" ' +
    'style="width:100%;padding:.5rem;background:#0e0c08;border:1px solid #3a3a30;color:#e0d8c0;margin-bottom:.7rem"/>';
  html += '<label style="display:block;font-size:.78rem;color:#8a8060;margin-bottom:.3rem">' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.desc')) + '</label>';
  html += '<textarea id="cpj-desc" maxlength="400" rows="3" placeholder="' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.descPh')) + '" ' +
    'style="width:100%;padding:.5rem;background:#0e0c08;border:1px solid #3a3a30;color:#e0d8c0;margin-bottom:1rem"></textarea>';
  html += commercePjBouton("commercePjCreerReference('" + commercePjEchapper(generiqueId) + "','" +
    commercePjEchapper(recetteId || '') + "')", tCommercePJ('commercepj.nouvelle.creer'), true);
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.titre.reference'), html);
}

async function commercePjCreerReference(generiqueId, recetteId) {
  const ctx = await commercePjContexte();
  const nom = (document.getElementById('cpj-nom') || {}).value || '';
  const desc = (document.getElementById('cpj-desc') || {}).value || '';
  const r = await sbFondsReferenceCreer(state.char.name, ctx.fondsId, generiqueId, recetteId || null, nom, desc);
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  if (typeof addJournalEntry === 'function') addJournalEntry('Nouveau produit : ' + nom + '.', 'event-good');
  commercePjEcranGestion();
}

// ---------------------------------------------------------------------------
// PRODUIRE
// ---------------------------------------------------------------------------
// L'ecran montre ce que la recette demande et ce que le commerce possede. Le
// client n'envoie ensuite QUE l'identifiant de la reference.
async function commercePjEcranProduire(referenceId) {
  commercePjChargement(tCommercePJ('commercepj.produire.titre'));
  const ctx = await commercePjContexte();
  const ref = ((ctx.fonds || {}).references || {})[referenceId];
  if (!ref) { showToast('—', commercePjRefus({ raison: 'reference_absente' }), false); return; }
  const recs = await sbGeneriqueRecettesSysteme(ref.generique_id);
  const rec = recs.filter(function (x) { return x.recette_id === ref.recette_id; })[0];
  const stocks = (ctx.fonds || {}).stockMatieres || {};

  let html = '<div style="padding:1.1rem">';
  html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.6rem">' +
    commercePjEchapper(ref.nom || '—') + '</div>';
  if (!rec) {
    html += '<p style="color:#8a8060;font-size:.85rem;font-style:italic">' +
      commercePjEchapper(tCommercePJ('commercepj.recette.aucune')) + '</p>';
  } else {
    html += '<div style="border:1px solid #2a2620;padding:.6rem .8rem;margin-bottom:.8rem">' +
      '<div style="color:#c0b090;font-size:.88rem;margin-bottom:.35rem">' + commercePjEchapper(rec.label) + '</div>' +
      commercePjRecetteLisible(rec) + '</div>';
    html += '<div style="font-size:.78rem;letter-spacing:.08em;color:#6a6050;margin-bottom:.3rem">' +
      commercePjEchapper(tCommercePJ('commercepj.produire.vosStocks')) + '</div>';
    Object.keys(rec.materiaux || {}).forEach(function (m) {
      const a = Math.max(0, Number(stocks[m]) || 0), b = Number(rec.materiaux[m]) || 0;
      html += commercePjLigne(commercePjLibelleMatiere(m),
        '<span style="color:' + (a >= b ? '#6fa07a' : '#a05a4a') + '">' + a + ' / ' + b + '</span>');
    });
    html += '<div style="margin-top:.9rem">' +
      commercePjBouton("commercePjProduire('" + referenceId + "','" + nouvelleCleProduction() + "')",
        tCommercePJ('commercepj.produire.confirmer'), true) + '</div>';
  }
  html += '<div style="margin-top:.9rem">' +
    commercePjBouton('commercePjEcranGestion()', tCommercePJ('commercepj.retour.gestion')) + '</div>';
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.produire.titre'), html);
}

// La cle de requete est fabriquee A L'OUVERTURE de l'ecran et passee telle quelle :
// un double clic rejoue la meme cle et ne produit donc qu'un seul lot.
async function commercePjProduire(referenceId, requete) {
  const ctx = await commercePjContexte();
  const r = await sbFondsReferenceProduire(requete, state.char.name, ctx.fondsId, referenceId);
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  if (r.rejeu !== true && typeof addJournalEntry === 'function') {
    addJournalEntry('Fabrication : ' + r.quantite + ' unité(s).', 'event-good');
  }
  showToast(tCommercePJ('commercepj.produire.fait'),
    r.quantite + ' ' + tCommercePJ('commercepj.recette.unites'), true);
  if (typeof updateUI === 'function') updateUI();
  commercePjEcranGestion();
}

// ---------------------------------------------------------------------------
// PRIX
// ---------------------------------------------------------------------------
// Le plafond vient du serveur et n'est JAMAIS recalcule ici : le coefficient est
// une politique de pays, et cette interface doit pouvoir servir tous les empires.
async function commercePjEcranPrix(referenceId) {
  commercePjChargement(tCommercePJ('commercepj.prix.titre'));
  const ctx = await commercePjContexte();
  const ref = ((ctx.fonds || {}).references || {})[referenceId] || {};
  const c = await sbFondsCoutRevientReference(ctx.fondsId, referenceId);
  const cur = commercePjDevise();
  const dispo = c && c.disponible === true;

  let html = '<div style="padding:1.1rem">';
  html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.6rem">' +
    commercePjEchapper(ref.nom || '—') + '</div>';
  if (!dispo) {
    html += '<p style="color:#8a8060;font-size:.85rem;line-height:1.6">' +
      commercePjEchapper(tCommercePJ('commercepj.prix.sansCout')) + '</p>';
  } else {
    html += '<div style="border:1px solid #2a2620;padding:.6rem .8rem;margin-bottom:.9rem">';
    html += commercePjLigne(tCommercePJ('commercepj.ref.cout'),
      commercePjMontant(c.coutUnitaire) + ' ' + cur + ' / ' + tCommercePJ('commercepj.ref.unite'));
    html += commercePjLigne(tCommercePJ('commercepj.ref.plafond'),
      '<b style="color:#E8C97A">' + commercePjMontant(c.prixMaximum) + ' ' + cur + '</b>');
    html += '</div>';
    html += '<label style="display:block;font-size:.78rem;color:#8a8060;margin-bottom:.3rem">' +
      commercePjEchapper(tCommercePJ('commercepj.prix.saisie')) + ' (' + cur + ')</label>';
    html += '<input id="cpj-prix" type="number" min="1" step="1" max="' + Number(c.prixMaximum) + '" value="' +
      (Number(ref.prixVente) > 0 ? Number(ref.prixVente) : Number(c.prixMaximum)) + '" ' +
      'style="width:100%;padding:.5rem;background:#0e0c08;border:1px solid #3a3a30;color:#e0d8c0;margin-bottom:.9rem"/>';
    html += commercePjBouton("commercePjFixerPrix('" + referenceId + "')", tCommercePJ('commercepj.prix.valider'), true);
  }
  html += '<div style="margin-top:.9rem">' +
    commercePjBouton('commercePjEcranGestion()', tCommercePJ('commercepj.retour.gestion')) + '</div>';
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.prix.titre'), html);
}

async function commercePjFixerPrix(referenceId) {
  const ctx = await commercePjContexte();
  const prix = Math.floor(Number((document.getElementById('cpj-prix') || {}).value) || 0);
  const r = await sbFondsReferencePrix(state.char.name, ctx.fondsId, referenceId, prix);
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  commercePjEcranGestion();
}

async function commercePjActiver(referenceId, actif) {
  const ctx = await commercePjContexte();
  const r = await sbFondsReferenceActiver(state.char.name, ctx.fondsId, referenceId, actif === true);
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  commercePjEcranGestion();
}

// ---------------------------------------------------------------------------
// BOUTIQUE PUBLIQUE
// ---------------------------------------------------------------------------
async function commercePjEcranBoutique(ctx) {
  commercePjChargement(tCommercePJ('commercepj.titre.boutique'));
  if (!ctx || !ctx.fonds) ctx = await commercePjContexte();
  const f = ctx.fonds, cur = commercePjDevise();
  const refs = f.references || {}, stocks = f.stockReferences || {};
  const actives = Object.keys(refs).filter(function (id) { return refs[id] && refs[id].active === true; });

  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.05rem;color:#E8C97A">' +
    commercePjEchapper(f.enseigne || '—') + '</div>';
  html += '<div style="font-size:.76rem;color:#6a6050;margin-bottom:.9rem">' +
    commercePjEchapper(tCommercePJ('commercepj.boutique.tenu')) + ' ' +
    commercePjEchapper(String(f.proprietaire || '').replace(/^pj:/, '')) + '</div>';

  if (!actives.length) {
    html += '<p style="color:#8a8060;font-size:.85rem;font-style:italic">' +
      commercePjEchapper(tCommercePJ('commercepj.boutique.aucun')) + '</p>';
  }
  actives.forEach(function (id) {
    const r = refs[id], stock = Math.max(0, Number(stocks[id]) || 0);
    html += '<div style="border:1px solid #2a2620;padding:.7rem .8rem;margin-bottom:.6rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:.6rem">' +
      '<b style="color:#e0d8c0;font-size:.95rem">' + commercePjEchapper(r.nom || '—') + '</b>' +
      '<span style="color:#E8C97A;white-space:nowrap">' + commercePjMontant(r.prixVente) + ' ' + cur + '</span></div>';
    if (stock <= 0) {
      html += '<div style="font-size:.76rem;color:#8c6a3a;margin-top:.25rem">' +
        commercePjEchapper(tCommercePJ('commercepj.ref.rupture')) + '</div>';
    }
    html += '<div style="margin-top:.5rem">' +
      commercePjBouton("commercePjFicheProduit('" + id + "')", tCommercePJ('commercepj.boutique.voir'), true) + '</div>';
    html += '</div>';
  });
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.titre.boutique'), html);
}

// ---------------------------------------------------------------------------
// FICHE PRODUIT — LE GARDE-FOU
// ---------------------------------------------------------------------------
// Deux blocs nettement separes : ce que le VENDEUR affirme, et ce que le SYSTEME
// constate. Un intitule mensonger reste possible ; l'acheteur peut le verifier.
// La fiche officielle est celle de L2, reutilisee telle quelle.
async function commercePjFicheProduit(referenceId) {
  commercePjChargement(tCommercePJ('commercepj.titre.produit'));
  const ctx = await commercePjContexte();
  const f = ctx.fonds || {};
  const r = (f.references || {})[referenceId];
  if (!r) { showToast('—', commercePjRefus({ raison: 'reference_absente' }), false); return; }
  const stock = Math.max(0, Number((f.stockReferences || {})[referenceId]) || 0);
  const cur = commercePjDevise();

  // L'objet decrit ici ne sert QU'A interroger la fiche : il n'est jamais envoye
  // comme autorite. L'achat, lui, n'envoie que la reference.
  let fiche = null;
  if (typeof sbObjetFicheOfficielle === 'function') {
    fiche = await sbObjetFicheOfficielle({
      type: referenceId,
      generique_id: r.generique_id,
      variante_id: r.variante_id || null
    }).catch(function () { return null; });
  }

  let html = '<div style="padding:1rem">';
  if (typeof ficheCommercialeHtml === 'function') {
    html += ficheCommercialeHtml({
      nom: r.nom, description: r.description, prix: r.prixVente, devise: cur,
      vendeur: String(f.proprietaire || '').replace(/^pj:/, ''), stock: stock
    });
  } else {
    html += '<div style="font-family:Playfair Display,serif;color:#E8C97A">' + commercePjEchapper(r.nom) + '</div>';
  }
  if (fiche && typeof ficheOfficielleHtml === 'function') {
    html += ficheOfficielleHtml(fiche);
  }

  html += '<div style="height:.9rem"></div>';
  html += '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.1em;color:#a09070;font-size:.8rem;margin-bottom:.4rem">' +
    commercePjEchapper(tCommercePJ('commercepj.fiche.vente')) + '</div>';
  if (stock <= 0) {
    html += '<div style="font-size:.84rem;color:#8c6a3a;margin-bottom:.5rem">' +
      commercePjEchapper(tCommercePJ('commercepj.ref.rupture')) + '</div>';
    html += commercePjBouton('', tCommercePJ('commercepj.boutique.acheter'), false, true);
  } else {
    html += '<label style="display:block;font-size:.78rem;color:#8a8060;margin-bottom:.3rem">' +
      commercePjEchapper(tCommercePJ('commercepj.fiche.quantite')) + '</label>';
    html += '<input id="cpj-qte" type="number" min="1" step="1" max="' + stock + '" value="1" ' +
      'style="width:100%;padding:.5rem;background:#0e0c08;border:1px solid #3a3a30;color:#e0d8c0;margin-bottom:.8rem"/>';
    // L'achat dans son propre commerce est autorise : le bouton n'est jamais masque.
    html += commercePjBouton("commercePjAcheter('" + referenceId + "','" + nouvelleCleAchat() + "')",
      tCommercePJ('commercepj.boutique.acheter'), true);
  }
  html += '<div style="margin-top:.9rem">' +
    commercePjBouton('commercePjEcranBoutique()', tCommercePJ('commercepj.retour.boutique')) + '</div>';
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.titre.produit'), html);
}

// L'achat n'envoie QUE : cle de requete, acteur, fonds, reference, quantite.
// Ni prix, ni objet, ni montant. La livraison passe par le sas existant.
async function commercePjAcheter(referenceId, requete) {
  const ctx = await commercePjContexte();
  const qte = Math.max(1, Math.floor(Number((document.getElementById('cpj-qte') || {}).value) || 1));
  const r = await sbAcheterProduitCommerce(requete, state.char.name, ctx.fondsId, referenceId, qte);
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  if (r.rejeu === true) { commercePjEcranBoutique(); return; }
  showToast(tCommercePJ('commercepj.fiche.achete'),
    commercePjMontant(r.montant) + ' ' + commercePjDevise() + ' — ' + tCommercePJ('commercepj.fiche.recu'), true, true);
  if (typeof addJournalEntry === 'function') {
    addJournalEntry('Achat : ' + r.quantite + ' × ' + commercePjMontant(r.prixUnitaire) + ' ' +
      commercePjDevise() + '.', 'event-good');
  }
  // Le sas existant reste le seul chemin de livraison : on ne cree pas un second
  // systeme de reception, on declenche simplement le drainage deja en place.
  if (typeof verifierObjetsRecus === 'function') { try { await verifierObjetsRecus(); } catch (e) {} }
  if (typeof updateUI === 'function') updateUI();
  commercePjEcranBoutique();
}
