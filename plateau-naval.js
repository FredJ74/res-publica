// Chantier naval de Port-Sainte-Marie : toutes les décisions serveur.
// Les bateaux livrés sont des actifs au port, PAS des objets d'inventaire.
'use strict';
function navT(key,original,vars){const fn=window.RPNavalI18n?.text;return typeof fn==='function'?fn(key,original,vars):String(original).replace(/\{([a-z]+)\}/g,(m,k)=>Object.hasOwn(vars||{},k)?String(vars[k]):m)}
function navHtml(key,original,vars){return navalEchappe(navT(key,original,vars));}
function navalNom(modele){const nom=CHANTIER_NAVAL_MODELES[modele];return nom?navT(modele==='bateau_3'?'boat3':'boat5',nom):modele;}

const CHANTIER_NAVAL_MODELES = Object.freeze({
  bateau_3: 'Bateau 3 places',
  bateau_5: 'Bateau 5 places'
});
const navalEchappe = v => String(v == null ? '' : v).replace(/[&<>"']/g, c =>
  ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[c]));
const navalNombre = v => Number(v || 0).toLocaleString('fr-FR',{maximumFractionDigits:0});
let CHANTIER_NAVAL_DEVIS_COURANT = [];

async function commanderBateauNaval(modele) {
  if (!Object.prototype.hasOwnProperty.call(CHANTIER_NAVAL_MODELES,modele) ||
      state.country !== 'republic' || state.currentCity !== 'ville_a' ||
      state.currentBuilding !== 'chantier-naval') {
    showToast(navT('site',"Chantier naval"),navT('mustHere',"Vous devez être présent au chantier naval de PSM."),false);
    return;
  }
  const devis = CHANTIER_NAVAL_DEVIS_COURANT.find(x => x.modele === modele);
  if (!devis) {
    showToast(navT("quoteStale","Devis périmé"),navT("reopen","Rouvrez le catalogue avant de commander."),false);
    return;
  }
  const prix = Number(devis.prix_total_fr);
  const acompte = Number(devis.acompte);
  if (!window.confirm(navT('confirm',"Commander {model} pour {price} FR ?\nAcompte immédiat : {deposit} FR. Le solde est payable pendant {days} journées de travail effectives. Un manque de matériaux suspend la progression et les échéances.",{
 model:navalNom(modele),price:navalNombre(prix),deposit:navalNombre(acompte),days:Number(devis.jours)
}))) return;
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
    showToast(navT("notConfirmed","Commande non confirmée"),navT("retry","Réessayez : la référence est conservée pour éviter un second acompte."),false);
    return;
  }
  if (!resultat || resultat.ok !== true) {
    const raisons = {
      fonds_insuffisants:navT("insufficient","Fonds insuffisants pour l’acompte."),
      lieu_incorrect:navT("wrongPlace","Vous devez être au chantier naval."),
      requete_deja_utilisee:navT("usedReference","Cette référence a déjà été utilisée pour un autre modèle.")
    };
    showToast(navT("orderRefused","Commande refusée"),raisons[resultat?.raison] || navT("serverRefused","Le serveur refuse cette commande."),false);
    return;
  }
  sessionStorage.removeItem(cle);
  showToast(navT("orderRecorded","Commande enregistrée"),navT('depositConfirmed',"Acompte de {deposit} FR confirmé côté serveur.",{deposit:navalNombre(resultat.acompte)}));
  await ouvrirDevisChantierNaval();
}

