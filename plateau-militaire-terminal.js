// =====================
// PLATEAU-MILITAIRE-TERMINAL.JS — TERMINAL DE SECTION DU LIEUTENANT (lot T)
// 29 septembre 2026
// =====================
// CE FICHIER N'EST PAS UN MOTEUR. Il affiche ce que militaire_terminal_section()
// rend, recueille une intention, appelle une des quatre portes mutantes, et
// reaffiche. Il ne calcule aucun PA, aucune capacite, aucun droit : tout cela est
// recalcule et oppose par le serveur, qui reste seul juge.
//
// IL NE LIT PAS LE BLOB DES COMPAGNIES. C'est le point le plus important de ce
// lot cote client : l'ancien ecran appelait sbGetCompagnies, donc un SELECT REST
// sur compagnies_militaires que la policy ouvre a TOUT joueur du pays. Ici, une
// seule porte, qui ne rend que la section de l'appelant.
//
// AUCUNE LISTE D'OBJETS N'EST ECRITE ICI. L'ancien ecran d'equipement filtrait
// l'inventaire du Lieutenant sur `o.produitMilitaire && o.id` -- un filtre
// PUREMENT CLIENT, que le serveur ne rejouait pas. C'est lui qui empechait Vince
// de distribuer autre chose que des armes et des equipements militaires. Le
// serveur accepte n'importe quel objet ; l'ecran propose donc n'importe quel
// objet, y compris ceux qui n'existent pas encore.

// ---------------------------------------------------------------------------
// LIBELLES
// ---------------------------------------------------------------------------
const I18N_MIL_TERMINAL_FR = {
  'mil.titre':            "Gestion des effectifs",
  'mil.plaque':           "SYSTÈME DE GESTION DES EFFECTIFS",
  'mil.armee':            "ARMÉE DE {pays}",
  'mil.eteindre':         "Fermer",
  'mil.col.soldat':       "Soldat",
  'mil.col.position':     "Position",
  'mil.col.pa':           "PA",
  'mil.col.armement':     "Armement",
  'mil.col.inventaire':   "Inventaire",
  'mil.col.ordres':       "Ordres",
  'mil.avecMoi':          "AVEC MOI",
  'mil.sansArme':         "Aucune",
  'mil.rienPorte':        "Rien",
  'mil.manger':           "Manger",
  'mil.dormir':           "Dormir",
  'mil.tente':            "Tente",
  'mil.gerer':            "Gérer",
  'mil.rejoindre':        "Rejoindre",
  'mil.fermerGestion':    "Fermer",
  'mil.ordonnerManger':   "Ordonner de manger",
  'mil.ordonnerDormir':   "Ordonner de dormir",
  'mil.toutManger':       "Tout sélectionner",
  'mil.rienSelectionner': "Tout désélectionner",
  'mil.effectif':         "Effectif",
  'mil.tentes':           "Tentes",
  'mil.placesTente':      "Places sous tente",
  'mil.radio':            "Radio",
  'mil.radioOui':         "en votre possession",
  'mil.radioNon':         "aucune",
  'mil.selection':        "{n} sélectionné(s)",
  'mil.aucuneSelection':  "Cochez d'abord des soldats.",
  'mil.monPaquetage':     "Votre paquetage",
  'mil.sonPaquetage':     "Son paquetage",
  'mil.donner':           "Donner",
  'mil.reprendre':        "Reprendre",
  'mil.quantite':         "Qté",
  'mil.rienADonner':      "Vous ne portez aucun objet.",
  'mil.rienAReprendre':   "Ce soldat ne porte rien.",
  'mil.pasLa':            "Transferts impossibles : ce soldat n'est pas avec vous.",
  'mil.aDormi':           "a dormi",
  'mil.rationsJour':      "{n}/{max} ration(s) aujourd'hui",
  'mil.chargement':       "Interrogation du registre…",

  // Motifs rendus par le serveur. Un refus doit se lire, jamais se deviner.
  'mil.refus.pas_lieutenant_de_section': "Ce terminal est réservé au Lieutenant d'une section.",
  'mil.refus.acteur_non_authentifie':    "Votre session a expiré. Reconnectez-vous.",
  'mil.refus.soldat_introuvable':        "Ce soldat n'est pas dans votre section.",
  'mil.refus.pas_co_presents':           "Il faut être physiquement avec ce soldat.",
  'mil.refus.quantite_invalide':         "Cette quantité n'est pas valide.",
  'mil.refus.quantite_insuffisante':     "Vous n'en portez pas autant.",
  'mil.refus.quantite_insuffisante_soldat': "Ce soldat n'en porte pas autant.",
  'mil.refus.inventaire_plein':          "Votre paquetage est plein.",
  'mil.refus.aucune_selection':          "Aucun soldat sélectionné.",
  'mil.refus.tente_hors_selection':      "Une place sous tente suppose de dormir.",
  'mil.refus.capacite_tente_depassée':   "Pas assez de places sous tente.",
  'mil.refus.capacite_tente_depassee':   "Pas assez de places sous tente : {demande} demandées pour {places_libres} disponibles.",
  'mil.refus.position_inconnue':         "Votre position est inconnue.",
  'mil.refus.requete_invalide':          "Demande mal formée. Rouvrez le terminal.",
  'mil.refus.sens_invalide':             "Ce sens de transfert n'existe pas.",
  'mil.refus.parametres_invalides':      "Demande incomplète. Rouvrez le terminal.",
  'mil.refus.session_perdue':            "Votre session a expiré. Reconnectez-vous puis réessayez.",
  'mil.refus.transport_indisponible':    "Le service n'a pas répondu. Rien n'a été modifié.",
  'mil.refus.reseau_indisponible':       "Connexion interrompue. Rien n'a été modifié.",
  'mil.refus.inconnu':                   "Refusé par le serveur ({motif}).",

  // Motifs par soldat, dans le compte rendu d'un ordre collectif.
  'mil.detail.hors_liaison':                 "hors liaison radio",
  'mil.detail.sans_ration':                  "sans ration : a mangé sans bonus",
  'mil.detail.pa_au_maximum':                "déjà au maximum de PA",
  'mil.detail.maximum_quotidien':            "a déjà mangé deux fois aujourd'hui",
  'mil.detail.epuise':                       "épuisé (0 PA)",
  'mil.detail.deja_repose':                  "a déjà dormi aujourd'hui",
  'mil.detail.deja_avec_vous':               "est déjà avec vous",
  'mil.detail.autre_ville_transport_requis': "dans une autre ville : il faut un transport"
};

