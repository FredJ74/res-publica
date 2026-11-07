// POUVOIR EN SOVARKA (07/11/2026, décisions de Fred, GAME-DESIGN-NOVOMIRSK.md).
// Soviet Suprême : sièges répartis à la semaine à la gloire des partis, députés désignés par
// les chefs de parti. Le serveur décide tout (sovarka_soviet_etat, sovarka_depute_designer) ;
// l'écran n'affiche que ses réponses.

const SOVIET_MOTIFS = {
  pas_chef_de_parti: 'Seul le chef d’un parti de Sovarka désigne les députés de son parti.',
  pas_sur_place: 'Les députés se désignent à l’hémicycle du Soviet Suprême.',
  aucun_siege: 'Votre parti n’a obtenu aucun siège à la dernière semaine à la gloire.',
  sieges_pourvus: 'Tous les sièges de votre parti sont déjà pourvus.',
  hors_parti: 'Seuls les membres de votre parti peuvent siéger en son nom.',
  deja_depute: 'Cette personne est déjà député.',
  pas_depute_du_parti: 'Cette personne ne siège pas pour votre parti.',
  personnage_introuvable: 'Personnage introuvable.',
  acteur_non_authentifie: 'Votre session doit être rétablie.'
};
let sovietDesignationEnCours = false;

