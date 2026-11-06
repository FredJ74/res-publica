// SALON DE COIFFURE (decisions de Fred du 06/11/2026, GAME-DESIGN-SALON-COIFFURE.md).
// La coupe : +5 POP, CHA +1 jusqu'a minuit sans cumul, une coupe tous les 3 jours. Tout est decide
// par le serveur (salon_coupe / salon_lire) ; l'ecran n'affiche que la reponse.
// Tant que le prix n'est pas fixe (logique de prix de Sovarka a decider), l'ordre est declare
// `bientot` dans data.js et cette fenetre n'est pas atteinte ; le serveur refuserait de toute
// facon (prix_non_fixe) avant tout debit.

const SALON_MOTIFS = {
  prix_non_fixe: 'Le salon n’a pas encore fixé le prix de ses coupes.',
  cheveux_pas_repousses: 'Vos cheveux n’ont pas encore repoussé.',
  pas_sur_place: 'Présentez-vous au salon.',
  salon_introuvable: 'Ce salon ne propose pas de coupe.',
  fonds_insuffisants: 'Vous n’avez pas assez d’argent.'
};
let salonActeEnCours = false;

async function ouvrirSalonCoupe() {
  const l = await sbRpcVerdict('salon_lire', {}).catch(() => null);
  if (!l || l.ok !== true) { showToast('Salon de coiffure', 'Lecture impossible auprès du serveur.', false); return; }
  if (!l.salon) { showToast('Salon de coiffure', SALON_MOTIFS.pas_sur_place, false); return; }
  const cur = (typeof COUNTRIES !== 'undefined' && COUNTRIES[state.country]?.cur) || 'FR';
  const attente = l.prochaineCoupeJour != null && l.jour < l.prochaineCoupeJour;
  let html = '<p class="cpj-note">Une coupe rapporte 5 points de popularité et +1 en charisme ' +
    'jusqu’à minuit. Il faut attendre 3 jours entre deux coupes.</p>';
  if (l.salon.prixCoupe == null) html += '<p>' + SALON_MOTIFS.prix_non_fixe + '</p>';
  else if (attente) html += '<p>' + SALON_MOTIFS.cheveux_pas_repousses + ' Prochaine coupe possible dans ' +
    (l.prochaineCoupeJour - l.jour) + ' jour(s).</p>';
  else html += '<button class="cpj-touche cpj-primaire" onclick="salonCouper(\'' + l.salon.id + '\')">Se faire couper les cheveux — ' +
    Number(l.salon.prixCoupe).toLocaleString('fr-FR') + ' ' + cur + '</button>';
  vehModal('Salon de coiffure', html);
}

async function salonCouper(entreprise) {
  if (salonActeEnCours) return;
  salonActeEnCours = true;
  const cle = 'hg-salon:' + (state.char?.name || '') + ':coupe';
  try {
    let requete = sessionStorage.getItem(cle);
    if (!requete) { requete = crypto.randomUUID(); sessionStorage.setItem(cle, requete); }
    const v = await sbRpcVerdict('salon_coupe', { p_requete: requete, p_entreprise: entreprise }).catch(() => null);
    if (v && !v.transport) sessionStorage.removeItem(cle);
    if (!v || v.ok !== true) {
      showToast('Coupe refusée', SALON_MOTIFS[v?.raison] || 'Le serveur n’a pas répondu.', false);
      return;
    }
    if (typeof appliquerPaiementServeur === 'function') appliquerPaiementServeur({ pa: v.pa, liquide: v.liquide, arg: v.arg });
    if (v.jauges && v.jauges.pop != null && typeof adopterJaugeServeur === 'function') adopterJaugeServeur('pop', v.jauges.pop);
    if (Array.isArray(v.effets_actifs)) state.effetsActifs = v.effets_actifs;
    if (typeof updateHeader === 'function') updateHeader();
    document.getElementById('modal-postes')?.classList.remove('open');
    showToast('Fraîchement coiffé', '+5 popularité' + (v.bonusCha ? ', +1 charisme jusqu’à minuit.' : '.'), true);
  } finally { salonActeEnCours = false; }
}
