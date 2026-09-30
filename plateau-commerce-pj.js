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
  'commercepj.ref.produire':         "Produire",
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

  'commercepj.produire.fait':        "Fabrication terminée",


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

  // --- C6 : libelles de l'ordre du local, derives du fonds ---
  'commercepj.ordre.gerer':          "Gérer mon commerce",
  'commercepj.ordre.gererAide':      "Gérer votre commerce : identité, caisse, matières et articles.",
  'commercepj.ordre.visiter':        "Entrer dans le commerce",
  // Libelles du parcours commercant unifie (30 septembre 2026). Le vocabulaire est
  // celui d'une boutique ; un restaurant dit « Consulter la carte » pour la MEME
  // primitive, et c'est voulu : le libelle appartient au metier, la primitive au socle.
  'commercepj.ordre.produits':       "Voir les produits",
  'commercepj.ordre.produitsAide':   "Les articles proposés à la vente, avec leur prix et leur stock.",
  'commercepj.ordre.produire':       "Produire",
  'commercepj.ordre.produireAide':   "Fabriquer pour ce commerce, avec ses matières premières. Le travail est payé.",
  'commercepj.ordre.matieres':       "Vendre ou donner des matières",
  'commercepj.ordre.matieresAide':   "Céder des matières premières de votre inventaire à ce commerce.",
  'commercepj.ordre.visiterAide':    "Acheter, fabriquer pour ce commerce, ou lui vendre des matières premières.",
  'commercepj.ordre.installer':      "Installer un commerce",
  'commercepj.ordre.installerAide':  "Créer un fonds de commerce dans ce local dont vous êtes titulaire.",
  // --- C6 : deux sous-menus, matieres premieres, apport public ---
  'commercepj.menu.boutique':        "Voir ma boutique",
  'commercepj.global.aucuneMatiere': "Aucune matière : les activités déclarées par votre commerce n'ouvrent encore aucune fabrication.",
  'commercepj.matiere.prix':         "Prix de rachat",
  'commercepj.matiere.enregistre':   "Réglage enregistré",
  'commercepj.appro.titre':          "Vendre ou donner des matières",
  'commercepj.appro.recherche':      "Ce commerce recherche",
  'commercepj.appro.aucune':         "Ce commerce ne recherche aucune matière pour le moment.",
  'commercepj.appro.vous':           "Vous en avez",
  'commercepj.appro.besoin':         "Il peut en prendre",
  'commercepj.appro.vendre':         "Vendre",
  'commercepj.appro.donner':         "Donner",
  'commercepj.appro.quantite':       "Quantité",
  'commercepj.appro.vendu':          "Matière vendue",
  'commercepj.appro.donne':          "Matière donnée",
  'commercepj.appro.partiel':        "Seules {faites} unités sur {voulues} ont pu être prises.",
  'commercepj.ref.stockMax':         "Stock maximum",
  'commercepj.ref.maxAide':          "0 signifie « sans limite ». Un lot dont le rendement dépasserait ce maximum est refusé en entier : le rendement d'une recette ne se coupe pas.",
  // --- C6 bis : sommaire public, production visiteur ---
  // « Illimité » ne concerne plus que le stock maximum d'un ARTICLE : pour une
  // matière première, 0 veut dire « je n'en veux pas » depuis C7.
  'commercepj.matiere.illimite':     "Illimité",
  'commercepj.matiere.utilisee':     "Utilisée par vos produits",

  // --- C7 : l'ordinateur de gestion du propriétaire ---
  'commercepj.machine.plaque':       "SYSTÈME COMMERCIAL RÉPUBLIA",
  'commercepj.machine.eteindre':     "Fermer",
  'commercepj.tab.caisse':           "Caisse",
  'commercepj.tab.produits':         "Produits vendus",
  'commercepj.tab.matieres':         "Matières premières",
  'commercepj.caisse.solde':         "Solde",
  'commercepj.caisse.vosPa':         "Vos PA",
  'commercepj.caisse.montant':       "Montant",
  'commercepj.caisse.apport':        "Apport",
  'commercepj.caisse.prelever':      "Prélever",
  'commercepj.caisse.apportFait':    "Apport versé en caisse",
  'commercepj.caisse.preleveFait':   "Prélèvement effectué",
  'commercepj.col.produit':          "Produit",
  'commercepj.col.matiere':          "Matière",
  'commercepj.col.stock':            "Stock",
  'commercepj.col.stockMax':         "Stock max.",
  'commercepj.col.prixVente':        "Prix de vente",
  'commercepj.col.rachat':           "Prix de rachat",
  'commercepj.ref.sansCoutCourt':    "coût de revient non établi",

  // --- C8 : fabrication et apport depuis la ligne ---
  'commercepj.prod.lots':            "Lots",
  'commercepj.prod.pa':              "PA",
  'commercepj.prod.verses':          "versés",
  'commercepj.prod.enCours':         "…",
  'commercepj.refus.lots_invalides':              "Ce nombre de lots n'est pas autorisé (1 à {maximum}).",
  'commercepj.refus.quantite_invalide':           "Cette quantité n'est pas valide.",
  'commercepj.refus.stock_personnel_insuffisant': "Vous n'en avez pas autant sur vous.",
  'commercepj.refus.personnage_introuvable':      "Votre personnage est introuvable.",
  'commercepj.refus.reference_sans_recette':      "Ce produit ne se fabrique pas.",
  'commercepj.refus.rendement_non_declare':       "Le rendement de cette fabrication n'est pas déclaré.",
  'commercepj.refus.valeur_pa_non_declaree':      "Le salaire horaire n'est pas défini dans cet empire.",
  'commercepj.matiere.refusCourt':   "vous n'en voulez pas",
  'commercepj.matiere.maxAide':      "Fixez le stock maximum de chaque matière : 0 signifie que votre commerce n'en veut pas, et personne ne pourra vous en vendre. Maximum autorisé : {plafond}.",
  'commercepj.public.titre':         "Entrer dans le commerce",
  'commercepj.public.boutique':      "Boutique",
  'commercepj.public.boutiqueAide':  "Acheter les produits proposés à la vente.",
  'commercepj.public.produire':      "Produire",
  'commercepj.public.produireAide':  "Fabriquer pour ce commerce, avec ses matières premières.",
  'commercepj.public.matieres':      "Matières premières",
  'commercepj.public.matieresAide':  "Vendre ou donner des matières à ce commerce.",
  'commercepj.public.retour':        "← Retour à l'entrée",
  'commercepj.travail.titre':        "Travailler ici",
  'commercepj.travail.aide':         "Ce commerce fournit ses matières premières et paie votre travail. Le produit fini rejoint son stock, pas votre inventaire.",
  'commercepj.travail.aucun':        "Ce commerce n'a encore aucun produit fabricable.",
  'commercepj.travail.fabrication':  "Fabrication",
  'commercepj.travail.rendement':    "Rendement du lot",
  'commercepj.travail.salaire':      "Votre salaire",
  'commercepj.travail.stockCommerce':"Stock du commerce",
  'commercepj.travail.maximum':      "Maximum",
  'commercepj.travail.produire':     "Produire ce lot",
  'commercepj.travail.matieresDispo':"Matières disponibles ici",
  'commercepj.nouvelle.choisirForme': "Choisir cette fabrication",
  'commercepj.nouvelle.formeRetenue': "Fabrication retenue",
  'commercepj.nouvelle.generiqueRetenu': "Type de produit",
  'commercepj.refus.defaut':                      "L'opération n'a pas abouti. Rien n'a été modifié.",
  'commercepj.refus.matiere_hors_activites':      "Les activités de ce commerce ne permettent pas d'utiliser cette matière.",
  'commercepj.refus.matiere_non_acceptee':        "Ce commerce n'accepte pas cette matière pour le moment.",
  'commercepj.refus.caisse_insuffisante':         "La caisse du commerce ne peut pas payer ce travail. Rien n'a été prélevé.",
  'commercepj.refus.pas_sur_place':               "Il faut être sur place, dans ce commerce.",
  'commercepj.refus.matiere_interdite':           "Cette matière est interdite par la loi « {loi} » : elle ne peut être ni vendue ni donnée.",
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
  // C6 : motifs de l'approvisionnement et de la presence physique.
  'commercepj.refus.pas_sur_place':               "Vous devez être dans ce commerce pour cela.",
  'commercepj.refus.matiere_interdite':           "Cette matière est interdite par la loi « {loi} » : elle ne peut être ni vendue ni donnée.",
  'commercepj.refus.matiere_non_recherchee':      "Ce commerce n'a aucun usage de cette matière.",
  'commercepj.refus.stock_plein':                 "Ce commerce n'a plus de place pour cette matière.",
  'commercepj.refus.plafond_matiere_non_defini':  "L'approvisionnement n'est pas encore ouvert dans cet empire.",
  'commercepj.refus.maximum_invalide':            "Ce maximum n'est pas autorisé.",
  // C7 : la caisse d'un commerce contient des especes. Un solde bancaire ne s'y
  // verse pas directement -- il faut d'abord retirer l'argent.
  'commercepj.refus.liquide_insuffisant':         "Vous n'avez pas cette somme en espèces sur vous.",
  'commercepj.refus.montant_invalide':            "Ce montant n'est pas valide.",
  'commercepj.refus.proprietaire_absent':         "Votre personnage est introuvable.",
  'commercepj.refus.pas_un_fonds':                "Ce n'est pas un commerce de joueur.",
  'commercepj.refus.mode_invalide':               "Ce type d'apport n'existe pas.",
  'commercepj.refus.requete_invalide':            "Demande mal formée. Rouvrez l'écran et recommencez.",
  'commercepj.refus.vendeur_introuvable':         "Votre personnage est introuvable.",
  'commercepj.refus.plafond_references_atteint':  "Vous avez atteint le nombre de produits autorisé pour ce commerce.",
  'commercepj.refus.stock_max_reference_depasse': "Cette fabrication produirait {rendement} unités et dépasserait votre capacité maximale de {maximum} (vous en avez {stock}).",
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
    // L'INTERDICTION SE NOMME. Le serveur rend la loi qui s'oppose a l'apport : le
    // joueur a le droit de savoir laquelle, et cela lui evite de croire a une panne.
    if (r === 'matiere_interdite') {
      const titreLoi = (v.loi && v.loi.titre) || (v.detail && v.detail.loi && v.detail.loi.titre);
      return tCommercePJ('commercepj.refus.matiere_interdite', { loi: titreLoi || '—' });
    }
    // Le refus du lot complet ne se comprend qu'avec ses trois chiffres : ce que
    // la recette produit, ce que le commerce peut contenir, ce qu'il contient deja.
    if (r === 'stock_max_reference_depasse') {
      return tCommercePJ('commercepj.refus.stock_max_reference_depasse',
        { rendement: v.rendement, maximum: v.maximum, stock: v.stock });
    }
    // C8 : les deux motifs de la commande multi-lots portent leurs bornes.
    if (r === 'lots_invalides' && v.maximum != null) {
      return tCommercePJ('commercepj.refus.lots_invalides', { maximum: v.maximum });
    }
    if (r === 'caisse_insuffisante' && v.salaire != null) {
      return texte + ' ' + commercePjMontant(v.salaire) + ' ' + commercePjDevise() +
             ' / ' + commercePjMontant(v.caisse) + ' ' + commercePjDevise() + '.';
    }
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
  // LA COQUE NE SURVIT PAS A L'ECRAN QUI L'A POSEE. #modal-postes est partage
  // avec l'organigramme, le journal, Helvetia : tout ecran ordinaire retire la
  // classe de la machine, sans quoi le suivant heriterait d'un boitier beige.
  const boite = document.querySelector('#modal-postes .modal-box');
  if (boite) boite.classList.remove('cpj-machine');
  document.getElementById('modal-postes').classList.add('open');
}

