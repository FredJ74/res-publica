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
function arkadiFicheHtml(salle) {
  const texte = ARKADI_RECITS[salle] || ARKADI_RECITS.hall;
  return '<div class="guide-musee-fiche" data-arkadi-salle="' + echapper(salle) + '">'
    + '<img src="' + ARKADI_PORTRAIT + '" alt="" style="float:left;width:96px;height:96px;object-fit:cover;border-radius:50%;margin:0 .8rem .4rem 0">'
    + '<div data-arkadi-recit>' + texte.split('\n\n').map(p => '<p>' + echapper(p) + '</p>').join('') + '</div>'
    + '<div style="clear:both"></div>' + arkadiEnigmeHtml() + '</div>';
}
// Une seule fenêtre à la fois (R8) : la fenêtre commune #modal-postes est réutilisée.
function arkadiEcouterGuide() {
  const salle = global.state?.currentRoom;
  if (!arkadiSurPlace(salle)) return;
  const html = arkadiFicheHtml(salle);
  if (typeof global.sovModal === 'function') global.sovModal(ARKADI_TITRE, html);
  else if (typeof global.vehModal === 'function') global.vehModal(ARKADI_TITRE, html);
}

global.ARKADI_RECITS = ARKADI_RECITS;
global.ARKADI_NOM = ARKADI_NOM;
global.arkadiEcouterGuide = arkadiEcouterGuide;
global.arkadiEnigmeHtml = arkadiEnigmeHtml;
})(typeof window !== 'undefined' ? window : globalThis);
