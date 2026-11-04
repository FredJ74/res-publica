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

async function commanderBateauNaval(modele) {
  if (!Object.prototype.hasOwnProperty.call(CHANTIER_NAVAL_MODELES,modele) ||
      state.country !== 'republic' || state.currentCity !== 'ville_a' ||
      state.currentBuilding !== 'chantier-naval') {
    showToast('Chantier naval','Vous devez être présent au chantier naval de PSM.',false);
    return;
  }
  const prix = modele === 'bateau_3' ? 90000 : 150000;
  const acompte = prix * 35 / 100;
  if (!window.confirm('Commander ' + CHANTIER_NAVAL_MODELES[modele] +
      ' pour ' + navalNombre(prix) + ' FR ?\\n' +
      'Acompte immédiat : ' + navalNombre(acompte) +
      ' FR. Le solde est payable pendant 7 ou 10 journées de travail effectives. ' +
      'Un manque de matériaux suspend la progression et les échéances.')) return;
  const cle = 'naval-commande-attente:' + modele;
  let requete = sessionStorage.getItem(cle);
  if (!requete) {
    requete = crypto.randomUUID();
    sessionStorage.setItem(cle,requete);
  }
  let resultat;
  try {
    resultat = await sbRpc('chantier_naval_commander', {p_modele:modele,p_requete:requete});
  } catch (e) {
    showToast('Commande non confirmée','Réessayez : la référence est conservée pour éviter un second acompte.',false);
    return;
  }
  if (!resultat || resultat.ok !== true) {
    const raisons = {
      fonds_insuffisants:'Fonds insuffisants pour l’acompte.',
      lieu_incorrect:'Vous devez être au chantier naval.',
      requete_deja_utilisee:'Cette référence a déjà été utilisée pour un autre modèle.'
    };
    showToast('Commande refusée',raisons[resultat?.raison] || 'Le serveur refuse cette commande.',false);
    return;
  }
  sessionStorage.removeItem(cle);
  showToast('Commande enregistrée','Acompte de '+navalNombre(resultat.acompte)+' FR confirmé côté serveur.');
  await ouvrirDevisChantierNaval();
}

async function ouvrirDevisChantierNaval() {
  if (state.country !== 'republic' || state.currentCity !== 'ville_a' ||
      state.currentBuilding !== 'chantier-naval') {
    showToast('Chantier naval', 'Présentez-vous au chantier naval de Port-Sainte-Marie.', false);
    return;
  }
  let devis, commandes;
  try {
    [devis,commandes] = await Promise.all([
      sbRpc('chantier_naval_devis', {}),
      sbRpc('chantier_naval_mes_commandes', {})
    ]);
  } catch (e) {
    showToast('Devis indisponible','Impossible de vérifier les contrats et stocks auprès du serveur.',false);
    return;
  }
  if (!Array.isArray(devis) || devis.length !== 2 || !Array.isArray(commandes) ||
      devis.some(x=>!x || !x.recette || !x.entrepot_psm || !CHANTIER_NAVAL_MODELES[x.modele])) {
    showToast('Devis incomplet','Le catalogue du chantier naval n’est pas disponible.',false);
    return;
  }
  let html = '<div style="padding:1rem;color:#e0e6ed;background:#151A21">' +
    '<p style="font-size:.87rem;color:#d0b777">Construction sur commande, sur 7 ou 10 journées effectives. ' +
    'L’absence de matériaux bloque le chantier, sans prélèvement ni journée perdue.</p>';
  for (const x of devis) {
    const nom = CHANTIER_NAVAL_MODELES[x.modele];
    const jours = x.modele==='bateau_3' ? 7 : 10;
    const acompte = Math.round(x.prix_total_fr*0.35);
    html += '<section style="border:1px solid #394656;border-radius:8px;padding:.9rem;margin-bottom:.8rem">' +
      '<strong style="color:#eac67a">' + navalEchappe(nom) + '</strong>' +
      '<div>' + navalNombre(x.passagers) + ' passagers · ' + navalNombre(x.fret) +
      ' unités de fret · ' + navalNombre(x.prix_total_fr) + ' FR</div>' +
      '<div style="font-size:.83rem;margin-top:.5rem">' +
      jours+' jours effectifs · acompte '+navalNombre(acompte)+' FR (35 %) · solde au fil des travaux (65 %)</div>' +
      '<div style="font-size:.83rem;margin-top:.5rem">Matériaux nécessaires : ' +
      navalNombre(x.recette.bois)+' bois, '+navalNombre(x.recette.metal)+' métal, ' +
      navalNombre(x.recette.derives_petrochimiques)+' dérivés pétrochimiques.</div>' +
      '<div style="font-size:.78rem;color:#a9b7c4;margin-top:.35rem">Entrepôt PSM : ' +
      navalNombre(x.entrepot_psm.bois)+' bois, '+navalNombre(x.entrepot_psm.metal)+
      ' métal, '+navalNombre(x.entrepot_psm.derives_petrochimiques)+' dérivés.</div>' +
      '<div style="font-size:.78rem;color:#dfb58a">Manque pour une construction complète : ' +
      navalNombre(x.manquant_psm.bois)+' bois, '+navalNombre(x.manquant_psm.metal)+
      ' métal, '+navalNombre(x.manquant_psm.derives_petrochimiques)+' dérivés.</div>' +
      '<button class="cpj-touche cpj-primaire" style="margin-top:.7rem" ' +
      'onclick="commanderBateauNaval(\''+x.modele+'\')">Commander — acompte '+navalNombre(acompte)+' FR</button>' +
      '</section>';
  }
  if (commandes.length) {
    html += '<strong style="color:#eac67a">Mes constructions et bateaux</strong>';
    for (const c of commandes) {
      const navire = c.bateau_id ?
        '<div style="color:#9ecfa5">Bateau livré au port de PSM — immatriculation '+navalEchappe(c.bateau_id)+
        ' (navigation privée non encore activée).</div>' : '';
      const etat = c.etat==='bloque_matieres' ? 'Bloqué : matériaux insuffisants' :
        c.etat==='bloque_finances' ? 'Bloqué : fonds insuffisants ou budget matières épuisé' :
        c.etat==='acheve' ? 'Achevé' : 'En construction';
      html += '<div style="border:1px solid #394656;border-radius:8px;padding:.6rem;margin-top:.5rem">' +
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