// ---------------------------------------------------------------------------
// L'ORDINATEUR DE GESTION — LA FENETRE EST LA MACHINE
// ---------------------------------------------------------------------------
// Le proprietaire ne consulte pas un formulaire : il s'assoit devant le
// terminal de son commerce. Le boitier, l'ecran et la plaque sont dessines par
// style.css (bloc .cpj-) -- aucune image, aucun asset. Ici on ne fait que
// composer la coque autour du contenu de l'ecran.
//
// La machine porte sa PROPRE touche de fermeture : l'en-tete standard de la
// modale est masquee, parce qu'un bandeau de jeu sur une coque beige casse
// l'illusion en un coup d'oeil.
function commercePjMachine(titre, enseigne, htmlEcran) {
  const t = document.getElementById('postes-modal-title');
  const b = document.getElementById('postes-body');
  if (!t || !b) return;
  t.textContent = titre;
  b.innerHTML =
    '<div class="cpj-fronton">' +
      '<span class="cpj-led" aria-hidden="true"></span>' +
      '<span class="cpj-plaque">' +
        commercePjEchapper(tCommercePJ('commercepj.machine.plaque')) + '</span>' +
      '<span class="cpj-grilles" aria-hidden="true"></span>' +
      '<span class="cpj-enseigne">' + commercePjEchapper(enseigne || '—') + '</span>' +
      '<button class="cpj-eteindre" onclick="commercePjFermer()" title="' +
        commercePjEchapper(tCommercePJ('commercepj.machine.eteindre')) + '">' +
        '<i class="ti ti-power"></i></button>' +
    '</div>' +
    '<div class="cpj-ecran">' + htmlEcran + '</div>' +
    '<div class="cpj-socle" aria-hidden="true"></div>';
  const boite = document.querySelector('#modal-postes .modal-box');
  if (boite) boite.classList.add('cpj-machine');
  document.getElementById('modal-postes').classList.add('open');
}

function commercePjFermer() {
  const boite = document.querySelector('#modal-postes .modal-box');
  if (boite) boite.classList.remove('cpj-machine');
  const m = document.getElementById('modal-postes');
  if (m) m.classList.remove('open');
}

// Touche de l'ecran. Meme role que commercePjBouton, autre materiau : les
// boutons du jeu n'ont rien a faire sur un ecran a phosphore.
function commercePjTouche(onclick, libelle, primaire, desactive) {
  return '<button class="cpj-touche' + (primaire ? ' cpj-primaire' : '') + '" ' +
    (desactive ? 'disabled' : 'onclick="' + onclick + '"') + '>' +
    commercePjEchapper(libelle) + '</button>';
}

// PICTOGRAMME : JAMAIS SEUL, ET JAMAIS INVENTE. Les deux sources existent deja
// dans le projet -- RESSOURCES_ECONOMIE.icon pour les matieres, le champ `icon`
// d'une reference pour les produits (celui-la meme que le serveur recopie sur
// l'objet livre, C2). On ne fabrique aucune bibliotheque d'assets : on lit ce
// qui est la, et on retombe sur une icone neutre plutot que sur du vide.
function commercePjPicto(icone) {
  const nom = String(icone || '').trim() || 'ti-package';
  return '<span class="cpj-chip" aria-hidden="true"><i class="ti ' +
    commercePjEchapper(nom) + '"></i></span>';
}