async function ouvrirDevisChantierNaval() {
  if (state.country !== 'republic' || state.currentCity !== 'ville_a' ||
      state.currentBuilding !== 'chantier-naval') {
    showToast(navT('site',"Chantier naval"),navT('mustHere',"Vous devez être présent au chantier naval de PSM."),false);
    return;
  }
  let devis, commandes;
  try {
    [devis,commandes] = await Promise.all([
      sbRpc('chantier_naval_devis', {}),
      sbRpc('chantier_naval_mes_commandes', {})
    ]);
  } catch (e) {
    showToast(navT("quoteUnavailable","Devis indisponible"),navT("loadFailed","Impossible de vérifier les contrats et stocks auprès du serveur."),false);
    return;
  }
  if (!Array.isArray(devis) || devis.length !== 2 || !Array.isArray(commandes) ||
      devis.some(x=>!x || !x.recette || !x.entrepot_psm || !CHANTIER_NAVAL_MODELES[x.modele])) {
    showToast(navT("quoteIncomplete","Devis incomplet"),navT("catalogueUnavailable","Le catalogue du chantier naval n’est pas disponible."),false);
    return;
  }
  CHANTIER_NAVAL_DEVIS_COURANT = devis;
  let html = '<div style="padding:1rem;color:#e0e6ed;background:#151A21">' +
    '<p style="font-size:.87rem;color:#d0b777">'+navHtml('constructionNotice',"Construction sur commande, sur 7 ou 10 journées effectives. L’absence de matériaux bloque le chantier, sans prélèvement ni journée perdue.")+'</p>';
  for (const x of devis) {
    const nom = navalNom(x.modele);
    const jours = Number(x.jours);
    const acompte = Number(x.acompte);
    html += '<section style="border:1px solid #394656;border-radius:8px;padding:.9rem;margin-bottom:.8rem">' +
      '<strong style="color:#eac67a">' + navalEchappe(nom) + '</strong>' +
      '<div>'+navHtml('summary',"{passengers} passagers · {cargo} unités de fret · {price} FR",{passengers:navalNombre(x.passagers),cargo:navalNombre(x.fret),price:navalNombre(x.prix_total_fr)})+'</div>' +
      '<div style="font-size:.83rem;margin-top:.5rem">' +
      navHtml('terms',"{days} jours effectifs · acompte {deposit} FR (35 %) · solde au fil des travaux (65 %)",{days:jours,deposit:navalNombre(acompte)})+'</div>' +
      '<div style="font-size:.83rem;margin-top:.5rem">'+navHtml('materials',"Matériaux nécessaires : {wood} bois, {metal} métal, {derivatives} dérivés pétrochimiques.",{wood:navalNombre(x.recette.bois),metal:navalNombre(x.recette.metal),derivatives:navalNombre(x.recette.derives_petrochimiques)})+'</div>' +
      '<div style="font-size:.78rem;color:#a9b7c4;margin-top:.35rem">'+navHtml('warehouse',"Entrepôt PSM : {wood} bois, {metal} métal, {derivatives} dérivés.",{wood:navalNombre(x.entrepot_psm.bois),metal:navalNombre(x.entrepot_psm.metal),derivatives:navalNombre(x.entrepot_psm.derives_petrochimiques)})+'</div>' +
      '<div style="font-size:.78rem;color:#dfb58a">'+navHtml('missing',"Manque pour une construction complète : {wood} bois, {metal} métal, {derivatives} dérivés.",{wood:navalNombre(x.manquant_psm.bois),metal:navalNombre(x.manquant_psm.metal),derivatives:navalNombre(x.manquant_psm.derives_petrochimiques)})+'</div>' +
      '<button class="cpj-touche cpj-primaire" style="margin-top:.7rem" ' +
      'onclick="commanderBateauNaval(\''+x.modele+'\')">'+navHtml('orderButton',"Commander — acompte {deposit} FR",{deposit:navalNombre(acompte)})+'</button>' +
      '</section>';
  }
  if (commandes.length) {
    html += '<strong style="color:#eac67a">'+navHtml('myOrders',"Mes constructions et bateaux")+'</strong>';
    for (const c of commandes) {
      const navire = c.bateau_id ?
        '<div style="color:#9ecfa5">'+navHtml('delivered',"Bateau livré au port de PSM — immatriculation {id} (navigation privée non encore activée).",{id:c.bateau_id})+'</div>' : '';
      const etat = c.etat==='bloque_matieres' ? navT("blockedMaterials","Bloqué : matériaux insuffisants") :
        c.etat==='bloque_finances' ? navT("blockedFunds","Bloqué : fonds insuffisants ou budget matières épuisé") :
        c.etat==='acheve' ? navT("completed","Achevé") : navT("building","En construction");
      html += '<div style="border:1px solid #394656;border-radius:8px;padding:.6rem;margin-top:.5rem">' +
       navalEchappe(navalNom(c.modele)) + ' — ' +
       navalNombre(c.jours)+' / '+navalNombre(c.total)+' journées · '+navalEchappe(etat) +
       '<div>'+navHtml('paid',"Payé : {paid} / {total} FR",{paid:navalNombre(c.verse),total:navalNombre(c.prix_total)})+'</div>' +
       navire+'</div>';
    }
  }
  html += '</div>';
  const titre=document.getElementById('postes-modal-title');
  const body=document.getElementById('postes-body');
  const modal=document.getElementById('modal-postes');
  if (!titre || !body || !modal) return;
  titre.textContent=navT('title',"Chantier naval Le Roux — commandes");
  body.innerHTML=html;
  modal.classList.add('open');
}