function tMil(cle, remp) {
  let t = I18N_MIL_TERMINAL_FR[cle] || cle;
  if (remp) Object.keys(remp).forEach(function (k) {
    t = t.split('{' + k + '}').join(String(remp[k]));
  });
  return t;
}

function milEch(s) {
  if (typeof escapeHtmlText === 'function') return escapeHtmlText(String(s == null ? '' : s));
  return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  });
}

// Traduit un refus serveur. Le code interne reste en console pour le diagnostic.
function milRefus(v) {
  if (!v) return tMil('mil.refus.inconnu', { motif: 'aucune réponse' });
  const r = v.raison || (v.detail && v.detail.raison);
  const cle = 'mil.refus.' + r;
  const t = tMil(cle, v);
  if (t !== cle) return t;
  if (r) { console.error('[terminal militaire] motif non traduit : ' + r, v);
           return tMil('mil.refus.inconnu', { motif: String(r) }); }
  return tMil('mil.refus.inconnu', { motif: '—' });
}

function milDetail(raison) {
  const t = tMil('mil.detail.' + raison);
  return (t === 'mil.detail.' + raison) ? raison : t;
}

// ---------------------------------------------------------------------------
// ETAT D'ECRAN — DES SELECTIONS, PAS UNE AUTORITE
// ---------------------------------------------------------------------------
// Ces trois ensembles ne sont QUE des cases cochees. Ils ne sont jamais une
// regle : le serveur revalide chaque matricule, la liaison, la capacite et les
// compteurs du jour. Ils survivent a un reaffichage pour ne pas faire perdre au
// joueur une selection de 24 lignes a cause d'un transfert.
let RP_MIL_ETAT = null;
let RP_MIL_MANGER = new Set();
let RP_MIL_DORMIR = new Set();
let RP_MIL_TENTE  = new Set();
let RP_MIL_GERE   = null;   // matricule dont le panneau de gestion est ouvert