function commercePjPictoMatiere(cle) {
  const r = (typeof RESSOURCES_ECONOMIE !== 'undefined') ? RESSOURCES_ECONOMIE[cle] : null;
  return commercePjPicto(r && r.icon);
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

// UN MAXIMUM NUL SE LIT « ILLIMITE ». Le chiffre 0 est exact mais illisible : il
// ressemble a une interdiction, alors qu'il en est l'inverse exact. Une seule
// fonction le traduit, pour que les six ecrans qui l'affichent ne divergent pas.
function commercePjMaximumLisible(maxi) {
  const n = Math.max(0, Number(maxi) || 0);
  return n === 0 ? tCommercePJ('commercepj.matiere.illimite') : String(n);
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
  if (ctx.fonds)                           return commercePjEcranPublic(ctx);
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
  // CONTEXTE RESOLU ICI SI L'APPELANT N'EN A PAS. « Modifier mes activites » est
  // une touche de l'ecran de gestion : elle appelle cette fonction SANS contexte,
  // et la ligne suivante levait alors une exception sur `ctx.fonds`. Le defaut
  // datait de C6 bis et rendait le bouton inutilisable -- meme forme de reparation
  // que dans tous les autres ecrans du fichier, qui resolvent leur propre contexte.
  if (!ctx || !ctx.fonds) ctx = await commercePjContexte();
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
// ---------------------------------------------------------------------------
// ORDRE DU LOCAL, DERIVE DU FONDS
// ---------------------------------------------------------------------------
// Le local ne sait pas ce qu'il abrite : c'est le BAIL qui designe le fonds.
// Cette fonction est la quatrieme source d'ordres de renderRoomActions, a cote
// des trois sources statiques de data.js. Elle est ADDITIVE et prudente :
// quand elle ne sait rien -- etat pas encore charge, local sans bail --, elle
// rend une liste vide et l'ordre declare dans data.js s'affiche comme avant.
// Quand elle sait, elle REMPLACE cet ordre par un libelle qui dit la verite :
// le proprietaire gere, le visiteur entre dans une boutique nommee.
//
// Tout est synchrone et sans reseau : getLocationPourRoom lit state.locationsActives,
// deja charge, et le serveur a inscrit fondsId dans le bail (migration C1).
// LE FONDS EXPLOITE ICI, LU SANS RESEAU. getLocationPourRoom lit state.locationsActives,
// deja charge, et le serveur a inscrit fondsId dans le bail (C1). Cette fonction est le
// point de bascule entre les deux moteurs de commerce du jeu : quand elle rend un
// identifiant, le local est exploite par un FONDS PJ et ce sont les primitives C6 qui
// parlent ; quand elle rend null, le lieu releve du moteur historique (restaurant,
// armurerie, bar, marche) et rien ne change pour lui.
function commercePjFondsIci() {
  if (typeof getLocationPourRoom !== 'function') return null;
  if (typeof state === 'undefined') return null;
  let bail = null;
  try { bail = getLocationPourRoom(state.currentBuilding, state.currentRoom, state.currentCity); }
  catch (e) { return null; }
  return (bail && bail.fondsId) ? bail.fondsId : null;
}

// ---------------------------------------------------------------------------
// LES ORDRES D'UN LOCAL EXPLOITE — MEME VOCABULAIRE QUE LES AUTRES COMMERCES
// ---------------------------------------------------------------------------
// LE DEFAUT CORRIGE (30 septembre 2026). Un local reellement exploite -- Aux
// Souvenirs d'Arnie, avec sa caisse, ses trois references, ses recettes et ses
// matieres -- n'offrait au visiteur qu'UN ordre, « Entrer dans le commerce », qui
// ouvrait un sommaire de trois entrees. A cote, le joueur lisait encore « Louer ce
// local (800 FR/jour) » : un parcours de local vacant devant un commerce actif.
//
// LE VOCABULAIRE EST DESORMAIS CELUI DU RESTAURANT LA REPUBLIA, qui est la
// reference UX : `consulter_carte_commerce`, `produire_commerce` et
// `vendre_matiere_commerce`. CE SONT LES MEMES `fn`, pas des jumeaux : le routeur
// les dirige vers le moteur qui tient ce lieu (voir plateau-router.js). Un
// libelle peut differer -- « Voir les produits » pour une boutique, « Consulter
// la carte » pour un restaurant -- la primitive, elle, est unique.
//
// TROIS ETATS, TROIS PARCOURS, tous derives du bail et d'aucun drapeau :
//   pas de bail            -> rien ici, « Louer ce local » de data.js s'applique ;
//   bail sans fonds        -> le titulaire seul peut installer un commerce ;
//   bail avec fonds        -> le parcours commercant complet, et « Louer ce local »
//                             est MASQUE : il est loue, et exploite.
function ordresCommerceDuLocal(buildingId, roomId, ville) {
  if (typeof getLocationPourRoom !== 'function') return [];
  let bail = null;
  try { bail = getLocationPourRoom(buildingId, roomId, ville); } catch (e) { return []; }
  if (!bail) return [];

  const base = { pa: 0, cost: 0, type: 'legal', successRate: 100 };
  const moi = (typeof state !== 'undefined' && state.char && state.char.name) || '';
  const titulaire = String(bail.locataire || '').replace(/^pj:/, '');

  if (!bail.fondsId) {
    // Local loue mais sans fonds : seul le titulaire peut en installer un.
    if (!moi || titulaire !== moi) return [];
    return [Object.assign({}, base, {
      fn: 'commerce_pj', icon: 'ti-building-store',
      label: tCommercePJ('commercepj.ordre.installer'),
      desc:  tCommercePJ('commercepj.ordre.installerAide')
    })];
  }

  // COMMERCE ACTIF. Le socle economique d'abord, dans l'ordre ou on s'en sert :
  // on regarde ce qui est vendu, on fabrique, on approvisionne.
  const ordres = [
    Object.assign({}, base, {
      fn: 'consulter_carte_commerce', icon: 'ti-shopping-bag',
      label: tCommercePJ('commercepj.ordre.produits'),
      desc:  tCommercePJ('commercepj.ordre.produitsAide'),
      // LE MASQUE PORTE SUR LES ORDRES QUE L'ETAT CONTREDIT, ET SUR EUX SEULS.
      //  - `louer_local` : le local est loue et exploite, il n'est plus a louer.
      //    C'etait le defaut visible chez Aux Souvenirs d'Arnie -- « Louer ce
      //    local » s'affichait a cote de la boutique en activite.
      //  - `commerce_pj` STATIQUE : data.js declare un « Ce commerce » a tout
      //    faire, qui menait tantot a la gestion tantot au menu public. Les trois
      //    primitives ci-dessus SONT ce menu ; le laisser afficherait deux portes
      //    pour la meme chose. Le masque ne retire que l'ordre DECLARE : celui que
      //    cette fonction ajoute plus bas pour le proprietaire est concatene apres
      //    le filtrage, et survit donc intact.
      // « Gerer mon local » n'est PAS masque : gerer un BAIL et gerer un COMMERCE
      // sont deux choses distinctes, et le titulaire a besoin des deux.
      masque: ['louer_local', 'commerce_pj']
    }),
    Object.assign({}, base, {
      fn: 'produire_commerce', icon: 'ti-hammer',
      label: tCommercePJ('commercepj.ordre.produire'),
      desc:  tCommercePJ('commercepj.ordre.produireAide')
    }),
    Object.assign({}, base, {
      fn: 'vendre_matiere_commerce', icon: 'ti-package-export',
      label: tCommercePJ('commercepj.ordre.matieres'),
      desc:  tCommercePJ('commercepj.ordre.matieresAide')
    })
  ];

  // Le proprietaire garde SA porte, distincte de celle du client : le terminal.
  if (moi && titulaire === moi) {
    ordres.push(Object.assign({}, base, {
      fn: 'commerce_pj', icon: 'ti-device-desktop-analytics',
      label: tCommercePJ('commercepj.ordre.gerer'),
      desc:  tCommercePJ('commercepj.ordre.gererAide')
    }));
  }
  return ordres;
}

// Inscription au REGISTRE des sources d'ordres dynamiques (29 septembre 2026).
// renderRoomActions n'appelle plus cette fonction par son nom : elle s'y inscrit,
// comme toute mecanique qui derive des ordres de l'etat plutot que de data.js.
if (typeof window !== 'undefined') {
  window.RP_ORDRES_DYNAMIQUES = window.RP_ORDRES_DYNAMIQUES || [];
  if (!window.RP_ORDRES_DYNAMIQUES.includes(ordresCommerceDuLocal)) {
    window.RP_ORDRES_DYNAMIQUES.push(ordresCommerceDuLocal);
  }
}

// RECETTES DES PRODUITS, MEMORISEES POUR L'ECRAN. Meme role de relais que
// RP_CPJ_FORMES, et la meme absence d'autorite : ces chiffres servent a ANNONCER
// au proprietaire ce que sa commande va couter. Ce qu'on envoie au serveur reste
// le seul nombre de lots voulus, et c'est lui qui recalcule tout.
let RP_CPJ_RECETTES = {};

// MESSAGES A REAFFICHER APRES UN RENDU. Une action reussie change le stock, les
// matieres, les PA et la caisse : l'ecran est donc redessine en entier. Sans ce
// relais, le compte rendu de l'action disparaitrait avec l'ancien HTML -- et le
// proprietaire ne saurait pas ce qui vient de se passer.
let RP_CPJ_MESSAGES = {};

// Ecrit un message SOUS la ligne concernee. Aucune modale : un refus se lit la
// ou l'on vient de cliquer, c'est tout l'objet de ce lot.
function commercePjMessage(cleLigne, texte, ok) {
  const e = document.getElementById('cpj-msg-' + cleLigne);
  if (!e) return;
  e.textContent = texte || '';
  e.className = 'cpj-msg' + (texte ? (ok ? ' cpj-msg-ok' : ' cpj-msg-ko') : '');
}

// Les recettes des references du commerce, en UN seul temps d'attente. On
// interroge le serveur generique par generique -- jamais reference par
// reference -- puis on retient la recette exacte de chacune.
async function commercePjRecettesDesReferences(refs) {
  const generiques = {};
  Object.keys(refs).forEach(function (id) {
    if (refs[id] && refs[id].recette_id) generiques[refs[id].generique_id] = true;
  });
  const listes = await Promise.all(Object.keys(generiques).map(function (g) {
    return sbGeneriqueRecettesSysteme(g).catch(function () { return []; });
  }));
  const parId = {};
  listes.forEach(function (l) { l.forEach(function (rec) { parId[rec.recette_id] = rec; }); });
  const parReference = {};
  Object.keys(refs).forEach(function (id) {
    const rec = refs[id] && parId[refs[id].recette_id];
    if (rec) parReference[id] = rec;
  });
  return parReference;
}

// ---------------------------------------------------------------------------
// FACE PROPRIETAIRE — UN SEUL ECRAN, TROIS SECTIONS
// ---------------------------------------------------------------------------
// CE QUE CET ECRAN REMPLACE. Il y avait un sommaire, deux sous-menus, et quatre
// formulaires de reglage en sous-fenetre (« Parametrer » d'une matiere, « Fixer
// le prix », « Stock maximum »), puis une cinquieme pour lancer une fabrication.
// Le proprietaire ne voyait donc jamais son commerce : il naviguait dedans. Tout
// tient maintenant sur un ecran -- caisse, produits, matieres -- et chaque geste
// se fait DANS la ligne : un champ quitte, une ligne enregistree ; un bouton
// cliqué, une commande partie. Aucun refus n'ouvre de fenetre : il s'ecrit sous
// la ligne qui l'a provoque.
//
// AUCUNE MECANIQUE NE CHANGE ICI. Les primitives appelees sont celles qui
// existaient, aux memes arguments : le serveur reste seul juge du prix maximal,
// du plafond de stock, des PA, de la caisse et de l'identite. Cet ecran ne
// calcule rien qui fasse autorite -- il affiche, il recueille, il envoie.
async function commercePjEcranGestion(ctx) {
  // LA MACHINE NE CLIGNOTE PAS. commercePjChargement peint la modale ORDINAIRE,
  // donc il retire la coque : acceptable a la premiere ouverture, insupportable
  // ensuite, puisque chaque geste de cet ecran le redessine (produire, vendre,
  // donner, prelever). Quand le terminal est deja allume, on ne touche donc a
  // rien pendant le rechargement -- l'ancien ecran reste lisible et les valeurs
  // se remplacent d'un coup, sans passage par un carre noir.
  const boite = document.querySelector('#modal-postes .modal-box');
  if (!boite || !boite.classList.contains('cpj-machine')) {
    commercePjChargement(tCommercePJ('commercepj.titre.gestion'));
  }
  if (!ctx || !ctx.fonds) ctx = await commercePjContexte();
  const f = ctx.fonds || {}, cur = commercePjDevise();
  const refs   = f.references || {};
  const stocks = f.stockReferences || {};
  const maxis  = (f.parametres || {}).stockMaxReferences || {};
  const cles   = Object.keys(refs);

  // Les couts de revient partent ENSEMBLE. C'etait une boucle `await` sequentielle
  // -- un aller-retour reseau par produit avant le premier pixel affiche. Meme
  // nombre d'appels, un seul temps d'attente.
  const couts = {};
  (await Promise.all(cles.map(function (id) {
    return sbFondsCoutRevientReference(ctx.fondsId, id)
      .catch(function () { return null; })
      .then(function (c) { return [id, c]; });
  }))).forEach(function (p) { couts[p[0]] = p[1]; });

  const matieres = await sbFondsMatieresAccessibles(ctx.fondsId);
  const types = await sbGetCatalogueTypes();
  RP_CPJ_RECETTES = await commercePjRecettesDesReferences(refs);
  const libelleType = {};
  types.forEach(function (t) { libelleType[t.id] = t.libelle; });
  const mesTypes = (f.typesAutorises || []).map(function (id) { return libelleType[id] || id; });
  const plafondMat = matieres.length ? Number(matieres[0].plafond_pays) || 0 : 0;
  const mesPa = (typeof state !== 'undefined' && typeof state.pa === 'number') ? state.pa : null;

  let h = '';

  // --- IDENTITE : deux lignes, pas une section. Le proprietaire sait ou il est.
  h += '<div class="cpj-note">' +
    commercePjEchapper(tCommercePJ('commercepj.gestion.local')) + ' : ' +
    commercePjEchapper((f.implantation && f.implantation.roomId) || '—') + ' · ' +
    commercePjEchapper(tCommercePJ('commercepj.gestion.activites')) + ' : ' +
    commercePjEchapper(mesTypes.length ? mesTypes.join(', ') : '—') + '</div>';

  // --- CAISSE -------------------------------------------------------------
  // LES PA SONT AFFICHES ICI parce qu'ils sont devenus une ressource de cet
  // ecran : produire depuis la ligne les consomme. Sans ce chiffre, « PA
  // insuffisants » serait un refus qu'on ne peut pas anticiper.
  h += '<div class="cpj-titre">' + commercePjEchapper(tCommercePJ('commercepj.tab.caisse')) + '</div>';
  h += '<div class="cpj-caisse">';
  h += '<div class="cpj-solde"><small>' +
    commercePjEchapper(tCommercePJ('commercepj.caisse.solde')) + '</small>' +
    commercePjMontant(f.caisse || 0) + ' ' + cur + '</div>';
  if (mesPa !== null) {
    h += '<div class="cpj-solde"><small>' +
      commercePjEchapper(tCommercePJ('commercepj.caisse.vosPa')) + '</small>' + mesPa + '</div>';
  }
  h += '<div class="cpj-caisse-actions">';
  h += '<input id="cpj-caisse-montant" class="cpj-champ" type="number" min="1" step="1" value="100" ' +
    'aria-label="' + commercePjEchapper(tCommercePJ('commercepj.caisse.montant')) + '"><em>' + cur + '</em>';
  h += commercePjTouche("commercePjCaisseMouvement('apport')",
    tCommercePJ('commercepj.caisse.apport'), true);
  h += commercePjTouche("commercePjCaisseMouvement('prelevement')",
    tCommercePJ('commercepj.caisse.prelever'));
  h += '</div></div>';
  h += '<div class="cpj-msg" id="cpj-msg-caisse"></div>';

  // --- PRODUITS VENDUS ----------------------------------------------------
  h += '<div class="cpj-titre">' + commercePjEchapper(tCommercePJ('commercepj.tab.produits')) + '</div>';
  if (!mesTypes.length) {
    h += '<div class="cpj-vide">' +
      commercePjEchapper(tCommercePJ('commercepj.gestion.aucuneActivite')) + '</div>';
  } else if (!cles.length) {
    h += '<div class="cpj-vide">' +
      commercePjEchapper(tCommercePJ('commercepj.gestion.aucunProduit')) + '</div>';
  } else {
    h += commercePjEntetes('commercepj.col.produit', 'commercepj.col.prixVente');
    cles.forEach(function (id) {
      const r = refs[id] || {};
      const stock = Math.max(0, Number(stocks[id]) || 0);
      const maxi  = Math.max(0, Number(maxis[id]) || 0);
      const c = couts[id];
      const dispo = c && c.disponible === true;
      const rec = RP_CPJ_RECETTES[id] || null;

      let etat;
      if (r.active !== true)   etat = tCommercePJ('commercepj.ref.retire');
      else if (stock <= 0)     etat = tCommercePJ('commercepj.ref.rupture');
      else                     etat = tCommercePJ('commercepj.ref.enVente');
      // LE PLAFOND DE PRIX VIENT DU SERVEUR et n'est jamais recalcule ici : c'est
      // une politique de pays. On l'annonce a cote du champ plutot que de laisser
      // le proprietaire decouvrir un refus.
      let sous = etat;
      if (dispo) {
        sous += ' · ' + tCommercePJ('commercepj.ref.cout') + ' ' +
                commercePjMontant(c.coutUnitaire) + ' ' + cur +
                ' · ' + tCommercePJ('commercepj.ref.plafond') + ' ' +
                commercePjMontant(c.prixMaximum) + ' ' + cur;
      } else {
        sous += ' · ' + tCommercePJ('commercepj.ref.sansCoutCourt');
      }

      h += '<div class="cpj-grille">';
      h += commercePjPicto(r.icon);
      h += '<div class="cpj-nom"><span class="cpj-nom-t">' +
             commercePjEchapper(r.nom || '—') + '</span>' +
           '<span class="cpj-sous">' + commercePjEchapper(sous) + '</span>';
      h += '<span class="cpj-actions">';
      // FABRICATION EN PLACE. Un produit sans recette ne se fabrique pas : on ne
      // propose alors ni nombre de lots ni bouton, et on le dit.
      if (rec) {
        h += '<em class="cpj-etiq">' + commercePjEchapper(tCommercePJ('commercepj.prod.lots')) + '</em>' +
          '<input id="cpj-lots-' + id + '" class="cpj-champ cpj-mini" type="number" min="1" max="99" ' +
            'step="1" value="1" oninput="commercePjResumeLots(\'' + id + '\')" aria-label="' +
            commercePjEchapper(tCommercePJ('commercepj.prod.lots')) + '">' +
          commercePjTouche("commercePjProduireLots('" + id + "')",
            tCommercePJ('commercepj.ref.produire'), true);
      } else {
        h += '<em class="cpj-etiq">' +
          commercePjEchapper(tCommercePJ('commercepj.recette.aucune')) + '</em>';
      }
      h += commercePjTouche("commercePjActiver('" + id + "'," + (r.active === true ? 'false' : 'true') + ")",
             r.active === true ? tCommercePJ('commercepj.ref.retirer')
                               : tCommercePJ('commercepj.ref.mettreEnVente'));
      h += '</span>';
      if (rec) h += '<span class="cpj-resume" id="cpj-resume-' + id + '"></span>';
      h += '<span class="cpj-msg" id="cpj-msg-' + id + '"></span>';
      h += '</div>';
      h += '<span class="cpj-num' + (stock <= 0 ? ' cpj-zero' : '') + '" data-l="' +
             commercePjEchapper(tCommercePJ('commercepj.col.stock')) + '">' + stock + '</span>';
      h += '<span class="cpj-cell" data-l="' +
             commercePjEchapper(tCommercePJ('commercepj.col.stockMax')) + '">' +
           '<input id="cpj-r-max-' + id + '" class="cpj-champ" type="number" min="0" step="1" ' +
             'value="' + maxi + '" data-avant="' + maxi + '" ' +
             'onchange="commercePjSauverMaxRef(\'' + id + '\')" aria-label="' +
             commercePjEchapper(tCommercePJ('commercepj.col.stockMax')) + '"></span>';
      h += '<span class="cpj-cell" data-l="' +
             commercePjEchapper(tCommercePJ('commercepj.col.prixVente')) + '">' +
           '<input id="cpj-r-prix-' + id + '" class="cpj-champ" type="number" min="1" step="1" ' +
             (dispo ? 'max="' + Number(c.prixMaximum) + '" ' : 'disabled ') +
             'value="' + (Number(r.prixVente) > 0 ? Number(r.prixVente) : '') + '" ' +
             'data-avant="' + (Number(r.prixVente) > 0 ? Number(r.prixVente) : '') + '" ' +
             'onchange="commercePjSauverPrixRef(\'' + id + '\')" aria-label="' +
             commercePjEchapper(tCommercePJ('commercepj.col.prixVente')) + '">' +
           '<em>' + cur + '</em></span>';
      h += '</div>';
    });
    h += '<div class="cpj-note">' +
      commercePjEchapper(tCommercePJ('commercepj.ref.maxAide')) + '</div>';
  }

  // --- MATIERES PREMIERES -------------------------------------------------
  // UNE SEULE GRANDEUR DEPUIS C7 : le stock maximum. A 0, le commerce n'en veut
  // pas -- et c'est tout ce que le proprietaire a a dire. Il n'y a plus de
  // question « acceptee oui/non » a l'ecran, et le serveur la deduit du chiffre.
  //
  // C8 AJOUTE SON INVENTAIRE PERSONNEL. Le proprietaire est un fournisseur comme
  // un autre : il vend ou donne a son commerce par la MEME primitive que
  // n'importe quel client, sans aucun raccourci -- memes controles de capacite,
  // de caisse, de presence et de possession reelle.
  h += '<div class="cpj-titre">' + commercePjEchapper(tCommercePJ('commercepj.tab.matieres')) + '</div>';
  if (!matieres.length) {
    h += '<div class="cpj-vide">' +
      commercePjEchapper(tCommercePJ('commercepj.global.aucuneMatiere')) + '</div>';
  } else {
    h += commercePjEntetes('commercepj.col.matiere', 'commercepj.col.rachat');
    matieres.forEach(function (m) {
      const cle   = m.matiere;
      const stock = Math.max(0, Number(m.stock) || 0);
      const maxi  = Math.max(0, Number(m.maximum) || 0);
      const prix  = Number(m.prix_achat) || 0;
      const reste = Math.max(0, Number(m.place_restante) || 0);
      const jai   = commercePjQuantiteInventaire(cle);
      const sous  = (maxi <= 0) ? tCommercePJ('commercepj.matiere.refusCourt')
                  : (m.utilisee === true ? tCommercePJ('commercepj.matiere.utilisee') : '');

      h += '<div class="cpj-grille' + (maxi <= 0 ? ' cpj-refuse' : '') + '" id="cpj-lig-' + cle + '">';
      h += commercePjPictoMatiere(cle);
      h += '<div class="cpj-nom"><span class="cpj-nom-t">' +
             commercePjEchapper(commercePjLibelleMatiere(cle)) + '</span>' +
           (sous ? '<span class="cpj-sous">' + commercePjEchapper(sous) + '</span>' : '');
      // APPORT EN PLACE. Les deux touches sont fermees quand l'issue serait un
      // refus certain : rien en poche, ou plus de place. Le serveur refuserait de
      // toute facon -- on ne propose simplement pas un geste sans issue.
      const bloque = (jai <= 0) || (reste <= 0) || (maxi <= 0);
      h += '<span class="cpj-actions">';
      h += '<em class="cpj-etiq">' +
        commercePjEchapper(tCommercePJ('commercepj.appro.vous')) + ' ' +
        '<b class="' + (jai > 0 ? 'cpj-jai' : '') + '">' + jai + '</b></em>';
      h += '<em class="cpj-etiq">' + commercePjEchapper(tCommercePJ('commercepj.appro.quantite')) + '</em>' +
        '<input id="cpj-appro-' + cle + '" class="cpj-champ cpj-mini" type="number" min="1" step="1" ' +
          'value="' + Math.max(1, Math.min(jai || 1, reste || 1)) + '" ' +
          'oninput="commercePjApercuMatiere(\'' + cle + '\')" aria-label="' +
          commercePjEchapper(tCommercePJ('commercepj.appro.quantite')) + '">';
      h += commercePjTouche("commercePjApporterDepuisTerminal('" + cle + "','vente')",
        tCommercePJ('commercepj.appro.vendre'), true, bloque);
      h += commercePjTouche("commercePjApporterDepuisTerminal('" + cle + "','don')",
        tCommercePJ('commercepj.appro.donner'), false, bloque);
      h += '</span>';
      h += '<span class="cpj-resume" id="cpj-resume-mat-' + cle + '"></span>';
      h += '<span class="cpj-msg" id="cpj-msg-mat-' + cle + '"></span>';
      h += '</div>';
      h += '<span class="cpj-num' + (stock <= 0 ? ' cpj-zero' : '') + '" data-l="' +
             commercePjEchapper(tCommercePJ('commercepj.col.stock')) + '">' + stock + '</span>';
      h += '<span class="cpj-cell" data-l="' +
             commercePjEchapper(tCommercePJ('commercepj.col.stockMax')) + '">' +
           '<input id="cpj-m-max-' + cle + '" class="cpj-champ" type="number" min="0" step="1" ' +
             'max="' + (Number(m.plafond_pays) || 0) + '" value="' + maxi + '" data-avant="' + maxi + '" ' +
             'onchange="commercePjSauverMatiere(\'' + cle + '\')" aria-label="' +
             commercePjEchapper(tCommercePJ('commercepj.col.stockMax')) + '"></span>';
      h += '<span class="cpj-cell" data-l="' +
             commercePjEchapper(tCommercePJ('commercepj.col.rachat')) + '">' +
           '<input id="cpj-m-prix-' + cle + '" class="cpj-champ" type="number" min="0" step="0.01" ' +
             'value="' + prix + '" data-avant="' + prix + '" ' +
             'onchange="commercePjSauverMatiere(\'' + cle + '\')" aria-label="' +
             commercePjEchapper(tCommercePJ('commercepj.col.rachat')) + '">' +
           '<em>' + cur + '</em></span>';
      h += '</div>';
    });
    h += '<div class="cpj-note">' +
      commercePjEchapper(tCommercePJ('commercepj.matiere.maxAide', { plafond: plafondMat })) + '</div>';
  }

  // --- TOUCHES DE L'ECRAN -------------------------------------------------
  h += '<div class="cpj-barre">';
  if (mesTypes.length) {
    h += commercePjTouche('commercePjNouvelleReference()', tCommercePJ('commercepj.gestion.nouveau'), true);
  }
  h += commercePjTouche('commercePjEcranTypes()', tCommercePJ('commercepj.gestion.modifierActivites'));
  h += commercePjTouche('commercePjEcranPublic()', tCommercePJ('commercepj.menu.boutique'));
  h += '</div>';

  commercePjMachine(tCommercePJ('commercepj.titre.gestion'), f.enseigne, h);

  // LES RESUMES SONT CALCULES APRES LE RENDU, par les memes fonctions que les
  // saisies suivantes : un seul chemin, donc aucun risque que l'affichage initial
  // et l'affichage apres frappe divergent.
  cles.forEach(function (id) { if (RP_CPJ_RECETTES[id]) commercePjResumeLots(id); });
  matieres.forEach(function (m) { commercePjApercuMatiere(m.matiere); });

  // Et on rend au proprietaire le compte rendu de l'action qui a provoque ce rendu.
  Object.keys(RP_CPJ_MESSAGES).forEach(function (k) {
    commercePjMessage(k, RP_CPJ_MESSAGES[k].texte, RP_CPJ_MESSAGES[k].ok);
  });
  RP_CPJ_MESSAGES = {};
}

// Les deux sous-menus d'hier sont devenus des SECTIONS du meme ecran. On garde
// leurs noms comme portes d'entree : une douzaine de retours (production, prix,
// creation de reference, activites) les appellent, et tous les renommer serait
// le seul vrai risque de ce lot.
function commercePjEcranGlobal(ctx)   { return commercePjEcranGestion(ctx); }
function commercePjEcranArticles(ctx) { return commercePjEcranGestion(ctx); }

// En-tetes d'un tableau. Les deux colonnes de gauche et les deux du milieu sont
// les memes pour les produits et les matieres : seules changent la premiere et
// la derniere. Une seule fonction, donc, et aucune divergence possible.
function commercePjEntetes(cleNom, clePrix) {
  return '<div class="cpj-grille cpj-entetes">' +
    '<span></span>' +
    '<span>' + commercePjEchapper(tCommercePJ(cleNom)) + '</span>' +
    '<span class="cpj-num">' + commercePjEchapper(tCommercePJ('commercepj.col.stock')) + '</span>' +
    '<span class="cpj-cell">' + commercePjEchapper(tCommercePJ('commercepj.col.stockMax')) + '</span>' +
    '<span class="cpj-cell">' + commercePjEchapper(tCommercePJ(clePrix)) + '</span>' +
    '</div>';
}

// ---------------------------------------------------------------------------
// ENREGISTREMENT EN PLACE — UN CHAMP QUITTE, UNE LIGNE PARTIE
// ---------------------------------------------------------------------------
// UN CHAMP REFUSE REVIENT A SA VALEUR. C'est la seule regle a ne pas rater dans
// une saisie en place : laisser a l'ecran un chiffre que le serveur n'a pas
// accepte ferait croire au proprietaire qu'il est enregistre. On restaure donc
// ce que le serveur tient pour vrai, et on nomme le refus.
function commercePjRendreValeur(champ) {
  if (champ) champ.value = champ.dataset.avant || '';
}

function commercePjFixerValeur(champ, valeur) {
  if (!champ) return;
  champ.value = (valeur === null || valeur === undefined) ? '' : valeur;
  champ.dataset.avant = champ.value;
}

// Matieres : les deux champs partent ENSEMBLE, parce que la primitive serveur
// prend les deux. `acceptee` n'est plus une question posee au joueur : elle se
// deduit du maximum, ici comme en base.
async function commercePjSauverMatiere(matiere) {
  const cMax  = document.getElementById('cpj-m-max-' + matiere);
  const cPrix = document.getElementById('cpj-m-prix-' + matiere);
  if (!cMax || !cPrix) return;
  const maxi = Math.max(0, Math.floor(Number(cMax.value) || 0));
  const prix = Math.max(0, Number(cPrix.value) || 0);
  const ctx = await commercePjContexte();
  const r = await sbFondsMatiereParametres(state.char.name, ctx.fondsId, matiere, prix, maxi, maxi > 0);
  if (!r || !r.ok) {
    commercePjRendreValeur(cMax); commercePjRendreValeur(cPrix);
    showToast('—', commercePjRefus(r), false);
    return;
  }
  commercePjFixerValeur(cMax, r.maximum);
  commercePjFixerValeur(cPrix, r.prixAchat);
  const ligne = document.getElementById('cpj-lig-' + matiere);
  if (ligne) ligne.classList.toggle('cpj-refuse', Number(r.maximum) <= 0);
  showToast(tCommercePJ('commercepj.matiere.enregistre'),
    commercePjLibelleMatiere(matiere) + ' — ' +
    (Number(r.maximum) > 0
      ? (r.maximum + ' × ' + commercePjMontant(r.prixAchat) + ' ' + commercePjDevise())
      : tCommercePJ('commercepj.matiere.refusCourt')), true);
}

async function commercePjSauverMaxRef(referenceId) {
  const champ = document.getElementById('cpj-r-max-' + referenceId);
  if (!champ) return;
  const maxi = Math.max(0, Math.floor(Number(champ.value) || 0));
  const ctx = await commercePjContexte();
  const r = await sbFondsReferenceStockMax(state.char.name, ctx.fondsId, referenceId, maxi);
  if (!r || !r.ok) { commercePjRendreValeur(champ); showToast('—', commercePjRefus(r), false); return; }
  commercePjFixerValeur(champ, maxi);
  showToast(tCommercePJ('commercepj.matiere.enregistre'),
    tCommercePJ('commercepj.ref.stockMax') + ' : ' + commercePjMaximumLisible(maxi), true);
}

async function commercePjSauverPrixRef(referenceId) {
  const champ = document.getElementById('cpj-r-prix-' + referenceId);
  if (!champ) return;
  const prix = Math.floor(Number(champ.value) || 0);
  const ctx = await commercePjContexte();
  const r = await sbFondsReferencePrix(state.char.name, ctx.fondsId, referenceId, prix);
  if (!r || !r.ok) { commercePjRendreValeur(champ); showToast('—', commercePjRefus(r), false); return; }
  commercePjFixerValeur(champ, prix);
  showToast(tCommercePJ('commercepj.matiere.enregistre'),
    tCommercePJ('commercepj.ref.prix') + ' : ' + commercePjMontant(prix) + ' ' + commercePjDevise(), true);
}

// ---------------------------------------------------------------------------
// CAISSE — APPORT ET PRELEVEMENT
// ---------------------------------------------------------------------------
// Les deux primitives existaient depuis le socle des fonds de commerce sans
// qu'aucun ecran ne les appelle. C7 les corrige cote serveur (identite exigee,
// numeraire) et les branche ici. Rien n'est calcule : le montant part tel quel,
// le serveur decide, et l'ecran applique le delta exact qu'il annonce.
async function commercePjCaisseMouvement(sens) {
  const champ = document.getElementById('cpj-caisse-montant');
  const montant = Math.max(0, Math.floor(Number(champ && champ.value) || 0));
  if (montant <= 0) {
    commercePjMessage('caisse', commercePjRefus({ raison: 'montant_invalide' }), false); return; }
  const ctx = await commercePjContexte();
  const r = (sens === 'apport')
    ? await sbAlimenterCaisseFonds(state.char.name, ctx.fondsId, montant)
    : await sbRetirerCaisseFonds(state.char.name, ctx.fondsId, montant);
  // UN REFUS RESTE DANS LE TERMINAL, comme tous les autres depuis C8 : il s'ecrit
  // sous la caisse, et l'ecran n'a pas besoin d'etre redessine puisque rien n'a
  // bouge -- le montant saisi reste donc a l'ecran, corrigeable.
  if (!r || !r.ok) { commercePjMessage('caisse', commercePjRefus(r), false); return; }

  // LE PATRIMOINE SUIT LE MOUVEMENT, il ne se recalcule pas. Le serveur a deja
  // ecrit `arg` et `liquide` : on applique le meme delta au miroir local, comme
  // le fait deja le salaire de production.
  const delta = (sens === 'apport') ? -montant : montant;
  if (typeof state !== 'undefined') {
    state.arg     = (Number(state.arg) || 0)     + delta;
    state.liquide = (Number(state.liquide) || 0) + delta;
  }
  if (typeof updateUI === 'function') updateUI();
  const titre = tCommercePJ(sens === 'apport' ? 'commercepj.caisse.apportFait'
                                              : 'commercepj.caisse.preleveFait');
  const sous = commercePjMontant(montant) + ' ' + commercePjDevise() + ' · ' +
               tCommercePJ('commercepj.caisse.solde') + ' ' +
               commercePjMontant(r.caisse) + ' ' + commercePjDevise();
  showToast(titre, sous, true);
  if (typeof addJournalEntry === 'function') addJournalEntry(titre + ' : ' + sous, 'event-good');
  RP_CPJ_MESSAGES.caisse = { texte: '✓ ' + sous, ok: true };
  await commercePjEcranGestion();
}

// ---------------------------------------------------------------------------
// PRODUIRE DEPUIS LA LIGNE — PLUSIEURS LOTS, UNE SEULE COMMANDE
// ---------------------------------------------------------------------------
// L'ancien detour par « Lancer une fabrication » disparait : le proprietaire
// choisit un nombre de lots dans la ligne du produit, voit ce que cela coute, et
// produit. L'ecran intermediaire n'avait pas d'autre appelant que celui-ci -- il
// est donc supprime plutot que laisse mort (voir plus bas, section PRODUIRE).
// La face publique n'est pas touchee : un visiteur fabrique toujours un lot a la
// fois depuis commercePjEcranTravail, par commercePjProduire.
//
// LE RESUME N'EST QU'UN AFFICHAGE. Il multiplie les chiffres de la recette pour
// annoncer la commande ; il ne decide rien, n'interdit rien, et n'est jamais
// renvoye au serveur. C'est le serveur qui recalcule matieres, PA, salaire,
// capacite et caisse, et qui refuse -- avec ses propres nombres.
function commercePjResumeLots(referenceId) {
  const zone = document.getElementById('cpj-resume-' + referenceId);
  const rec  = RP_CPJ_RECETTES[referenceId];
  if (!zone || !rec) return;
  const champ = document.getElementById('cpj-lots-' + referenceId);
  const lots  = Math.max(1, Math.min(99, Math.floor(Number(champ && champ.value) || 1)));
  const parts = [];
  parts.push((Number(rec.portions) || 0) * lots + ' ' + tCommercePJ('commercepj.recette.unites'));
  Object.keys(rec.materiaux || {}).forEach(function (m) {
    parts.push(((Number(rec.materiaux[m]) || 0) * lots) + ' ' + commercePjLibelleMatiere(m));
  });
  const pa = (Number(rec.pa) || 0) * lots;
  if (pa > 0) parts.push(pa + ' ' + tCommercePJ('commercepj.prod.pa'));
  const valeurPa = commercePjValeurPa();
  if (valeurPa !== null && pa > 0) {
    parts.push(tCommercePJ('commercepj.travail.salaire') + ' ' +
               commercePjMontant(pa * valeurPa) + ' ' + commercePjDevise());
  }
  zone.textContent = '→ ' + parts.join(' · ');
}

async function commercePjProduireLots(referenceId) {
  const champ = document.getElementById('cpj-lots-' + referenceId);
  const lots  = Math.max(1, Math.min(99, Math.floor(Number(champ && champ.value) || 1)));
  commercePjMessage(referenceId, tCommercePJ('commercepj.prod.enCours'), true);
  const ctx = await commercePjContexte();
  // UNE SEULE CLE POUR TOUTE LA COMMANDE : un double clic rejoue la meme cle et ne
  // produit donc pas une seconde fois les memes lots.
  const r = await sbFondsReferenceProduireLots(nouvelleCleProduction(), state.char.name,
                                               ctx.fondsId, referenceId, lots);
  // PAS DE MODALE SUR UN REFUS. Le motif s'ecrit sous la ligne, avec les chiffres
  // que le serveur a opposes -- matiere manquante, capacite, PA, caisse.
  if (!r || !r.ok) { commercePjMessage(referenceId, commercePjRefus(r), false); return; }
  if (r.rejeu === true) { await commercePjEcranGestion(); return; }

  // L'ECRAN SUIT CE QUE LE SERVEUR A DEJA ECRIT : ni PA ni salaire ne sont
  // recalcules ici, on applique ce que la transaction rend.
  if (typeof state !== 'undefined') {
    if (typeof r.paRestants === 'number') state.pa = r.paRestants;
    if (Number(r.salaire) > 0) {
      state.arg     = (Number(state.arg) || 0)     + Number(r.salaire);
      state.liquide = (Number(state.liquide) || 0) + Number(r.salaire);
    }
  }
  if (typeof updateUI === 'function') updateUI();
  const compte = r.quantite + ' ' + tCommercePJ('commercepj.recette.unites') +
    (Number(r.salaire) > 0
      ? (' · ' + commercePjMontant(r.salaire) + ' ' + commercePjDevise() + ' ' +
         tCommercePJ('commercepj.prod.verses'))
      : '');
  if (typeof addJournalEntry === 'function') {
    addJournalEntry(tCommercePJ('commercepj.produire.fait') + ' : ' + compte, 'event-good');
  }
  RP_CPJ_MESSAGES[referenceId] = { texte: '✓ ' + compte, ok: true };
  await commercePjEcranGestion();
}

// ---------------------------------------------------------------------------
// VENDRE OU DONNER SES PROPRES MATIERES, DEPUIS LE TERMINAL
// ---------------------------------------------------------------------------
// AUCUN RACCOURCI PARCE QU'IL EST PROPRIETAIRE. C'est la primitive d'apport de
// C6, celle qu'utilise n'importe quel client : possession reelle relue en base,
// presence physique, capacite restante, caisse du commerce, prix de rachat
// configure, idempotence par cle. Le proprietaire est un fournisseur comme un
// autre -- et il l'etait deja par la face publique, qui coutait deux ecrans.
function commercePjApercuMatiere(matiere) {
  const zone = document.getElementById('cpj-resume-mat-' + matiere);
  if (!zone) return;
  const champ = document.getElementById('cpj-appro-' + matiere);
  const qte   = Math.max(0, Math.floor(Number(champ && champ.value) || 0));
  const prix  = Number((document.getElementById('cpj-m-prix-' + matiere) || {}).value) || 0;
  if (qte <= 0) { zone.textContent = ''; return; }
  zone.textContent = qte + ' ' + commercePjLibelleMatiere(matiere) + ' → ' +
    commercePjMontant(qte * prix) + ' ' + commercePjDevise();
}

async function commercePjApporterDepuisTerminal(matiere, mode) {
  const champ = document.getElementById('cpj-appro-' + matiere);
  const qte   = Math.max(0, Math.floor(Number(champ && champ.value) || 0));
  if (qte <= 0) {
    commercePjMessage('mat-' + matiere, commercePjRefus({ raison: 'quantite_invalide' }), false); return; }
  commercePjMessage('mat-' + matiere, tCommercePJ('commercepj.prod.enCours'), true);
  const ctx = await commercePjContexte();
  const r = await sbFondsMatiereApporter(nouvelleCleApport(), state.char.name,
                                         ctx.fondsId, matiere, qte, mode);
  if (!r || !r.ok) { commercePjMessage('mat-' + matiere, commercePjRefus(r), false); return; }

  // L'inventaire rendu par la transaction fait autorite : on ne le recalcule pas.
  if (r.inventory && typeof state !== 'undefined') {
    state.inventory = r.inventory;
    if (typeof renderInventory === 'function') renderInventory();
  }
  if (Number(r.montant) > 0 && typeof state !== 'undefined') {
    state.arg     = (Number(state.arg) || 0)     + Number(r.montant);
    state.liquide = (Number(state.liquide) || 0) + Number(r.montant);
  }
  if (typeof updateUI === 'function') updateUI();

  let compte = commercePjLibelleMatiere(matiere) + ' × ' + r.quantite;
  if (Number(r.montant) > 0) compte += ' · ' + commercePjMontant(r.montant) + ' ' + commercePjDevise();
  // LE SERVEUR BORNE LA QUANTITE et le dit : une commande partiellement honoree
  // n'est pas un echec, mais le proprietaire doit le savoir.
  if (Number(r.quantite) < Number(r.demandee)) {
    compte += ' · ' + tCommercePJ('commercepj.appro.partiel',
      { faites: r.quantite, voulues: r.demandee });
  }
  const titre = (mode === 'don') ? tCommercePJ('commercepj.appro.donne')
                                 : tCommercePJ('commercepj.appro.vendu');
  if (typeof addJournalEntry === 'function') addJournalEntry(titre + ' : ' + compte);
  RP_CPJ_MESSAGES['mat-' + matiere] = { texte: '✓ ' + compte, ok: true };
  await commercePjEcranGestion();
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
  RP_CPJ_GENERIQUES = {};
  gens.forEach(function (g) {
    RP_CPJ_GENERIQUES[g.generique_id] = g.libelle;
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
    commercePjBouton('commercePjEcranArticles()', tCommercePJ('commercepj.retour.gestion')) + '</div>';
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

// FORMES PROPOSEES AU DERNIER ECRAN. Un relais entre deux ecrans, pas une source
// de verite : le serveur revalide la recette et son generique a la creation. On
// evite ainsi de faire passer des libelles -- avec leurs apostrophes et leurs
// tirets longs -- dans un attribut onclick.
let RP_CPJ_FORMES = {};

// Libelles des generiques, memorises par l'ecran qui les liste. Meme role de
// relais que RP_CPJ_FORMES, et meme absence d'autorite.
let RP_CPJ_GENERIQUES = {};

async function commercePjChoisirGenerique(generiqueId) {
  RP_CPJ_FORMES = {};
  commercePjChargement(tCommercePJ('commercepj.titre.reference'));
  const recs = await sbGeneriqueRecettesSysteme(generiqueId);
  let html = '<div style="padding:1.1rem">';
  if (recs.length) {
    html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.3rem">' +
      commercePjEchapper(tCommercePJ('commercepj.nouvelle.recette')) + '</div>';
    html += '<p style="color:#8a8060;font-size:.82rem;margin-bottom:.9rem">' +
      commercePjEchapper(tCommercePJ('commercepj.nouvelle.recetteAide')) + '</p>';
    // UNE ACTION EXPLICITE (29 septembre 2026). La carte ETAIT cliquable, mais rien
    // ne le disait : ni bouton, ni libelle d'action. Le test humain s'est arrete la,
    // le joueur croyant l'ecran terminal. On prefere un bouton comprehensible a une
    // carte mysterieusement cliquable -- la carte reste cliquable pour qui l'a
    // devine, le bouton le dit pour tous les autres.
    recs.forEach(function (rec) {
      RP_CPJ_FORMES[rec.recette_id] = { generiqueId: generiqueId, rec: rec };
      html += '<div onclick="commercePjEcranHabillage(\'' + commercePjEchapper(generiqueId) + '\',\'' +
        commercePjEchapper(rec.recette_id) + '\')" ' +
        'style="border:1px solid #2a2620;padding:.6rem .7rem;margin-bottom:.4rem;cursor:pointer">' +
        '<div style="color:#e0d8c0;font-size:.9rem;margin-bottom:.25rem">' + commercePjEchapper(rec.label) + '</div>' +
        commercePjRecetteLisible(rec) +
        '<div style="margin-top:.5rem">' +
          commercePjBouton("commercePjEcranHabillage('" + commercePjEchapper(generiqueId) + "','" +
            commercePjEchapper(rec.recette_id) + "')",
            tCommercePJ('commercepj.nouvelle.choisirForme'), true) +
        '</div></div>';
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
  const choix = RP_CPJ_FORMES[recetteId] || null;
  let html = '<div style="padding:1.1rem">';
  html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.3rem">' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.habillage')) + '</div>';
  html += '<p style="color:#8a8060;font-size:.82rem;margin-bottom:.9rem">' +
    commercePjEchapper(tCommercePJ('commercepj.nouvelle.habillageAide')) + '</p>';

  // TROIS NIVEAUX, TROIS LIGNES (29 septembre 2026). Le joueur confondait le type
  // de produit, la fabrication et le nom de SA reference : il croyait devoir
  // vendre un « T-shirt de Port-Sainte-Marie ». On les nomme separement, et ce
  // qu'il saisit est visiblement la troisieme chose.
  if (choix) {
    html += '<div style="border:1px solid #2a2620;padding:.55rem .75rem;margin-bottom:.9rem">';
    html += commercePjLigne(tCommercePJ('commercepj.nouvelle.generiqueRetenu'),
      commercePjEchapper(RP_CPJ_GENERIQUES[generiqueId] || generiqueId));
    html += commercePjLigne(tCommercePJ('commercepj.nouvelle.formeRetenue'),
      commercePjEchapper(choix.rec.label));
    html += commercePjRecetteLisible(choix.rec);
    html += '</div>';
  }
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
  commercePjEcranArticles();
}

// ---------------------------------------------------------------------------
// PRODUIRE — L'ECRAN INTERMEDIAIRE A DISPARU
// ---------------------------------------------------------------------------
// commercePjEcranProduire est SUPPRIMEE apres audit (29 septembre 2026). C'etait
// l'ecran « Lancer une fabrication », et il n'etait atteint que depuis la gestion
// du proprietaire, qui fabrique maintenant dans la ligne du produit. Recherche
// faite sur tout le depot avant de la retirer : plus aucun appelant, ni dans les
// .js, ni dans plateau.html, ni dans un onclick construit -- la face publique,
// elle, appelle commercePjProduire directement depuis commercePjEcranTravail.
//
// On ne garde donc pas un module mort : dans ce fichier, un export orphelin a
// deja fait tomber le cron de minuit, et une fonction sans appelant est la meme
// dette a retardement.


// La cle de requete est fabriquee A L'OUVERTURE de l'ecran et passee telle quelle :
// un double clic rejoue la meme cle et ne produit donc qu'un seul lot.
//
// LE CHEMIN DU VISITEUR, ET LUI SEUL depuis C8. Le proprietaire ne passe plus par
// ici : il commande ses lots depuis son terminal (commercePjProduireLots), qui
// appelle la porte multi-lots. Les deux chemins tombent sur la MEME economie
// serveur -- fonds_reference_produire n'est plus qu'un relais vers elle avec
// 1 lot. `origine` ne sert toujours qu'a choisir l'ecran de retour, et seule la
// valeur 'publique' est encore emise ; l'autre branche reste un repli inoffensif.
async function commercePjProduire(referenceId, requete, origine) {
  const ctx = await commercePjContexte();
  const r = await sbFondsReferenceProduire(requete, state.char.name, ctx.fondsId, referenceId);
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  if (r.rejeu !== true && typeof addJournalEntry === 'function') {
    addJournalEntry('Fabrication : ' + r.quantite + ' unité(s)'
      + (r.salaire > 0 ? (' — salaire ' + commercePjMontant(r.salaire) + ' ' + commercePjDevise()) : '')
      + '.', 'event-good');
  }
  // Le salaire vient du SERVEUR, jamais d'un calcul refait ici.
  showToast(tCommercePJ('commercepj.produire.fait'),
    r.quantite + ' ' + tCommercePJ('commercepj.recette.unites') +
    (r.salaire > 0 ? (' · +' + commercePjMontant(r.salaire) + ' ' + commercePjDevise()) : ''), true);
  // L'ECRAN SUIT CE QUE LE SERVEUR A DEJA ECRIT. On ne recalcule rien : `paRestants`
  // et `salaire` viennent de la transaction elle-meme. Un rejeu ne rend pas ces
  // champs et ne touche donc a rien -- c'est voulu, il n'a rien preleve ni verse.
  if (r.rejeu !== true && typeof state !== 'undefined') {
    if (typeof r.paRestants === 'number') state.pa = r.paRestants;
    if (r.salaire > 0) {
      state.arg     = (Number(state.arg) || 0)     + Number(r.salaire);
      state.liquide = (Number(state.liquide) || 0) + Number(r.salaire);
    }
  }
  if (typeof updateUI === 'function') updateUI();
  if (origine === 'publique') commercePjEcranTravail();
  else commercePjEcranArticles();
}

// ---------------------------------------------------------------------------
// PRIX — PLUS D'ECRAN DEDIE
// ---------------------------------------------------------------------------
// commercePjEcranPrix et commercePjFixerPrix sont SUPPRIMEES : le prix de vente
// se saisit desormais dans la case du tableau (commercePjSauverPrixRef), et le
// cout de revient comme le prix maximal autorise s'affichent a cote du champ.
// Les garder aurait laisse deux chemins pour la meme decision -- et un module
// mort dans un fichier ou un export orphelin a deja fait tomber un cron.
// Le plafond vient toujours du serveur et n'est jamais recalcule ici.

async function commercePjActiver(referenceId, actif) {
  const ctx = await commercePjContexte();
  const r = await sbFondsReferenceActiver(state.char.name, ctx.fondsId, referenceId, actif === true);
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  commercePjEcranArticles();
}

// ---------------------------------------------------------------------------
// FACE PUBLIQUE — TROIS USAGES, TROIS PORTES
// ---------------------------------------------------------------------------
// Le test humain a montre que l'ancien ecran unique ne disait qu'une chose :
// « achetez ». Or un commerce PJ est trois lieux a la fois -- une boutique, un
// atelier, et un acheteur de matieres. Un sommaire les nomme, sur la meme forme
// que le menu de gestion : le joueur reconnait le motif et comprend d'emblee ce
// qu'il peut faire ici.
async function commercePjEcranPublic(ctx) {
  commercePjChargement(tCommercePJ('commercepj.public.titre'));
  if (!ctx || !ctx.fonds) ctx = await commercePjContexte();
  const f = ctx.fonds || {};

  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.05rem;color:#E8C97A">' +
    commercePjEchapper(f.enseigne || '—') + '</div>';
  html += '<div style="font-size:.76rem;color:#6a6050;margin-bottom:.9rem">' +
    commercePjEchapper(tCommercePJ('commercepj.boutique.tenu')) + ' ' +
    commercePjEchapper(String(f.proprietaire || '').replace(/^pj:/, '')) + '</div>';

  [['commercePjEcranBoutique()',           'commercepj.public.boutique', 'commercepj.public.boutiqueAide', 'ti-shopping-cart'],
   ['commercePjEcranTravail()',            'commercepj.public.produire', 'commercepj.public.produireAide', 'ti-hammer'],
   ['commercePjEcranMatieresPubliques()',  'commercepj.public.matieres', 'commercepj.public.matieresAide', 'ti-package']
  ].forEach(function (e) {
    html += '<div onclick="' + e[0] + '" style="border:1px solid #2a2620;padding:.8rem .9rem;margin-bottom:.6rem;cursor:pointer">' +
      '<div style="color:#e0d8c0;font-size:.95rem;margin-bottom:.2rem">' +
        commercePjEchapper(tCommercePJ(e[1])) + '</div>' +
      '<div style="font-size:.8rem;color:#8a8060">' +
        commercePjEchapper(tCommercePJ(e[2])) + '</div></div>';
  });

  // Le proprietaire present chez lui utilise les fonctions publiques comme tout
  // le monde ; sa gestion reste une porte separee, jamais melangee a celle-ci.
  if (ctx.jeSuisProprietaire) {
    html += '<div style="margin-top:.9rem">' +
      commercePjBouton('commercePjEcranGestion()', tCommercePJ('commercepj.retour.gestion')) + '</div>';
  }
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.public.titre'), html);
}

// ---------------------------------------------------------------------------
// BOUTIQUE — CE QUI EST REELLEMENT EN VENTE, ET RIEN D'AUTRE
// ---------------------------------------------------------------------------
async function commercePjEcranBoutique(ctx) {
  commercePjChargement(tCommercePJ('commercepj.titre.boutique'));
  if (!ctx || !ctx.fonds) ctx = await commercePjContexte();
  const f = ctx.fonds, cur = commercePjDevise();
  const refs = f.references || {}, stocks = f.stockReferences || {};
  const actives = Object.keys(refs).filter(function (id) { return refs[id] && refs[id].active === true; });

  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.05rem;color:#E8C97A;margin-bottom:.9rem">' +
    commercePjEchapper(f.enseigne || '—') + '</div>';

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
    html += commercePjLigne(tCommercePJ('commercepj.ref.stock'), stock);
    if (stock <= 0) {
      html += '<div style="font-size:.76rem;color:#8c6a3a;margin-top:.25rem">' +
        commercePjEchapper(tCommercePJ('commercepj.ref.rupture')) + '</div>';
    }
    html += '<div style="margin-top:.5rem">' +
      commercePjBouton("commercePjFicheProduit('" + id + "')",
        tCommercePJ('commercepj.boutique.acheter'), true, stock <= 0) + '</div>';
    html += '</div>';
  });

  html += '<div style="margin-top:.9rem">' +
    commercePjBouton('commercePjEcranPublic()', tCommercePJ('commercepj.public.retour')) + '</div>';
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.titre.boutique'), html);
}

// ---------------------------------------------------------------------------
// PRODUIRE — LE COMMERCE EST AUSSI UN LIEU DE TRAVAIL
// ---------------------------------------------------------------------------
// LE PERIMETRE EST CELUI DU COMMERCE, PAS CELUI DE SES ACTIVITES : on ne fabrique
// que les references que CE commerce a decide de referencer, et seulement celles
// qui ont une recette systeme. C'est la difference entre « ce qu'on pourrait
// vendre ici » et « ce qu'on y fabrique ».
//
// Le visiteur apporte ses PA. Le commerce fournit ses matieres et paie le
// travail. Le produit fini rejoint le stock du commerce -- jamais l'inventaire du
// producteur. C'est exactement la boucle des 13 commerces PNJ du jeu.
async function commercePjEcranTravail(ctx) {
  commercePjChargement(tCommercePJ('commercepj.travail.titre'));
  if (!ctx || !ctx.fonds) ctx = await commercePjContexte();
  const f = ctx.fonds || {}, cur = commercePjDevise();
  const refs = f.references || {}, stocks = f.stockReferences || {};
  const maxis = (f.parametres || {}).stockMaxReferences || {};
  const stockMat = f.stockMatieres || {};
  const salaireParPa = commercePjValeurPa();

  // Une reference n'est fabricable que si elle porte une recette. On interroge le
  // serveur generique par generique, puis on retient la recette exacte.
  const ids = Object.keys(refs).filter(function (id) { return refs[id] && refs[id].recette_id; });
  const parGenerique = {};
  ids.forEach(function (id) { parGenerique[refs[id].generique_id] = true; });
  const recettes = {};
  const gens = Object.keys(parGenerique);
  for (let i = 0; i < gens.length; i++) {
    const liste = await sbGeneriqueRecettesSysteme(gens[i]);
    liste.forEach(function (rec) { recettes[rec.recette_id] = rec; });
  }

  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Playfair Display,serif;font-size:1.05rem;color:#E8C97A;margin-bottom:.3rem">' +
    commercePjEchapper(f.enseigne || '—') + '</div>';
  html += '<p style="color:#8a8060;font-size:.8rem;margin:0 0 .9rem">' +
    commercePjEchapper(tCommercePJ('commercepj.travail.aide')) + '</p>';

  const fabricables = ids.filter(function (id) { return recettes[refs[id].recette_id]; });
  if (!fabricables.length) {
    html += '<p style="color:#8a8060;font-size:.85rem;font-style:italic">' +
      commercePjEchapper(tCommercePJ('commercepj.travail.aucun')) + '</p>';
  }
  fabricables.forEach(function (id) {
    const r = refs[id], rec = recettes[r.recette_id];
    const stock = Math.max(0, Number(stocks[id]) || 0);
    const maxi  = Math.max(0, Number(maxis[id]) || 0);
    const salaire = (salaireParPa === null) ? null
      : Math.max(0, Number(rec.pa) || 0) * salaireParPa;
    // Le lot est INDIVISIBLE : on annonce donc le refus avant le clic plutot que
    // de laisser le joueur decouvrir qu'un maximum trop bas l'interdit a jamais.
    const lotTient = (maxi === 0) || (stock + Number(rec.portions) <= maxi);
    let matieresOk = true;
    Object.keys(rec.materiaux || {}).forEach(function (m) {
      if ((Number(stockMat[m]) || 0) < (Number(rec.materiaux[m]) || 0)) matieresOk = false;
    });

    html += '<div style="border:1px solid #2a2620;padding:.7rem .8rem;margin-bottom:.6rem">';
    html += '<div style="color:#e0d8c0;font-size:.95rem;margin-bottom:.1rem">' +
      commercePjEchapper(r.nom || '—') + '</div>';
    html += '<div style="font-size:.76rem;color:#6a6050;margin-bottom:.45rem">' +
      commercePjEchapper(tCommercePJ('commercepj.travail.fabrication')) + ' : ' +
      commercePjEchapper(rec.label) + '</div>';
    html += commercePjRecetteLisible(rec);
    html += '<div style="margin-top:.45rem">';
    html += commercePjLigne(tCommercePJ('commercepj.travail.rendement'),
      rec.portions + ' ' + tCommercePJ('commercepj.recette.unites'));
    if (salaire !== null) {
      html += commercePjLigne(tCommercePJ('commercepj.travail.salaire'),
        '<b style="color:#6fa07a">' + commercePjMontant(salaire) + ' ' + cur + '</b>');
    }
    html += commercePjLigne(tCommercePJ('commercepj.travail.stockCommerce'),
      stock + ' / ' + commercePjEchapper(commercePjMaximumLisible(maxi)));
    html += '</div>';

    html += '<div style="font-size:.74rem;letter-spacing:.06em;color:#6a6050;margin:.5rem 0 .2rem">' +
      commercePjEchapper(tCommercePJ('commercepj.travail.matieresDispo')) + '</div>';
    Object.keys(rec.materiaux || {}).forEach(function (m) {
      const a = Math.max(0, Number(stockMat[m]) || 0), b = Number(rec.materiaux[m]) || 0;
      html += commercePjLigne(commercePjLibelleMatiere(m),
        '<span style="color:' + (a >= b ? '#6fa07a' : '#a05a4a') + '">' + a + ' / ' + b + '</span>');
    });

    if (!lotTient) {
      html += '<div style="font-size:.76rem;color:#8c6a3a;margin-top:.4rem">' +
        commercePjEchapper(tCommercePJ('commercepj.refus.stock_max_reference_depasse',
          { rendement: rec.portions, maximum: maxi, stock: stock })) + '</div>';
    }
    html += '<div style="margin-top:.55rem">' +
      commercePjBouton("commercePjProduire('" + id + "','" + nouvelleCleProduction() + "','publique')",
        tCommercePJ('commercepj.travail.produire'), true, !lotTient || !matieresOk) + '</div>';
    html += '</div>';
  });

  html += '<div style="margin-top:.9rem">' +
    commercePjBouton('commercePjEcranPublic()', tCommercePJ('commercepj.public.retour')) + '</div>';
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.travail.titre'), html);
}

// VALEUR D'UN PA DE TRAVAIL — AUCUN NOMBRE N'EST ECRIT ICI.
//
// Le socle du jeu possede deja ce chiffre a deux endroits qui se font face : la
// constante serveur `cout_main_oeuvre_pa_alimentaire`, seule autorite, et son
// miroir client `COUT_MAIN_OEUVRE_PA_ALIMENTAIRE` (plateau-actions-illegales-
// rumeurs.js), que les 13 commerces PNJ affichent depuis toujours. On lit le
// miroir, comme eux : c'est la forme la plus coherente avec l'existant, et cela
// n'ajoute pas une troisieme copie du meme nombre. Deduplicaer les deux serait une
// refonte du socle, explicitement hors de ce lot.
//
// FAIL-CLOSED : si le miroir manque, on n'affiche PAS de salaire plutot que d'en
// inventer un. Le serveur reste de toute facon le seul a le calculer et a le
// verser -- cet ecran ne fait qu'annoncer.
function commercePjValeurPa() {
  return (typeof COUT_MAIN_OEUVRE_PA_ALIMENTAIRE === 'number')
    ? COUT_MAIN_OEUVRE_PA_ALIMENTAIRE : null;
}

// ---------------------------------------------------------------------------
// MATIERES PREMIERES — CE QUE LE COMMERCE ACCEPTE D'ACHETER
// ---------------------------------------------------------------------------
// On n'affiche que les matieres dont le stock maximum est superieur a zero. Le
// serveur refuse de toute facon les autres : cet ecran ne fait que ne pas
// proposer ce qui serait refuse. Depuis C7 la colonne `acceptee` est CALCULEE
// par le serveur a partir de ce maximum -- on la lit donc toujours de la meme
// facon, mais elle n'est plus un reglage separe.
async function commercePjEcranMatieresPubliques(ctx) {
  commercePjChargement(tCommercePJ('commercepj.public.matieres'));
  if (!ctx || !ctx.fonds) ctx = await commercePjContexte();
  const cur = commercePjDevise();
  const matieres = (await sbFondsMatieresAccessibles(ctx.fondsId))
    .filter(function (m) { return m.acceptee === true; });

  let html = '<div style="padding:1rem">';
  html += '<div style="font-family:Bebas Neue,sans-serif;letter-spacing:.1em;color:#a09070;font-size:.85rem;margin-bottom:.5rem">' +
    commercePjEchapper(tCommercePJ('commercepj.appro.recherche')) + '</div>';
  if (!matieres.length) {
    html += '<p style="color:#8a8060;font-size:.85rem;font-style:italic">' +
      commercePjEchapper(tCommercePJ('commercepj.appro.aucune')) + '</p>';
  }
  matieres.forEach(function (m) {
    const stock = Math.max(0, Number(m.stock) || 0), maxi = Math.max(0, Number(m.maximum) || 0);
    const jai = commercePjQuantiteInventaire(m.matiere);
    const reste = Math.max(0, Number(m.place_restante) || 0);
    html += '<div style="border:1px solid #2a2620;padding:.6rem .8rem;margin-bottom:.5rem">';
    html += '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:.6rem">' +
      '<b style="color:#e0d8c0;font-size:.92rem">' + commercePjEchapper(commercePjLibelleMatiere(m.matiere)) + '</b>' +
      '<span style="color:#E8C97A;white-space:nowrap">' + commercePjMontant(m.prix_achat) + ' ' + cur +
      ' / ' + commercePjEchapper(tCommercePJ('commercepj.ref.unite')) + '</span></div>';
    // Le maximum d'une MATIERE est un chiffre nu depuis C7 : il n'est jamais
    // « illimite » (0 voudrait dire que le commerce la refuse, et elle ne serait
    // alors pas dans cette liste). commercePjMaximumLisible ne sert plus qu'aux
    // ARTICLES, ou 0 garde son sens de « non defini ».
    html += commercePjLigne(tCommercePJ('commercepj.travail.stockCommerce'),
      stock + ' / ' + maxi);
    html += commercePjLigne(tCommercePJ('commercepj.appro.besoin'), reste);
    html += commercePjLigne(tCommercePJ('commercepj.appro.vous'),
      '<span style="color:' + (jai > 0 ? '#6fa07a' : '#8a8060') + '">' + jai + '</span>');
    html += '<div style="margin-top:.45rem">' +
      commercePjBouton("commercePjEcranApporter('" + commercePjEchapper(m.matiere) + "')",
        tCommercePJ('commercepj.appro.titre'), true, jai <= 0 || reste <= 0) + '</div>';
    html += '</div>';
  });

  html += '<div style="margin-top:.9rem">' +
    commercePjBouton('commercePjEcranPublic()', tCommercePJ('commercepj.public.retour')) + '</div>';
  html += '</div>';
  commercePjModale(tCommercePJ('commercepj.public.matieres'), html);
}

// ---------------------------------------------------------------------------
// APPORT DE MATIERE — VENDRE OU DONNER
// ---------------------------------------------------------------------------
// Le navigateur propose, le serveur dispose : il borne la quantite par ce que
// le joueur possede vraiment, la place restante et la caisse du commerce. On
// affiche donc des reperes, jamais une regle.
async function commercePjEcranApporter(matiere) {
  commercePjChargement(tCommercePJ('commercepj.appro.titre'));
  const ctx = await commercePjContexte();
  const matieres = await sbFondsMatieresAccessibles(ctx.fondsId);
  const m = matieres.filter(function (x) { return x.matiere === matiere; })[0];
  if (!m) { showToast('—', commercePjRefus({ raison: 'matiere_hors_activites' }), false); return; }
  // Le serveur refuse de toute facon une matiere non acceptee : on ne propose
  // simplement pas un ecran dont l'issue serait un refus.
  if (m.acceptee !== true) {
    showToast('—', commercePjRefus({ raison: 'matiere_non_acceptee' }), false); return; }
  const cur = commercePjDevise();
  const jai = commercePjQuantiteInventaire(matiere);
  const cle = nouvelleCleApport();

  let html = '<div style="padding:1.1rem">';
  html += '<div style="font-family:Playfair Display,serif;color:#E8C97A;margin-bottom:.6rem">' +
    commercePjEchapper(commercePjLibelleMatiere(matiere)) + '</div>';
  html += commercePjLigne(tCommercePJ('commercepj.appro.vous'), jai);
  html += commercePjLigne(tCommercePJ('commercepj.appro.besoin'), m.place_restante);
  html += commercePjLigne(tCommercePJ('commercepj.matiere.prix'),
    commercePjMontant(m.prix_achat) + ' ' + cur + ' / ' + tCommercePJ('commercepj.ref.unite'));

  html += '<div style="margin-top:.8rem;font-size:.82rem;color:#a09070">' +
    commercePjEchapper(tCommercePJ('commercepj.appro.quantite')) + '</div>';
  html += '<input id="cpj-appro-qte" type="number" min="1" step="1" value="' +
    Math.max(1, Math.min(jai, Number(m.place_restante) || 1)) +
    '" style="width:100%;box-sizing:border-box;background:#0d0b05;border:1px solid #2a2620;color:#e0d8c0;padding:.45rem .6rem">';

  html += '<div style="display:flex;flex-wrap:wrap;gap:.4rem;margin-top:1rem">';
  html += commercePjBouton("commercePjApporter('" + commercePjEchapper(matiere) + "','" + cle + "','vente')",
    tCommercePJ('commercepj.appro.vendre'), true, jai <= 0);
  html += commercePjBouton("commercePjApporter('" + commercePjEchapper(matiere) + "','" + cle + "-d','don')",
    tCommercePJ('commercepj.appro.donner'), false, jai <= 0);
  html += commercePjBouton('commercePjEcranMatieresPubliques()', tCommercePJ('commercepj.public.retour'));
  html += '</div></div>';
  commercePjModale(tCommercePJ('commercepj.appro.titre'), html);
}

// Quantite reellement detenue, lue dans l'inventaire local pour l'affichage
// seul : le serveur relit l'inventaire reel avant d'accepter quoi que ce soit.
function commercePjQuantiteInventaire(cle) {
  const inv = (typeof state !== 'undefined' && state.inventory) || [];
  let total = 0;
  for (let i = 0; i < inv.length; i++) {
    const o = inv[i] || {};
    if (o.stackKey === cle) total += Math.max(0, Number(o.qty) || 0);
  }
  return total;
}

async function commercePjApporter(matiere, requete, mode) {
  const ctx = await commercePjContexte();
  const qte = Math.max(1, Math.floor(Number((document.getElementById('cpj-appro-qte') || {}).value) || 1));
  const r = await sbFondsMatiereApporter(requete, state.char.name, ctx.fondsId, matiere, qte, mode);
  if (!r || !r.ok) { showToast('—', commercePjRefus(r), false); return; }
  if (r.inventory) { state.inventory = r.inventory; if (typeof renderInventory === 'function') renderInventory(); }
  if (typeof updateUI === 'function') updateUI();
  const titre = (mode === 'don') ? tCommercePJ('commercepj.appro.donne') : tCommercePJ('commercepj.appro.vendu');
  let sous = commercePjLibelleMatiere(matiere) + ' × ' + r.quantite;
  if (Number(r.montant) > 0) sous += ' — ' + commercePjMontant(r.montant) + ' ' + commercePjDevise();
  if (Number(r.quantite) < Number(r.demandee)) {
    sous += ' · ' + tCommercePJ('commercepj.appro.partiel', { faites: r.quantite, voulues: r.demandee });
  }
  showToast(titre, sous, true);
  if (typeof addJournalEntry === 'function') addJournalEntry(titre + ' : ' + sous);
  commercePjEcranMatieresPubliques();
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
