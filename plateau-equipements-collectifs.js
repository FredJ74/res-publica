// Equipements collectifs : rendu des faits serveur, aucune mutation d'argent ou d'objet locale.
let RP_EQ_VUE = 0;
function equipementsCollectifsContexte() {
 return {personnage:state.char,nom:state.char?.name,
  uid:typeof rpAuthUid==='function'?rpAuthUid():null,
  session:typeof rpAuthSessionIdentifiant==='function'?rpAuthSessionIdentifiant():null};
}
function equipementsCollectifsContexteValide(c) {
 return state.char===c.personnage&&state.char?.name===c.nom&&
  (typeof rpAuthUid!=='function'||rpAuthUid()===c.uid)&&
  (typeof rpAuthSessionIdentifiant!=='function'||rpAuthSessionIdentifiant()===c.session);
}
async function equipementsCollectifsOuvrir(organisation) {
 if(typeof showToast==='function')showToast('Équipements collectifs indisponibles','Le service serveur n’est pas encore activé. Aucun objet ni paiement n’a été modifié.',false);
 return {ok:false,raison:'service_non_active'};
}

// Un choix de payeur n'apparait que si le contrat d'achat serveur est disponible.
async function equipementsCollectifsProposerPayeur(cible) {
 // Contrats absents en production : aucun choix collectif et aucune requête de sondage.
 if(cible?.replaceChildren)cible.replaceChildren();
 return false;
}

// Une intention d'achat non confirmee conserve sa cle a travers F5/reconnexion.
// Le stockage ne porte aucun solde ; seul le recu serveur tranche l'operation.
function equipementsCollectifsCleAchat(organisation,fonds,reference,quantite,candidate) {
 const uid=typeof rpAuthUid==='function'?rpAuthUid():null;
 if(!uid||!state.char?.name)throw Error('Connexion requise.');
 const cle='rp_achat_collectif:'+JSON.stringify([uid,state.char.name,organisation,fonds,reference,quantite]);
 const ancienne=localStorage.getItem(cle);
 const requete=ancienne||candidate;
 if(typeof requete!=='string'||!/^achat-[A-Za-z0-9-]{6,80}$/.test(requete))throw Error('Identifiant de reprise invalide.');
 localStorage.setItem(cle,requete);
 if(localStorage.getItem(cle)!==requete)throw Error('Reprise de transaction indisponible.');
 return {cle,requete};
}
function equipementsCollectifsAchatConfirme(reprise) {
 if(!reprise)return;
 try{if(localStorage.getItem(reprise.cle)===reprise.requete)localStorage.removeItem(reprise.cle);}catch(_){/* Le rejeu reste sur le recu deja confirme, sans nouveau debit. */}
}