// ---------------------------------------------------------------------------
// LA COQUE
// ---------------------------------------------------------------------------
// Meme principe que le terminal de commerce : la FENETRE est la machine, dessinee
// en CSS. Identite distincte -- coque gris militaire, ecran a phosphore VERT --
// pour qu'on ne confonde pas une boutique avec un poste de commandement.
//
// LE DEFAUT A NE PAS REPRODUIRE : un enfant de flex qui deborde ne se reduit pas
// sous la taille de son contenu sans `min-height:0`. C'est ce qui a rendu le
// terminal de commerce non defilable. `.mil-ecran` le porte (voir style.css), et
// c'est lui qui defile -- jamais la coque.
function milMachine(htmlEcran, pays) {
  const t = document.getElementById('postes-modal-title');
  const b = document.getElementById('postes-body');
  if (!t || !b) return;
  t.textContent = tMil('mil.titre');
  b.innerHTML =
    '<div class="mil-fronton">' +
      '<span class="mil-led" aria-hidden="true"></span>' +
      '<span class="mil-led mil-led-veille" aria-hidden="true"></span>' +
      '<span class="mil-plaque">' + milEch(tMil('mil.plaque')) + '</span>' +
      '<span class="mil-grilles" aria-hidden="true"></span>' +
      '<span class="mil-armee">' +
        milEch(tMil('mil.armee', { pays: milNomPays(pays) })) + '</span>' +
      '<button class="mil-eteindre" onclick="milFermer()" title="' +
        milEch(tMil('mil.eteindre')) + '"><i class="ti ti-power"></i></button>' +
    '</div>' +
    '<div class="mil-ecran" id="mil-ecran">' + htmlEcran + '</div>' +
    '<div class="mil-socle" aria-hidden="true"></div>';
  const boite = document.querySelector('#modal-postes .modal-box');
  if (boite) boite.classList.add('mil-machine');
  document.getElementById('modal-postes').classList.add('open');
}

// Le nom du pays vient du referentiel, jamais d'une chaine ecrite ici : la plaque
// dira « ARMÉE DE SOVARKA » dans un autre empire sans qu'on touche ce fichier.
function milNomPays(pays) {
  const p = pays || (typeof state !== 'undefined' && state.country);
  const n = (typeof COUNTRIES !== 'undefined' && COUNTRIES[p] && (COUNTRIES[p].name || COUNTRIES[p].label));
  return String(n || p || '—').toUpperCase();
}

function milFermer() {
  const boite = document.querySelector('#modal-postes .modal-box');
  if (boite) boite.classList.remove('mil-machine');
  const m = document.getElementById('modal-postes');
  if (m) m.classList.remove('open');
}

function milTouche(onclick, libelle, primaire, desactive, titre) {
  return '<button class="mil-touche' + (primaire ? ' mil-primaire' : '') + '" ' +
    (titre ? 'title="' + milEch(titre) + '" ' : '') +
    (desactive ? 'disabled' : 'onclick="' + onclick + '"') + '>' +
    milEch(libelle) + '</button>';
}

// Une pastille icone + libelle. JAMAIS d'icone seule : un pictogramme sans mot
// est une devinette, et cet ecran en porte trop pour se le permettre.
function milPastille(o) {
  return '<span class="mil-obj" title="' + milEch(o.name || '') + '">' +
    '<i class="ti ' + milEch(o.icon || 'ti-package') + '" aria-hidden="true"></i>' +
    milEch(o.name || '?') +
    (Number(o.qte) > 1 ? '<b>×' + Number(o.qte) + '</b>' : '') + '</span>';
}

function milMessage(texte, ok) {
  const e = document.getElementById('mil-msg');
  if (!e) return;
  e.textContent = texte || '';
  e.className = 'mil-msg' + (texte ? (ok ? ' mil-msg-ok' : ' mil-msg-ko') : '');
}

