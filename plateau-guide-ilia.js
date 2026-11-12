// Visite guidée du Musée municipal de Novomirsk — Ilia Krioukov.
// La présentation est gratuite. Les questions suivent le même compteur serveur
// que la guide du musée national : 1 PA pour 3 questions par pièce et par jour.
// L'étape du trésor des Tsars reste exclusivement décidée par tresor_tsars_guide.
const ILIA_MUSEE_PIECES = Object.freeze(['hall', 'salle_origines', 'salle_personnalites_discretes', 'salle_bataille_fleuve', 'salle_grand_incendie']);
const ILIA_MUSEE_PORTRAIT = 'images/Sovarka/Novomirsk/Novo_ilia_medailine_portrait.webp';
const ILIA_MUSEE_RECITS = Object.freeze({
  hall: `Ah ! Bienvenue au musée municipal de Novomirsk ! Je suis Ilia Krioukov. On m'appelle le vétéran, mais rassurez-vous, je n'ai pas participé personnellement à toutes les batailles que je raconte !

Ici, on ne vous montre pas l'histoire entière de Sovarka : nous avons mieux, l'histoire de notre ville. Vous découvrirez comment les pêcheurs ont fait naître Novomirsk, quelques personnages trop discrets pour figurer au musée national, notre victoire de 1742 sur le fleuve et le grand incendie de 1887.

Prenez votre temps et entrez dans chaque salle. Je serai là pour vous raconter ce que les objets ont à nous dire. Et si quelque chose vous intrigue, posez-moi vos questions !`,
  salle_origines: `Approchez, approchez ! Ici commence l'histoire de Novomirsk. Le fleuve Sovarka, voyez-vous, a tout donné à la ville : des terres fertiles, du poisson à ne savoir qu'en faire, et une route d'eau pour commercer avec toutes les villes et tous les pays. Les Tsars en firent leur capitale, et quand le régime tomba pour laisser place à la démocratie, Novomirsk le resta, tout naturellement.

Et cette vitrine vide ? Ah… La légende dit que lorsque Sergueï IV, dit le Terrible, s'enfuit, il emporta le trésor des Tsars dans une barque qui prenait l'eau. La barque coula, le tsar se noya, et le trésor disparut au fond du fleuve. Depuis, les pêcheurs relèvent leurs filets en espérant remonter un coffre plutôt qu'une carpe…

Si le cœur vous en dit, demandez donc à la femme du pêcheur qui vend du poisson le long des quais si ses poissons valent de l'or…

Avez-vous des questions ?`,
  salle_personnalites_discretes: `Mes chers visiteurs, les grandes statues et les présidents ont déjà leurs salles au musée national. Ici, nous nous intéressons aux autres : ceux dont les inventions, les exploits ou les mésaventures ont laissé des traces dans notre ville.

Voici Sophia Nouiseteskaïa, qui fabriquait un voile si transparent que ses vêtements de nuit auraient eu un pouvoir redoutable sur les hommes. À côté, Viktor Polov : on raconte que cet ancien coursier du tsar Léonid III inventa le polo en se passant un sac de sucre de cavalier en cavalier. Il fallait avoir de bons réflexes !

Alexander Aspirine prétendait soigner les maux de tête avec son vin fermenté ; à forte dose, il provoquait surtout des vomissements. Ivan Betonov dessina le Palais du Gouvernement, si colossal que sa construction priva le pays de matériaux pendant cinq ans. Enfin, Anna Mouriskova, courtisane et espionne, fut exécutée sur ordre du camarade Belov. Pour jalousie ou pour ses secrets ? Les archives se taisent.

Regardez les objets sous chaque portrait, puis demandez-moi ce qui vous intrigue. Je vous écoute !`,
  salle_bataille_fleuve: `Ah ! La bataille du fleuve Sovarka ! Voilà une journée dont Novomirsk peut être fière ! C'était en 1742, et le prince Mikhaïl Dragounov arrivait avec vingt-sept bateaux et près de huit cents soldats. Il croyait pouvoir prendre notre port comme on cueille une pomme.

Mais il avait oublié nos pêcheurs ! Le capitaine Piotr Karassov connaissait chaque courant et chaque banc de sable. Ses hommes retirèrent les balises et plantèrent des pieux sous la surface. Les premiers bateaux ennemis s'échouèrent, les suivants leur rentrèrent dedans : quelle pagaille ! Les défenseurs de Novomirsk les accueillirent depuis les berges.

Karassov aurait dit après la victoire : « Ils avaient huit cents soldats. Nous avions le fleuve. » Voyez cette barque : la tradition affirme que c'est la sienne. Les historiens en doutent, mais ses descendants, eux, n'en doutent pas une seconde !

Si vous avez des questions sur cette magnifique victoire, je suis tout ouïe !`,
  salle_grand_incendie: `Ah… 1887. Trois jours et trois nuits pendant lesquels le vieux quartier marchand de Novomirsk a brûlé. Et tout cela aurait commencé dans la boulangerie de Grigori Pirogov : un apprenti avait oublié de surveiller le four !

Le vent poussa le feu de maison en maison, puis jusqu'aux entrepôts du port. Les habitants luttèrent avec des seaux, des pompes à bras et toute l'eau du fleuve qu'ils pouvaient transporter. Un tiers de la vieille ville partit en fumée. La catastrophe obligea ensuite Novomirsk à rebâtir son centre en pierre et en brique.

Vous voyez cette pompe à incendie ? Et ces photographies des ruines ? Mais le plus extraordinaire est ici, sous verre : une miche de pain entièrement carbonisée retrouvée dans les décombres de la boulangerie Pirogov. Le boulanger rouvrit plus tard, paraît-il, avec cette promesse sur sa porte : « Cette fois, nous surveillons la cuisson. »

Que voudriez-vous savoir de cette terrible histoire ? Je répondrai à vos questions !`
});
const iliaMuseeEtat = {};
const iliaMuseeEchanges = {};
let iliaMuseeOccupé = false;
let iliaMuseeRendu = null;