function sovEchapper(s) {
  if (typeof escapeHtmlText === 'function') return escapeHtmlText(s);
  return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

async function ouvrirSovietSupreme() {
  const v = await sbRpcVerdict('sovarka_soviet_etat', {}).catch(() => null);
  if (!v || v.ok !== true) {
    showToast('Soviet Suprême', SOVIET_MOTIFS[v?.raison] || 'Le serveur n’a pas répondu.', false);
    return;
  }
  const scores = Array.isArray(v.scores) ? v.scores : [];
  const sieges = v.sieges || {};
  const deputes = v.deputes || {};
  let html = '<p>Les 9 sièges du Soviet Suprême sont répartis entre les partis à la proportionnelle de leurs ' +
    'partisans, lors de la semaine à la gloire des partis. Chaque chef de parti désigne ensuite ses députés.</p>';
  if (!scores.length) {
    html += vehSection('Législature', '<p class="cpj-note">Aucune semaine à la gloire n’a encore été proclamée.</p>');
  } else {
    let corps = v.vainqueur ? '<p>Parti vainqueur : <strong>' + sovEchapper(v.vainqueur) + '</strong></p>' : '';
    scores.forEach(s => {
      const noms = Array.isArray(deputes[s.partiId]) ? deputes[s.partiId] : [];
      corps += '<p style="margin:.35rem 0"><strong>' + sovEchapper(s.nom) + '</strong> — ' +
        (sieges[s.partiId] || 0) + ' siège(s) · ' + (s.adherentsPJ || 0) + ' adhérent(s), ' +
        (s.partisansPNJ || 0) + ' partisan(s)' +
        (noms.length ? '<br><span class="cpj-note">Députés : ' + noms.map(sovEchapper).join(', ') + '</span>' : '') + '</p>';
    });
    html += vehSection('Législature en cours', corps);
  }
  if (v.chef && v.monParti) {
    const miens = Array.isArray(deputes[v.monParti]) ? deputes[v.monParti] : [];
    const nb = sieges[v.monParti] || 0;
    let corps = '<p>' + miens.length + ' / ' + nb + ' siège(s) pourvu(s).</p>';
    (Array.isArray(v.membres) ? v.membres : []).forEach(nom => {
      const siege = miens.indexOf(nom) >= 0;
      const js = 'designerDeputeSoviet(' + JSON.stringify(nom).replace(/"/g, '&quot;') + ',' + siege + ')';
      corps += '<div style="margin:.3rem 0">' + sovEchapper(nom) + (siege ? ' — <em>député</em>' : '') +
        vehBouton(siege ? 'Retirer le siège' : 'Désigner député', js, !siege) + '</div>';
    });
    html += vehSection('Désigner les députés de votre parti', corps);
  }
  vehModal('Soviet Suprême', html);
}

async function designerDeputeSoviet(nom, retirer) {
  if (sovietDesignationEnCours) return;
  sovietDesignationEnCours = true;
  try {
    const v = await sbRpcVerdict('sovarka_depute_designer', { p_nom: nom, p_retirer: !!retirer }).catch(() => null);
    if (!v || v.ok !== true) {
      showToast('Soviet Suprême', SOVIET_MOTIFS[v?.raison] || 'Le serveur n’a pas confirmé.', false);
      return;
    }
    showToast('Soviet Suprême', retirer ? nom + ' ne siège plus.' : nom + ' siège désormais au Soviet Suprême.', true);
    await ouvrirSovietSupreme();
  } finally { sovietDesignationEnCours = false; }
}

// REPAS PRESIDENTIEL (étape 6, Fred 07/11/2026) : un repas gratuit par jour dans les appartements
// du Palais du Parti, avec un invité présent s'il le souhaite ; effets du dîner d'affaires. Le
// serveur (sovarka_repas_presidentiel) vérifie le président, le lieu, l'invité et le jour.
const REPAS_PRES_MOTIFS = {
  reserve_president: 'Réservé au Président de la République de Sovarka.',
  pas_sur_place: 'Le repas se prend dans les appartements présidentiels.',
  deja_pris_aujourdhui: 'Le repas présidentiel a déjà été servi aujourd’hui.',
  invite_absent: 'Votre invité doit se trouver avec vous dans les appartements.',
  invite_invalide: 'Choisissez un autre invité.',
  acteur_non_authentifie: 'Votre session doit être rétablie.'
};
let repasPresidentielEnCours = false;

async function ouvrirRepasPresidentiel() {
  const presents = (typeof sbGetPresencesInRoom === 'function')
    ? await sbGetPresencesInRoom(state.country, state.currentCity, state.currentBuilding, state.currentRoom).catch(() => [])
    : [];
  const moi = state.char?.name || '';
  const noms = Array.from(new Set((presents || []).map(p => p.name || p.nom).filter(n => n && n !== moi)));
  let corps = '<p>Un repas offert par jour : +10 Santé, +2 Moral, +5 INF et +3 PA au prochain Dormir, ' +
    'pour vous et pour votre invité.</p><select id="repas-pres-invite" class="cpj-champ"><option value="">Seul</option>' +
    noms.map(n => '<option value="' + sovEchapper(n) + '">' + sovEchapper(n) + '</option>').join('') + '</select><br>' +
    vehBouton('Faire servir le repas', 'servirRepasPresidentiel()', true);
  vehModal('Appartements présidentiels', vehSection('Repas du Président', corps));
}

async function servirRepasPresidentiel() {
  if (repasPresidentielEnCours) return;
  repasPresidentielEnCours = true;
  const invite = document.getElementById('repas-pres-invite')?.value || null;
  const cle = 'hg-repas-pres:' + (state.char?.name || '') + ':' + new Date().toISOString().slice(0, 10);
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict('sovarka_repas_presidentiel', { p_requete: requete, p_invite: invite }).catch(() => null);
    if (v && !v.transport && v.ok !== true) sessionStorage.removeItem(cle);
    if (!v || v.ok !== true) {
      showToast('Repas présidentiel', REPAS_PRES_MOTIFS[v?.raison] || 'Le serveur n’a pas confirmé le repas.', false);
      return;
    }
    if (typeof v.hp === 'number') state.hp = v.hp;
    if (typeof v.moral === 'number') state.moral = v.moral;
    if (v.inf != null && typeof adopterJaugeServeur === 'function') adopterJaugeServeur('inf', v.inf);
    if (typeof updateHeader === 'function') updateHeader();
    if (typeof updateUI === 'function') updateUI();
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast('Repas présidentiel', v.invite ? 'Servi pour vous et ' + v.invite + '.' : 'Servi.', true);
  } finally { repasPresidentielEnCours = false; }
}