// ---------------------------------------------------------------------------
// POINT D'ENTREE
// ---------------------------------------------------------------------------
async function ouvrirTerminalSection() {
  milMachine('<div class="mil-vide">' + milEch(tMil('mil.chargement')) + '</div>');
  const r = await sbMilitaireTerminalSection();
  if (!r || r.ok !== true) {
    milMachine('<div class="mil-vide mil-msg-ko">' + milEch(milRefus(r)) + '</div>');
    return;
  }
  RP_MIL_ETAT = r;
  milRendre();
}

// Recharge l'etat serveur puis redessine, EN CONSERVANT les selections et le
// panneau ouvert : une action ne doit pas coûter au joueur son travail de
// selection sur 24 lignes.
async function milRafraichir(message, ok) {
  const r = await sbMilitaireTerminalSection();
  if (r && r.ok === true) RP_MIL_ETAT = r;
  milRendre();
  if (message) milMessage(message, ok !== false);
}

function milRendre() {
  const e = RP_MIL_ETAT;
  if (!e) return;
  const sols = e.soldats || [];
  // Les selections ne survivent que pour des matricules encore presents.
  const vivants = new Set(sols.map(function (s) { return s.matricule; }));
  [RP_MIL_MANGER, RP_MIL_DORMIR, RP_MIL_TENTE].forEach(function (set) {
    Array.from(set).forEach(function (m) { if (!vivants.has(m)) set.delete(m); });
  });

  let h = '';

  // --- BANDEAU D'ETAT : ce que le Lieutenant doit savoir avant d'agir ---
  h += '<div class="mil-bandeau">';
  h += '<span class="mil-chiffre"><small>' + milEch(tMil('mil.effectif')) + '</small>' +
       (e.effectif || 0) + '</span>';
  h += '<span class="mil-chiffre"><small>' + milEch(tMil('mil.tentes')) + '</small>' +
       (e.tentes || 0) + '</span>';
  h += '<span class="mil-chiffre"><small>' + milEch(tMil('mil.placesTente')) + '</small>' +
       (e.places_tente_libres || 0) + '</span>';
  h += '<span class="mil-chiffre"><small>' + milEch(tMil('mil.radio')) + '</small>' +
       '<em class="' + (e.radio_moi ? 'mil-oui' : 'mil-non') + '">' +
       milEch(e.radio_moi ? tMil('mil.radioOui') : tMil('mil.radioNon')) + '</em></span>';
  h += '</div>';
  h += '<div class="mil-msg" id="mil-msg"></div>';

  // --- BARRE DES ORDRES COLLECTIFS, en haut : on la voit avant de descendre ---
  h += milBarreOrdres();

  if (!sols.length) {
    h += '<div class="mil-vide">Aucun soldat dans votre section.</div>';
    milMachine(h, e.pays);
    return;
  }

  // --- EN-TETES ---
  h += '<div class="mil-grille mil-entetes">' +
       '<span>' + milEch(tMil('mil.col.soldat')) + '</span>' +
       '<span>' + milEch(tMil('mil.col.position')) + '</span>' +
       '<span>' + milEch(tMil('mil.col.pa')) + '</span>' +
       '<span>' + milEch(tMil('mil.col.armement')) + '</span>' +
       '<span>' + milEch(tMil('mil.col.inventaire')) + '</span>' +
       '<span>' + milEch(tMil('mil.col.ordres')) + '</span></div>';

  sols.forEach(function (s) { h += milLigneSoldat(s, e); });

  h += milBarreOrdres();
  milMachine(h, e.pays);
}

function milBarreOrdres() {
  const nM = RP_MIL_MANGER.size, nD = RP_MIL_DORMIR.size, nT = RP_MIL_TENTE.size;
  let h = '<div class="mil-barre">';
  h += milTouche('milOrdonnerManger()',
    tMil('mil.ordonnerManger') + (nM ? ' (' + nM + ')' : ''), true, nM === 0);
  h += milTouche('milOrdonnerDormir()',
    tMil('mil.ordonnerDormir') + (nD ? ' (' + nD + (nT ? ', ' + nT + ' ⛺' : '') + ')' : ''),
    true, nD === 0);
  h += milTouche('milToutCocher(true)', tMil('mil.toutManger'));
  h += milTouche('milToutCocher(false)', tMil('mil.rienSelectionner'));
  h += '</div>';
  return h;
}

