// SALLES DE REUNION DE NOVOMIRSK : EVENEMENTS (07/11/2026, decision de Fred).
// Le serveur (sovarka_reunion_evenement) verifie tout : reservation du jour, presence, evenement
// deja tenu, paiement, participants et effets. L'ecran n'affiche que la reponse.

// Textes d'affichage : catalogue i18n/sovarka-messages-resources.js (français de référence et de repli).
const reuT = (k, v) => (typeof texteSovMessages === 'function' ? texteSovMessages(k, v) : k);
const REUNION_EVENEMENTS = ['conference_presse', 'reseautage', 'seminaire', 'buffet'];
const REUNION_CARACS = ['CHA', 'DUP', 'ENT', 'INT', 'PER', 'VOL'];
const REUNION_MOTIFS = ['salle_non_reservee', 'evenement_deja_tenu', 'pas_sur_place', 'caracteristique_inconnue',
  'fonds_insuffisants', 'pa_insuffisants', 'acteur_non_authentifie', 'evenement_inconnu'];
let reunionEvenementEnCours = false;

function ouvrirReunionEvenement() {
  const salle = state.currentRoom;
  let html = '<p>' + reuT('re_intro') + '</p>';
  for (const type of REUNION_EVENEMENTS) {
    let corps = '<p style="margin:.4rem 0">' + reuT('re_d_' + type) + '</p>';
    if (type === 'seminaire') {
      corps += '<select id="reunion-carac" class="cpj-champ" style="margin-top:.3rem">' +
        REUNION_CARACS.map(k => '<option value="' + k + '">' + reuT('re_c_' + k) + '</option>').join('') + '</select><br>';
    }
    corps += vehBouton(reuT('re_organize'), "lancerReunionEvenement('" + type + "','" + salle + "')", true);
    html += vehSection(reuT('re_t_' + type), corps);
  }
  vehModal(reuT('re_title'), html);
}

async function lancerReunionEvenement(type, salle) {
  if (reunionEvenementEnCours) return;
  reunionEvenementEnCours = true;
  const carac = type === 'seminaire' ? (document.getElementById('reunion-carac')?.value || null) : null;
  const cle = 'hg-reunion:' + (state.char?.name || '') + ':' + salle + ':' + type;
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict('sovarka_reunion_evenement',
      { p_requete: requete, p_salle: salle, p_type: type, p_carac: carac }).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(cle);
    if (!v || v.ok !== true) {
      showToast(reuT('re_tRefused'), REUNION_MOTIFS.includes(v?.raison) ? reuT('re_m_' + v.raison) : reuT('re_notConfirmed'), false);
      return;
    }
    if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (v.jauges && typeof adopterJaugeServeur === 'function') {
      if (v.jauges.pop != null) adopterJaugeServeur('pop', v.jauges.pop);
      if (v.jauges.inf != null) adopterJaugeServeur('inf', v.jauges.inf);
    }
    if (Array.isArray(v.effets_actifs)) state.effetsActifs = v.effets_actifs;
    if (typeof updateHeader === 'function') updateHeader();
    if (typeof updateUI === 'function') updateUI();
    document.getElementById('modal-postes')?.classList.remove('open');
    const n = (v.presents || []).length;
    // Titre : celui de l'événement confirmé (type renvoyé par le serveur), sinon le titre du serveur tel quel.
    const titre = REUNION_EVENEMENTS.includes(v.type) ? reuT('re_t_' + v.type) : (v.titre || reuT('re_tEvent'));
    const presents = reuT(n > 1 ? 're_present_many' : 're_present_one', { n });
    showToast(titre, v.paye ? reuT('re_doneBuffet', { presents, montant: v.paye }) : reuT('re_done', { presents }), true);
  } finally { reunionEvenementEnCours = false; }
}
