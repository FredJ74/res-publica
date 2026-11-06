// SALLES DE REUNION DE NOVOMIRSK : EVENEMENTS (07/11/2026, decision de Fred).
// Le serveur (sovarka_reunion_evenement) verifie tout : reservation du jour, presence, evenement
// deja tenu, paiement, participants et effets. L'ecran n'affiche que la reponse.

const REUNION_EVENEMENTS = {
  conference_presse: { titre: 'Conférence de presse',
    desc: 'Vous prenez la parole : +3 POP, et +1 POP par personne présente dans la salle (au plus +10).' },
  reseautage: { titre: 'Soirée de réseautage',
    desc: 'Chaque personne présente gagne +2 INF ; vous gagnez +1 INF par participant (au plus +8).' },
  seminaire: { titre: 'Séminaire de formation',
    desc: 'Toutes les personnes présentes, vous compris, gagnent +1 à la caractéristique choisie jusqu’à minuit (sans cumul de séminaires).' },
  buffet: { titre: 'Buffet du Grand Hôtel',
    desc: 'Le restaurant du Grand Hôtel livre un buffet : 40 PSK par personne présente, à votre charge ; chacun gagne +2 PA.' }
};
const REUNION_CARACS = { CHA: 'Charisme', DUP: 'Duplicité', ENT: 'Entregent', INT: 'Intelligence', PER: 'Perception', VOL: 'Volonté' };
const REUNION_MOTIFS = {
  salle_non_reservee: 'Seul celui qui a réservé la salle aujourd’hui peut y organiser un événement.',
  evenement_deja_tenu: 'Cet événement a déjà eu lieu dans cette salle aujourd’hui.',
  pas_sur_place: 'Vous devez vous trouver dans la salle.',
  caracteristique_inconnue: 'Choisissez la caractéristique du séminaire.',
  fonds_insuffisants: 'Vous ne disposez pas de suffisamment de PSK pour le buffet.',
  pa_insuffisants: 'Vous n’avez pas assez de PA.',
  acteur_non_authentifie: 'Votre session doit être rétablie.'
};
let reunionEvenementEnCours = false;

function ouvrirReunionEvenement() {
  const salle = state.currentRoom;
  let html = '<p>Vous avez réservé la salle pour la journée ? Organisez-y un événement. Chaque événement coûte 1 PA et ' +
    'ne peut avoir lieu qu’une fois par salle et par jour. Les participants sont les personnes présentes dans la salle ' +
    'au moment où vous le lancez.</p>';
  for (const [type, e] of Object.entries(REUNION_EVENEMENTS)) {
    let corps = '<p style="margin:.4rem 0">' + e.desc + '</p>';
    if (type === 'seminaire') {
      corps += '<select id="reunion-carac" class="cpj-champ" style="margin-top:.3rem">' +
        Object.entries(REUNION_CARACS).map(([k, l]) => '<option value="' + k + '">' + l + '</option>').join('') + '</select><br>';
    }
    corps += vehBouton('Organiser', "lancerReunionEvenement('" + type + "','" + salle + "')", true);
    html += vehSection(e.titre, corps);
  }
  vehModal('Organiser un événement', html);
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
      showToast('Événement refusé', REUNION_MOTIFS[v?.raison] || 'Le serveur n’a pas confirmé l’événement.', false);
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
    showToast(v.titre || 'Événement', n + ' personne' + (n > 1 ? 's' : '') + ' présente' + (n > 1 ? 's' : '') +
      (v.paye ? ' ; buffet payé ' + v.paye + ' PSK.' : '.'), true);
  } finally { reunionEvenementEnCours = false; }
}