function milLigneSoldat(s, e) {
  const m = s.matricule;
  const avecMoi = s.avec_moi === true;
  const joignable = avecMoi || (e.radio_moi === true);
  const pos = avecMoi ? tMil('mil.avecMoi') : milNomVille(s.ville);
  const arme = (s.arme === 'corps_a_corps') ? tMil('mil.sansArme') : s.arme;
  const poss = s.possessions || [];

  let h = '<div class="mil-grille' + (avecMoi ? '' : ' mil-loin') + '">';

  // SOLDAT
  h += '<span class="mil-mat">' + milEch(m) +
       (s.a_dormi ? '<em class="mil-note">' + milEch(tMil('mil.aDormi')) + '</em>' : '') +
       '</span>';

  // POSITION — « AVEC MOI » ou la VILLE, jamais la piece d'autrui.
  h += '<span class="mil-pos' + (avecMoi ? ' mil-ici' : '') + '" data-l="' +
       milEch(tMil('mil.col.position')) + '">' + milEch(pos) + '</span>';

  // PA
  h += '<span class="mil-pa' + (Number(s.pa) <= 0 ? ' mil-zero' : '') + '" data-l="' +
       milEch(tMil('mil.col.pa')) + '">' + Number(s.pa) + '/' + Number(s.pa_max) + '</span>';

  // ARMEMENT — deduit de ce qu'il porte, plus une categorie a lui attribuer.
  h += '<span class="mil-arme' + (s.arme === 'corps_a_corps' ? ' mil-zero' : '') +
       '" data-l="' + milEch(tMil('mil.col.armement')) + '">' +
       (s.arme === 'corps_a_corps' ? '' : '<i class="ti ti-crosshair" aria-hidden="true"></i>') +
       milEch(arme) + '</span>';

  // INVENTAIRE — TOUT, tout de suite. C'est le critere joueur central.
  h += '<span class="mil-inv" data-l="' + milEch(tMil('mil.col.inventaire')) + '">';
  if (!poss.length) h += '<em class="mil-note">' + milEch(tMil('mil.rienPorte')) + '</em>';
  else poss.forEach(function (o) { h += milPastille(o); });
  h += '</span>';

  // ORDRES — deux cases liees, et deux touches.
  h += '<span class="mil-ordres">';
  h += milCase('manger', m, RP_MIL_MANGER.has(m), !joignable, tMil('mil.manger'));
  h += milCase('dormir', m, RP_MIL_DORMIR.has(m), !joignable, tMil('mil.dormir'));
  h += milCase('tente',  m, RP_MIL_TENTE.has(m),  !joignable, tMil('mil.tente'));
  h += milTouche("milGerer('" + m + "')",
        RP_MIL_GERE === m ? tMil('mil.fermerGestion') : tMil('mil.gerer'),
        RP_MIL_GERE === m, !avecMoi,
        avecMoi ? null : tMil('mil.pasLa'));
  // REJOINDRE n'apparait que quand il a un sens : un soldat deja la n'a rien a rejoindre.
  if (!avecMoi) {
    h += milTouche("milRejoindre('" + m + "')", tMil('mil.rejoindre'), false, !joignable,
      joignable ? null : milDetail('hors_liaison'));
  }
  h += '</span>';

  // PANNEAU DE GESTION, DANS LA LIGNE. Aucune sous-fenetre : on ne quitte pas le
  // terminal pour donner trois rations.
  if (RP_MIL_GERE === m) h += milPanneauGestion(s, e);

  h += '</div>';
  return h;
}

function milCase(quoi, matricule, coche, desactive, libelle) {
  return '<label class="mil-case' + (desactive ? ' mil-case-off' : '') + '">' +
    '<input type="checkbox"' + (coche ? ' checked' : '') + (desactive ? ' disabled' : '') +
    ' onchange="milCocher(\'' + quoi + '\',\'' + matricule + '\',this.checked)">' +
    milEch(libelle) + '</label>';
}

