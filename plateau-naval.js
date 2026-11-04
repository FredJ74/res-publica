// Chantier naval de Port-Sainte-Marie : toutes les décisions serveur.
// Les bateaux livrés sont des actifs au port, PAS des objets d'inventaire.
'use strict';

const CHANTIER_NAVAL_MODELES = Object.freeze({
  bateau_3: 'Bateau 3 places',
  bateau_5: 'Bateau 5 places'
});
const navalEchappe = v => String(v == null ? '' : v).replace(/[&<>"']/g, c =>
  ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
const navalNombre = v => Number(v || 0).toLocaleString('fr-FR',{maximumFractionDigits:0});
let CHANTIER_NAVAL_DEVIS_COURANT = [];
let CHANTIER_NAVAL_CONTEXTE = null;
function navalContexteValide(o) {
  const c=sbContexteInventaire();
  return !!o && o.personnage===c.personnage && o.uid===c.uid && o.jeton===c.jeton && o.generation===c.generation
    && state.country==='republic' && state.currentCity==='ville_a' && state.currentBuilding==='chantier-naval';
}

async function commanderBateauNaval(modele) {
  if (!Object.prototype.hasOwnProperty.call(CHANTIER_NAVAL_MODELES,modele) ||
      state.country !== 'republic' || state.currentCity !== 'ville_a' ||
      state.currentBuilding !== 'chantier-naval') {
    showToast('Chantier naval','Vous devez être présent au chantier naval de PSM.',false);
    return;
  }
  const devis = CHANTIER_NAVAL_DEVIS_COURANT.find(x => x.modele === modele);
  if (!devis || !navalContexteValide(CHANTIER_NAVAL_CONTEXTE)) {
    showToast('Devis périmé','Rouvrez le catalogue avant de commander.',false);
    return;
  }
  const prix = Number(devis.prix_total_fr);
  const acompte = Number(devis.acompte);
  if (!window.confirm('Commander ' + CHANTIER_NAVAL_MODELES[modele] +
      ' pour ' + navalNombre(prix) + ' FR ?\n' +
      'Acompte immédiat : ' + navalNombre(acompte) +
      ' FR. Le solde est payable pendant ' + Number(devis.jours) + ' journées de travail effectives. ' +
      'Un manque de matériaux suspend la progression et les échéances.')) return;
  const resultat = await executerReceptionInventaire('chantier_naval_commander', {p_modele:modele});
  if (!resultat) return; // Le pilote commun conserve la clé et distingue transport/refus.
  showToast('Commande enregistrée','Acompte de '+navalNombre(resultat.acompte)+' FR confirmé côté serveur.',true);
  await ouvrirDevisChantierNaval();
}

async function ouvrirDevisChantierNaval() {
  if (state.country !== 'republic' || state.currentCity !== 'ville_a' ||
      state.currentBuilding !== 'chantier-naval') {
    showToast('Chantier naval', 'Présentez-vous au chantier naval de Port-Sainte-Marie.', false);
    return;
  }
  const origine=sbContexteInventaire();
  let devis, commandes;
  try {
    [devis,commandes] = await Promise.all([
      sbRpcVerdict('chantier_naval_devis', {}, {encoreValide:()=>navalContexteValide(origine)}),
      sbRpcVerdict('chantier_naval_mes_commandes', {}, {encoreValide:()=>navalContexteValide(origine)})
    ]);
  } catch (e) {
    showToast('Devis indisponible','Impossible de vérifier les contrats et stocks auprès du serveur.',false);
    return;
  }
  if (!navalContexteValide(origine)) return;
  const panne=[devis,commandes].find(x=>x && x.transport);
  if (panne) {
    showToast('Devis indisponible',panne.transport.etat==='session_perdue'
      ? 'Votre session doit être rétablie avant de consulter le chantier.'
      : 'La réponse du serveur est indisponible. Réessayez la consultation.',false);
    return;
  }
  if (!Array.isArray(devis) || devis.length !== 2 || !Array.isArray(commandes) ||
      devis.some(x=>!x || !x.recette || !x.entrepot_psm || !CHANTIER_NAVAL_MODELES[x.modele])) {
    showToast('Devis incomplet','Le catalogue du chantier naval n’est pas disponible.',false);
    return;
  }
  CHANTIER_NAVAL_DEVIS_COURANT = devis;
  CHANTIER_NAVAL_CONTEXTE = origine;
  let html = '<div class="cpj-dialogue">' +
    '<p class="cpj-note">Construction sur commande, sur 7 ou 10 journées effectives. ' +
    'L’absence de matériaux bloque le chantier, sans prélèvement ni journée perdue.</p>';
  for (const x of devis) {
    const nom = CHANTIER_NAVAL_MODELES[x.modele];
    const jours = Number(x.jours);
    const acompte = Number(x.acompte);
    html += '<section style="border-radius:8px;padding:.9rem;margin-bottom:.8rem">' +
      '<strong class="cpj-titre">' + navalEchappe(nom) + '</strong>' +
      '<div>' + navalNombre(x.passagers) + ' passagers · ' + navalNombre(x.fret) +
      ' unités de fret · ' + navalNombre(x.prix_total_fr) + ' FR</div>' +
      '<div style="font-size:.83rem;margin-top:.5rem">' +
      jours+' jours effectifs · acompte '+navalNombre(acompte)+' FR (35 %) · solde au fil des travaux (65 %)</div>' +
      '<div style="font-size:.83rem;margin-top:.5rem">Matériaux nécessaires : ' +
      navalNombre(x.recette.bois)+' bois, '+navalNombre(x.recette.metal)+' métal, ' +
      navalNombre(x.recette.derives_petrochimiques)+' dérivés pétrochimiques.</div>' +
      '<div class="cpj-note">Entrepôt PSM : ' +
      navalNombre(x.entrepot_psm.bois)+' bois, '+navalNombre(x.entrepot_psm.metal)+
      ' métal, '+navalNombre(x.entrepot_psm.derives_petrochimiques)+' dérivés.</div>' +
      '<div class="cpj-note">Manque pour une construction complète : ' +
      navalNombre(x.manquant_psm.bois)+' bois, '+navalNombre(x.manquant_psm.metal)+
      ' métal, '+navalNombre(x.manquant_psm.derives_petrochimiques)+' dérivés.</div>' +
      '<button class="cpj-touche cpj-primaire" style="margin-top:.7rem" ' +
      'onclick="commanderBateauNaval(\''+x.modele+'\')">Commander — acompte '+navalNombre(acompte)+' FR</button>' +
      '</section>';
  }
  if (commandes.length) {
    html += '<strong class="cpj-titre">Mes constructions et bateaux</strong>';
    for (const c of commandes) {
      const navire = c.bateau_id ?
        '<div class="cpj-note">Bateau livré au port de PSM — immatriculation '+navalEchappe(c.bateau_id)+
        ' — '+navalNombre(c.bateau?.passagers)+' places, '+navalNombre(c.bateau?.fret)+' unités de fret (navigation privée non encore activée).</div>' : '';
      const etat = c.etat==='bloque_matieres' ? 'Bloqué : matériaux insuffisants' :
        c.etat==='bloque_finances' ? 'Bloqué : fonds insuffisants ou budget matières épuisé' :
        c.etat==='acheve' ? 'Achevé' : 'En construction';
      html += '<div style="border-radius:8px;padding:.6rem;margin-top:.5rem">' +
       navalEchappe(CHANTIER_NAVAL_MODELES[c.modele] || c.modele) + ' — ' +
       navalNombre(c.jours)+' / '+navalNombre(c.total)+' journées · '+navalEchappe(etat) +
       '<div>Payé : '+navalNombre(c.verse)+' / '+navalNombre(c.prix_total)+' FR</div>' +
       navire+'</div>';
    }
  }
  html += '</div>';
  const titre=document.getElementById('postes-modal-title');
  const body=document.getElementById('postes-body');
  const modal=document.getElementById('modal-postes');
  if (!titre || !body || !modal) return;
  titre.textContent='Chantier naval Le Roux — commandes';
  body.innerHTML=html;
  modal.classList.add('open');
}