function iliaMuseeSurPlace(salle) {
  return state.country === 'soviet' && state.currentCity === 'capitale'
    && state.currentBuilding === 'musee-novomirsk' && ILIA_MUSEE_PIECES.includes(salle);
}
function iliaMuseeEchapper(t) {
  return String(t == null ? '' : t).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function iliaMuseeMotif(raison) {
  return ({
    pas_sur_place: 'Vous devez être dans le musée de Novomirsk.',
    dialogue_non_ouvert: 'Ouvrez d’abord les questions.',
    questions_epuisees: 'Vous avez posé vos trois questions dans cette salle aujourd’hui.',
    pa_insuffisants: 'Vous n’avez pas assez de PA.'
  })[raison] || 'Le guide ne peut pas répondre pour le moment.';
}
function iliaMuseeQuestionsHtml(salle) {
  const e = iliaMuseeEtat[salle];
  const messages = (iliaMuseeEchanges[salle] || []).map(m =>
    '<p class="' + (m.role === 'user' ? 'cpj-note' : '') + '"><strong>' +
    (m.role === 'user' ? 'Vous' : 'Ilia') + ' :</strong> ' + iliaMuseeEchapper(m.content) + '</p>').join('');
  let controles;
  if (!e || !e.ouvert) {
    controles = '<p class="cpj-note">Si vous voulez en savoir davantage, pour 1 PA je réponds à trois questions dans cette salle, aujourd’hui.</p>'
      + '<button class="cpj-touche cpj-primaire" onclick="iliaMuseeOuvrirQuestions()">Poser des questions (1 PA)</button>';
  } else if (e.restantes > 0) {
    controles = '<textarea id="ilia-musee-question" class="cpj-champ" rows="2" maxlength="500" style="width:100%" placeholder="Votre question sur Novomirsk…"></textarea>'
      + '<button class="cpj-touche cpj-primaire" onclick="iliaMuseePoser()">Demander (' + e.restantes + ' restantes)</button>';
  } else {
    controles = '<p class="cpj-note">Je vous ai tout dit pour aujourd’hui dans cette salle. Bonne visite !</p>';
  }
  return '<div class="guide-musee-questions"><h4>Des questions pour Ilia ?</h4>' + messages + controles + '</div>';
}
async function iliaEcouterGuide(etapeTresor = false) {
  const salle = state.currentRoom;
  if (!iliaMuseeSurPlace(salle)) return;
  if (etapeTresor && salle === 'salle_origines') {
    // Même RPC que l'ancien bouton : pas de faux déclenchement client de l'énigme.
    const v = typeof sbRpcVerdict === 'function'
      ? await sbRpcVerdict('tresor_tsars_guide', {}).catch(() => null) : null;
    if (v && v.ok === false && v.raison === 'pas_sur_place') {
      if (typeof showToast === 'function') showToast('Ilia Krioukov', iliaMuseeMotif('pas_sur_place'), false);
      return;
    }
  }
  if (!iliaMuseeSurPlace(salle)) return;
  const rendre = () => {
    if (!iliaMuseeSurPlace(salle)) return;
    const texte = ILIA_MUSEE_RECITS[salle];
    const html = '<div class="guide-musee-fiche"><img src="' + ILIA_MUSEE_PORTRAIT +
      '" alt="" style="float:left;width:96px;height:96px;object-fit:cover;border-radius:50%;margin:0 .8rem .4rem 0">'
      + texte.split('\n\n').map(p => '<p>' + iliaMuseeEchapper(p) + '</p>').join('')
      + iliaMuseeQuestionsHtml(salle) + '</div>';
    if (typeof sovModal === 'function') sovModal('Ilia Krioukov — Guide du musée municipal', html, rendre);
    else if (typeof vehModal === 'function') vehModal('Ilia Krioukov — Guide du musée municipal', html);
  };
  iliaMuseeRendu = rendre;
  rendre();
  if (typeof sbRpcVerdict === 'function') {
    const v = await sbRpcVerdict('guide_musee_dialogue_lire', {}).catch(() => null);
    if (iliaMuseeSurPlace(salle) && v?.ok === true && v.salle === 'novomirsk:' + salle) {
      iliaMuseeEtat[salle] = {ouvert: v.ouvert === true, restantes: Number(v.restantes) || 0};
      rendre();
    }
  }
}
async function iliaMuseeOuvrirQuestions() {
  if (iliaMuseeOccupé || !iliaMuseeSurPlace(state.currentRoom)) return;
  iliaMuseeOccupé = true;
  try {
    const v = await sbRpcVerdict('guide_musee_dialogue_ouvrir', {}).catch(() => null);
    if (v?.ok !== true || v.salle !== 'novomirsk:' + state.currentRoom) {
      if (typeof showToast === 'function') showToast('Ilia Krioukov', iliaMuseeMotif(v?.raison), false);
      return;
    }
    if (v.pa != null && typeof appliquerPaiementServeur === 'function')
      appliquerPaiementServeur({pa:v.pa, liquide:v.liquide, arg:v.arg});
    if (typeof updateUI === 'function') updateUI();
    iliaMuseeEtat[state.currentRoom] = {ouvert:true, restantes:Number(v.restantes)||0};
    if (iliaMuseeRendu) iliaMuseeRendu();
  } finally { iliaMuseeOccupé = false; }
}
async function iliaMuseePoser() {
  const salle = state.currentRoom, e = iliaMuseeEtat[salle];
  const champ = document.getElementById('ilia-musee-question');
  const question = String(champ?.value || '').trim().slice(0,500);
  if (!iliaMuseeSurPlace(salle) || !question || !e || !(e.restantes > 0) || iliaMuseeOccupé) return;
  iliaMuseeOccupé = true;
  const bouton = champ?.nextElementSibling;
  if (bouton) {bouton.disabled = true; bouton.textContent = 'Ilia réfléchit…';}
  try {
    if (typeof rpAuthAssurerSession === 'function') await rpAuthAssurerSession().catch(() => null);
    const jeton = typeof rpAuthJeton === 'function' ? rpAuthJeton() : null;
    const langue = typeof langueDuJeu === 'function' ? langueDuJeu() : 'fr';
    const historique = (iliaMuseeEchanges[salle] || []).slice(-6);
    const resp = jeton ? await fetch('/api/chat', {
      method:'POST', headers:{'Content-Type':'application/json','Authorization':'Bearer '+jeton},
      body:JSON.stringify({profil:'veteran_ilia_krioukov',lang:langue,message:question,historique})
    }).catch(() => null) : null;
    const d = resp ? await resp.json().catch(() => null) : null;
    if (!resp?.ok || typeof d?.reponse !== 'string') {
      if (d?.raison === 'questions_epuisees' || d?.raison === 'dialogue_non_ouvert')
        iliaMuseeEtat[salle] = {ouvert:d.raison === 'questions_epuisees', restantes:0};
      if (typeof showToast === 'function') showToast('Ilia Krioukov', iliaMuseeMotif(d?.raison), false);
      if (iliaMuseeRendu) iliaMuseeRendu();
      return;
    }
    (iliaMuseeEchanges[salle] = iliaMuseeEchanges[salle] || []).push(
      {role:'user',content:question},{role:'assistant',content:d.reponse});
    iliaMuseeEtat[salle] = {ouvert:true, restantes:Math.max(0,Number(d.restantes)||0)};
    if (iliaMuseeRendu) iliaMuseeRendu();
  } finally {
    iliaMuseeOccupé = false;
    if (bouton && document.body.contains(bouton)) bouton.disabled = false;
  }
}