// TENTE IMPLIQUE DORMIR, ET DECOCHER DORMIR LIBERE LA TENTE. La regle est portee
// ici parce qu'elle est d'interface ; le serveur la revalide de son cote
// (tente_hors_selection).
function milCocher(quoi, matricule, coche) {
  if (quoi === 'manger') {
    if (coche) RP_MIL_MANGER.add(matricule); else RP_MIL_MANGER.delete(matricule);
  } else if (quoi === 'dormir') {
    if (coche) RP_MIL_DORMIR.add(matricule);
    else { RP_MIL_DORMIR.delete(matricule); RP_MIL_TENTE.delete(matricule); }
  } else {
    if (coche) { RP_MIL_TENTE.add(matricule); RP_MIL_DORMIR.add(matricule); }
    else RP_MIL_TENTE.delete(matricule);
  }
  milRendre();
}

function milToutCocher(oui) {
  const sols = (RP_MIL_ETAT && RP_MIL_ETAT.soldats) || [];
  RP_MIL_MANGER.clear(); RP_MIL_DORMIR.clear(); RP_MIL_TENTE.clear();
  if (oui) sols.forEach(function (s) {
    if (s.avec_moi === true || RP_MIL_ETAT.radio_moi === true) {
      RP_MIL_MANGER.add(s.matricule); RP_MIL_DORMIR.add(s.matricule);
    }
  });
  milRendre();
}

// ---------------------------------------------------------------------------
// PANNEAU DE GESTION — N'IMPORTE QUEL OBJET, DANS LES DEUX SENS
// ---------------------------------------------------------------------------
function milPanneauGestion(s, e) {
  const m = s.matricule;
  const mien = e.mon_inventaire || [];
  const sien = s.possessions || [];
  let h = '<div class="mil-panneau">';

  h += '<div class="mil-colonne"><div class="mil-sstitre">' +
       milEch(tMil('mil.monPaquetage')) + '</div>';
  if (!mien.length) h += '<em class="mil-note">' + milEch(tMil('mil.rienADonner')) + '</em>';
  mien.forEach(function (o, i) {
    h += '<div class="mil-transfert">' + milPastille(o) +
      '<input id="mil-q-d-' + m + '-' + i + '" class="mil-qte" type="number" min="1" step="1" ' +
        'max="' + Number(o.qte) + '" value="1" aria-label="' + milEch(tMil('mil.quantite')) + '">' +
      milTouche("milTransferer('" + m + "','" + encodeURIComponent(o.signature) +
        "','mil-q-d-" + m + "-" + i + "','donner')", tMil('mil.donner'), true) +
      '</div>';
  });
  h += '</div>';

  h += '<div class="mil-colonne"><div class="mil-sstitre">' +
       milEch(tMil('mil.sonPaquetage')) + '</div>';
  if (!sien.length) h += '<em class="mil-note">' + milEch(tMil('mil.rienAReprendre')) + '</em>';
  sien.forEach(function (o, i) {
    h += '<div class="mil-transfert">' + milPastille(o) +
      '<input id="mil-q-r-' + m + '-' + i + '" class="mil-qte" type="number" min="1" step="1" ' +
        'max="' + Number(o.qte) + '" value="1" aria-label="' + milEch(tMil('mil.quantite')) + '">' +
      milTouche("milTransferer('" + m + "','" + encodeURIComponent(o.signature) +
        "','mil-q-r-" + m + "-" + i + "','reprendre')", tMil('mil.reprendre')) +
      '</div>';
  });
  h += '</div>';

  h += '</div>';
  return h;
}

function milGerer(matricule) {
  RP_MIL_GERE = (RP_MIL_GERE === matricule) ? null : matricule;
  milRendre();
}

async function milTransferer(matricule, signatureEncodee, idChamp, sens) {
  const signature = decodeURIComponent(signatureEncodee);
  const champ = document.getElementById(idChamp);
  const qte = Math.max(1, Math.floor(Number(champ && champ.value) || 1));
  const r = await sbMilitaireTerminalTransferer(nouvelleCleMilitaire(), matricule,
                                               signature, qte, sens);
  if (!r || r.ok !== true) { milMessage(milRefus(r), false); return; }
  // L'ARMEMENT PEUT AVOIR CHANGE : le serveur le renvoie, on l'annonce.
  let mot = (sens === 'donner' ? '→ ' : '← ') + r.quantite + ' × ' + (r.objet || '?') +
            ' · ' + matricule;
  if (r.arme) mot += ' · armement : ' + (r.arme === 'corps_a_corps' ? tMil('mil.sansArme') : r.arme);
  if (typeof addJournalEntry === 'function') addJournalEntry('Paquetage : ' + mot);
  if (typeof updateUI === 'function') updateUI();
  await milRafraichir('✓ ' + mot, true);
}

