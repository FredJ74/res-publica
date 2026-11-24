// Visite guidée du musée de Krasnov — Arkadi Pamiatnikov (Fred, 23/11/2026, point 29 ;
// GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md). Sur le modèle d'Ilia Krioukov à Novomirsk (plateau-guide-ilia.js) :
// même ordre de pièce « Écouter le guide » (ilia_ecouter_guide, gratuit), présentation fixe de chaque salle.
// Le directeur du musée est supprimé : c'est Arkadi qui reçoit la solution de l'énigme de Krasnov. Le jugement reste au
// serveur (krasnov_ecole_agir, action repondre_enigme, via soumettreEnigmeKrasnov de plateau-enigme-krasnov.js).
(function (global) {
'use strict';
const ARKADI_PIECES = Object.freeze(['hall', 'faune_sauvage', 'flore_sauvage', 'exploitation_bois', 'kolkhozes', 'ecoute_spatiale']);
const ARKADI_PORTRAIT = 'images/Sovarka/Krasnov/Krasnov_musee_accueil_guide.webp';
const ARKADI_NOM = 'Arkadi Pamiatnikov';
const ARKADI_TITRE = 'Arkadi Pamiatnikov — Guide du musée de Krasnov';
const ARKADI_RECITS = Object.freeze({
  hall: `Entrez, entrez, ne restez pas dans le courant d'air ! Je suis Arkadi Pamiatnikov, guide de ce musée depuis… oh, depuis que le poêle du hall fume de travers, c'est-à-dire depuis toujours.

Notre musée est petit, mais il dit tout de Krasnov : la grande faune de nos forêts, nos baies et nos fougères, le bois et ceux qui le coupent, les kolkhozes qui ont fait vivre la ville, et ces grandes oreilles tendues vers le ciel que nos voisins de Novomirsk nous envient sans l'avouer.

Cinq salles vous attendent. Dans chacune, appelez-moi : je vous raconterai ce que les vitrines ne savent pas dire. Et si une vieille feuille de papier vous tracasse… venez donc me voir. Les vieux guides ont parfois de vieilles réponses.`,
  faune_sauvage: `Levez les yeux, n'ayez pas peur : il est empaillé depuis 1931. C'est l'ours brun de Krasnov, le plus grand jamais abattu dans nos bois. Un garde forestier l'a rencontré au bord d'une clairière à miel ; on dit que l'ours a eu le temps de finir la ruche avant de finir au musée.

Autour de lui, le loup, qui hurle l'hiver derrière la scierie ; le lynx, que personne ne voit jamais mais que tout le monde a entendu ; l'aigle royal des falaises ; et ce petit diable de glouton, capable de vider un piège et d'emporter le piégeur avec, si on le laissait faire.

L'ours reste notre emblème. Les anciens savaient le tenir loin des essaims sauvages… mais ils gardaient leurs recettes pour eux. Des questions ? Parlez-moi, j'ai l'oreille encore bonne.`,
  flore_sauvage: `Ici, la forêt se mange, ou elle vous mange : tout dépend de ce que vous cueillez. Myrtilles, airelles, canneberges des tourbières, camarine noire… et, à côté, ces jolies baies rouges que je ne vous conseille pas, sauf pour un ennemi politique.

Regardez la droséra, là, dans la mare reconstituée : une plante qui mange les mouches. Le Parti l'a longtemps citée en exemple de discipline. Les fougères et les bouleaux viennent de la clairière du nord ; les enfants de l'école les ont replantés eux-mêmes.

Le guide des baies sauvages se vend à l'accueil. Lisez-le bien, jusqu'à la dernière page… et même ce qui n'est pas imprimé dedans.`,
  exploitation_bois: `Le bois a bâti Krasnov, ses isbas, son église, sa scierie et même, paraît-il, le premier bureau du Parti, qui a brûlé deux fois. Voici les haches, les scies passe-partout, les traîneaux et les crochets des bûcherons d'autrefois.

Les vieux ne coupaient jamais n'importe quand : bois d'hiver, à la lune descendante, pour qu'il ne travaille pas et que les vers n'y entrent pas. Le Plan, lui, coupait tous les jours ; les vers ont beaucoup apprécié le Plan.

Sur ce panneau, la journée d'un bûcheron : lever à cinq heures, thé brûlant, dix heures dans la neige, et une cuillère de graisse au pain noir pour tenir le froid. Voilà des hommes ! Des questions ? Je vous écoute.`,
  kolkhozes: `Voici la maquette du kolkhoze « Aube de Krasnov » : les étables, le silo, les champs de seigle et, au milieu, le tracteur, que l'on bénit encore à l'église. Ici, on mettait tout en commun : les terres, les outils, les récoltes… et les disputes, surtout les disputes.

Ces carnets de brigade notaient chaque journée de travail. Les meilleurs devenaient héros du Travail, avec une médaille et une photo dans le journal. Les moins bons recevaient aussi leur photo, mais dans un autre journal.

Le miel des ruches collectives partait à Novomirsk, les pommes à la gare, et le reste dans les caves de chacun : l'économie collective a toujours eu ses petits arrangements. Interrogez-moi si le cœur vous en dit.`,
  ecoute_spatiale: `Baissez la voix, je vous prie. Non, ce n'est pas interdit, mais c'est l'usage. Ces paraboles, ces antennes et cette Terre entourée d'ondes racontent la grande fierté de Krasnov : notre station d'écoute de l'espace, au-dessus de la forêt.

Elle a entendu, dit-on, des signaux que personne n'a su expliquer. Les savants parlaient de pulsars ; le colonel, lui, ne parlait de rien, et c'est bien ce qui inquiétait tout le monde. Une science impressionnante, et terriblement mystérieuse.

Les photographies s'arrêtent en 1986. Pourquoi ? Je n'en sais rien, et à mon âge, je préfère ne pas le savoir. Mais posez vos questions : je répondrai à celles que je peux.`
});
const ARKADI_ENIGME = Object.freeze({
  titre: 'Une solution pour la feuille volante ?',
  intro: 'Vous avez trouvé l’ingrédient effacé de la recette ? Dites-le à Arkadi : il vous dira si c’est le bon.',
  placeholder: 'L’ingrédient effacé…',
  bouton: 'Le dire à Arkadi',
  sansFeuille: 'Si vous achetez un jour le guide des baies sauvages, regardez bien entre ses pages : une feuille volante pourrait vous intriguer.',
  resolue: 'Vous avez résolu l’énigme de Krasnov. Arkadi vous salue d’un hochement de tête respectueux.'
});

function arkadiSurPlace(salle) {
  const s = global.state;
  return !!s && s.country === 'soviet' && s.currentCity === 'ville_b' && s.currentBuilding === 'musee-novomirsk'
    && ARKADI_PIECES.includes(salle);
}
function echapper(t) {
  return String(t == null ? '' : t).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function aLaFeuille() {
  return (global.state?.inventory || []).some(o => o && o.type === 'feuille_enigme_krasnov');
}
function enigmeResolue() {
  return (global.state?.enigmesResolues || []).some(e => e && e.enigme === 'krasnov');
}
// Section de l'énigme : le joueur donne l'ingrédient au guide ; le serveur juge.
function arkadiEnigmeHtml() {
  let corps;
  if (enigmeResolue()) corps = '<p class="cpj-note">' + echapper(ARKADI_ENIGME.resolue) + '</p>';
  else if (!aLaFeuille()) corps = '<p class="cpj-note">' + echapper(ARKADI_ENIGME.sansFeuille) + '</p>';
  else corps = '<p>' + echapper(ARKADI_ENIGME.intro) + '</p>'
    + '<input id="enigme-krasnov-reponse" type="text" maxlength="80" class="cpj-champ" style="width:100%" dir="auto" placeholder="'
    + echapper(ARKADI_ENIGME.placeholder) + '">'
    + '<button class="cpj-touche cpj-primaire" style="width:100%;margin-top:.6rem" onclick="soumettreEnigmeKrasnov()">'
    + echapper(ARKADI_ENIGME.bouton) + '</button>';
  return '<div class="guide-musee-questions" data-arkadi-enigme><h4>' + echapper(ARKADI_ENIGME.titre) + '</h4>' + corps + '</div>';
}
// QUESTIONS LIBRES À ARKADI (Fred, 24/11/2026, mission « Purge », point H.3) : comme Ouliana et Ilia à Novomirsk,
// 1 PA ouvre trois questions, par salle et par jour. Le serveur tient le compte (guide_musee_dialogue_lire / _ouvrir,
// salle « krasnov:<pièce> », migration 20261124142000) et /api/chat ne répond à Arkadi que dans son musée ; l'écran ne
// fait qu'afficher ce que le serveur renvoie. Textes en français (Codex les traduira).
const ARKADI_QUESTIONS = Object.freeze({
  titre: 'Des questions pour Arkadi ?',
  intro: 'Pour 1 PA, Arkadi répond à trois questions dans cette salle, aujourd’hui.',
  ouvrir: 'Poser des questions (1 PA)',
  placeholder: 'Votre question sur Krasnov…',
  demander: 'Demander ({n} restantes)',
  vous: 'Vous',
  attente: 'Arkadi ajuste ses lunettes…',
  fini: 'Je vous ai tout dit pour aujourd’hui dans cette salle. Bonne visite !',
  r_pas_sur_place: 'Vous devez être dans le musée de Krasnov.',
  r_dialogue_non_ouvert: 'Ouvrez d’abord les questions.',
  r_questions_epuisees: 'Vous avez posé vos trois questions dans cette salle aujourd’hui.',
  r_pa_insuffisants: 'Vous n’avez pas assez de PA.',
  r_autre: 'Le guide ne peut pas répondre pour le moment.'
});
const arkadiEtat = {}, arkadiEchanges = {};
let arkadiOccupe = false, arkadiRendu = null;
function arkadiMotif(raison) {
  return ARKADI_QUESTIONS['r_' + raison] || ARKADI_QUESTIONS.r_autre;
}
function arkadiQuestionsHtml(salle) {
  const e = arkadiEtat[salle];
  const messages = (arkadiEchanges[salle] || []).map(m => '<p class="' + (m.role === 'user' ? 'cpj-note' : '') + '"><strong>'
    + echapper(m.role === 'user' ? ARKADI_QUESTIONS.vous : 'Arkadi') + ' :</strong> ' + echapper(m.content) + '</p>').join('');
  let controles;
  if (!e || !e.ouvert) {
    controles = '<p class="cpj-note">' + echapper(ARKADI_QUESTIONS.intro) + '</p>'
      + '<button class="cpj-touche cpj-primaire" onclick="arkadiOuvrirQuestions()">' + echapper(ARKADI_QUESTIONS.ouvrir) + '</button>';
  } else if (e.restantes > 0) {
    controles = '<textarea id="arkadi-question" class="cpj-champ" rows="2" maxlength="500" style="width:100%" dir="auto" placeholder="'
      + echapper(ARKADI_QUESTIONS.placeholder) + '"></textarea>'
      + '<button class="cpj-touche cpj-primaire" onclick="arkadiPoser()">' + echapper(ARKADI_QUESTIONS.demander.replace('{n}', e.restantes)) + '</button>';
  } else {
    controles = '<p class="cpj-note">' + echapper(ARKADI_QUESTIONS.fini) + '</p>';
  }
  return '<div class="guide-musee-questions" data-arkadi-questions><h4>' + echapper(ARKADI_QUESTIONS.titre) + '</h4>' + messages + controles + '</div>';
}
function arkadiFicheHtml(salle) {
  const texte = ARKADI_RECITS[salle] || ARKADI_RECITS.hall;
  return '<div class="guide-musee-fiche" data-arkadi-salle="' + echapper(salle) + '">'
    + '<img src="' + ARKADI_PORTRAIT + '" alt="" style="float:left;width:96px;height:96px;object-fit:cover;border-radius:50%;margin:0 .8rem .4rem 0">'
    + '<div data-arkadi-recit>' + texte.split('\n\n').map(p => '<p>' + echapper(p) + '</p>').join('') + '</div>'
    + '<div style="clear:both"></div>' + arkadiQuestionsHtml(salle) + arkadiEnigmeHtml() + '</div>';
}
// Une seule fenêtre à la fois (R8) : la fenêtre commune #modal-postes est réutilisée.
async function arkadiEcouterGuide() {
  const salle = global.state?.currentRoom;
  if (!arkadiSurPlace(salle)) return;
  const rendre = () => {
    if (!arkadiSurPlace(salle) || global.state?.currentRoom !== salle) return;
    const html = arkadiFicheHtml(salle);
    if (typeof global.sovModal === 'function') global.sovModal(ARKADI_TITRE, html);
    else if (typeof global.vehModal === 'function') global.vehModal(ARKADI_TITRE, html);
  };
  arkadiRendu = rendre;
  rendre();
  if (typeof global.sbRpcVerdict === 'function') {
    const v = await global.sbRpcVerdict('guide_musee_dialogue_lire', {}).catch(() => null);
    if (arkadiSurPlace(salle) && v?.ok === true && v.salle === 'krasnov:' + salle) {
      arkadiEtat[salle] = { ouvert: v.ouvert === true, restantes: Number(v.restantes) || 0 };
      rendre();
    }
  }
}
async function arkadiOuvrirQuestions() {
  const salle = global.state?.currentRoom;
  if (arkadiOccupe || !arkadiSurPlace(salle) || typeof global.sbRpcVerdict !== 'function') return;
  arkadiOccupe = true;
  try {
    const v = await global.sbRpcVerdict('guide_musee_dialogue_ouvrir', {}).catch(() => null);
    if (v?.ok !== true || v.salle !== 'krasnov:' + salle) {
      if (typeof global.showToast === 'function') global.showToast(ARKADI_NOM, arkadiMotif(v?.raison), false);
      return;
    }
    if (v.pa != null && typeof global.appliquerPaiementServeur === 'function') global.appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (typeof global.updateUI === 'function') global.updateUI();
    arkadiEtat[salle] = { ouvert: true, restantes: Number(v.restantes) || 0 };
    if (arkadiRendu) arkadiRendu();
  } finally { arkadiOccupe = false; }
}
async function arkadiPoser() {
  const salle = global.state?.currentRoom, e = arkadiEtat[salle];
  const champ = global.document?.getElementById('arkadi-question');
  const question = String(champ?.value || '').trim().slice(0, 500);
  if (!arkadiSurPlace(salle) || !question || !e || !(e.restantes > 0) || arkadiOccupe) return;
  arkadiOccupe = true;
  const bouton = champ?.nextElementSibling;
  if (bouton) { bouton.disabled = true; bouton.textContent = ARKADI_QUESTIONS.attente; }
  try {
    if (typeof global.rpAuthAssurerSession === 'function') await global.rpAuthAssurerSession().catch(() => null);
    const jeton = typeof global.rpAuthJeton === 'function' ? global.rpAuthJeton() : null;
    const langue = typeof global.langueDuJeu === 'function' ? global.langueDuJeu() : 'fr';
    const historique = (arkadiEchanges[salle] || []).slice(-6);
    const resp = jeton ? await global.fetch('/api/chat', {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + jeton },
      body: JSON.stringify({ profil: 'arkadi_pamiatnikov', lang: langue, message: question, historique })
    }).catch(() => null) : null;
    const d = resp ? await resp.json().catch(() => null) : null;
    if (!resp?.ok || typeof d?.reponse !== 'string') {
      if (d?.raison === 'questions_epuisees' || d?.raison === 'dialogue_non_ouvert')
        arkadiEtat[salle] = { ouvert: d.raison === 'questions_epuisees', restantes: 0 };
      if (typeof global.showToast === 'function') global.showToast(ARKADI_NOM, arkadiMotif(d?.raison), false);
      if (arkadiRendu) arkadiRendu();
      return;
    }
    (arkadiEchanges[salle] = arkadiEchanges[salle] || []).push({ role: 'user', content: question }, { role: 'assistant', content: d.reponse });
    arkadiEtat[salle] = { ouvert: true, restantes: Math.max(0, Number(d.restantes) || 0) };
    if (arkadiRendu) arkadiRendu();
  } finally {
    arkadiOccupe = false;
    if (bouton && global.document?.body?.contains(bouton)) bouton.disabled = false;
  }
}

global.ARKADI_RECITS = ARKADI_RECITS;
global.ARKADI_NOM = ARKADI_NOM;
global.arkadiEcouterGuide = arkadiEcouterGuide;
global.arkadiOuvrirQuestions = arkadiOuvrirQuestions;
global.arkadiPoser = arkadiPoser;
global.ARKADI_QUESTIONS = ARKADI_QUESTIONS;
global.arkadiEnigmeHtml = arkadiEnigmeHtml;
})(typeof window !== 'undefined' ? window : globalThis);