// ---------------------------------------------------------------------------
// ORDRES COLLECTIFS
// ---------------------------------------------------------------------------
// Le compte rendu nomme CHAQUE cas particulier : un soldat sans ration a bien
// mange, un soldat hors liaison n'a rien recu. Sans cela le joueur ne saurait pas
// pourquoi 18 selectionnes donnent 12 servis.
function milCompteRendu(r) {
  const parts = [];
  if (typeof r.avec_ration === 'number') {
    parts.push(r.avec_ration + ' avec ration (+' + (r.gain_pa || 1) + ' PA)');
    if (r.sans_ration) parts.push(r.sans_ration + ' sans ration');
  }
  if (typeof r.reposes === 'number') {
    parts.push(r.reposes + ' reposé(s)');
    if (r.caserne) parts.push(r.caserne + ' à la caserne');
    if (r.tente)   parts.push(r.tente + ' sous tente');
    if (r.terrain) parts.push(r.terrain + ' au terrain');
  }
  if (typeof r.rejoints === 'number') parts.push(r.rejoints + ' rejoint(s)');

  const refus = {};
  (r.details || []).forEach(function (d) {
    if (!d || !d.raison) return;
    refus[d.raison] = (refus[d.raison] || 0) + 1;
  });
  Object.keys(refus).forEach(function (k) {
    parts.push(refus[k] + ' ' + milDetail(k));
  });
  return parts.join(' · ');
}

async function milOrdonnerManger() {
  if (!RP_MIL_MANGER.size) { milMessage(tMil('mil.aucuneSelection'), false); return; }
  const r = await sbMilitaireTerminalManger(nouvelleCleMilitaire(), Array.from(RP_MIL_MANGER));
  if (!r || r.ok !== true) { milMessage(milRefus(r), false); return; }
  RP_MIL_MANGER.clear();
  if (typeof addJournalEntry === 'function') addJournalEntry('Ordre : manger — ' + milCompteRendu(r));
  await milRafraichir('✓ ' + milCompteRendu(r), true);
}

async function milOrdonnerDormir() {
  if (!RP_MIL_DORMIR.size) { milMessage(tMil('mil.aucuneSelection'), false); return; }
  const r = await sbMilitaireTerminalDormir(nouvelleCleMilitaire(),
              Array.from(RP_MIL_DORMIR), Array.from(RP_MIL_TENTE));
  if (!r || r.ok !== true) { milMessage(milRefus(r), false); return; }
  RP_MIL_DORMIR.clear(); RP_MIL_TENTE.clear();
  if (typeof addJournalEntry === 'function') addJournalEntry('Ordre : dormir — ' + milCompteRendu(r));
  await milRafraichir('✓ ' + milCompteRendu(r), true);
}

async function milRejoindre(matricule) {
  const r = await sbMilitaireTerminalRejoindre(nouvelleCleMilitaire(), [matricule]);
  if (!r || r.ok !== true) { milMessage(milRefus(r), false); return; }
  const cr = milCompteRendu(r);
  if (typeof addJournalEntry === 'function') addJournalEntry('Ordre : rejoindre — ' + cr);
  await milRafraichir('✓ ' + cr, Number(r.rejoints) > 0);
}

// Nom lisible d'une ville. Le referentiel fait foi ; on n'ecrit aucun nom ici.
function milNomVille(cle) {
  if (!cle) return '—';
  if (typeof WORLD !== 'undefined' && typeof state !== 'undefined'
      && WORLD[state.country] && WORLD[state.country][cle] && WORLD[state.country][cle].name) {
    return WORLD[state.country][cle].name;
  }
  return String(cle).replace(/_/g, ' ');
}
