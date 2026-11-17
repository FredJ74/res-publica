/* Refuge après la traversée du goulag.
 * Nuitée et débit du bois uniquement confirmés par le serveur.
 */
(function () {
  'use strict';
  let actif = false;
  let refugeCourant = null;
  async function requete(action,args={}) {
    if (typeof sbRpcVerdict !== 'function') return {ok:false,raison:'serveur_indisponible'};
    try { return await sbRpcVerdict(action,args); }
    catch (_) { return {ok:false,raison:'connexion_impossible'}; }
  }
  function avertir(titre,texte,ok) {
    if(typeof showToast==='function') showToast(titre,texte,ok);
  }
  async function lire() {
    const reponse=await requete('sovarka_goulag_refuge_lire');
    if(!reponse.ok) { refugeCourant=null; return null; }
    refugeCourant=reponse;
    return reponse;
  }
  async function rejoindre() {
    if(actif)return;
    actif=true;
    try {
      const info=await lire();
      if(!info || info.termine)return;
      if(info.nuits!==0)return;
      if(!window.confirm('Vous êtes épuisé après la toundra. Rejoindre l’habitant qui vous recueillera pendant trois jours ?'))return;
      const res=await requete('sovarka_goulag_refuge_rejoindre');
      if(!res.ok){avertir('Accueil refusé',res.raison||'Position non confirmée.',false);return;}
      avertir('Refuge trouvé','L’habitant vous ouvre. Première nuit : 5 unités de bois ; deuxième nuit : 3.',true);
      if(typeof sbLoadPersonnage==='function')await sbLoadPersonnage();
      if(typeof updateUI==='function')updateUI();
    } finally {actif=false;}
  }
  async function nuit() {
    if(actif) return;
    actif=true;
    try {
      const info=await lire();
      if(!info || info.termine){avertir('Refuge indisponible','Aucune récupération en cours.',false);return;}
      if(info.nuits >= 2){avertir('Deux nuits effectuées','Votre deuxième nuit a déjà été enregistrée.',false);return;}
      const cout=info.bois_prochain;
      if(!Number.isInteger(cout)||cout<=0){avertir('Nuit indisponible','Le serveur ne confirme pas le bois dû.',false);return;}
      if(!window.confirm((cout===8?'Régler les deux nuits écoulées (5 puis 3 bois)':'Passer la '+(info.nuits===0?'première':'deuxième')+' nuit chez l’habitant')+' : '+cout+' unités de bois. Confirmer ?')) return;
      const r=await requete('sovarka_goulag_refuge_nuit',{p_max_bois:cout});
      if(!r.ok){avertir('Nuit refusée',r.raison||'Refus serveur',false);return;}
      if (r.inventory && typeof sbAdopterInventaireServeur==='function')
        sbAdopterInventaireServeur(r);
      avertir('Bois remis',(r.paiements?.length>1?'Deux nuits réglées : '+r.paiements.map(p=>p.bois).join(' puis ')+' unités de bois.':r.bois_preleves+' unités de bois remises à votre hôte.')+' Restez au repos.',true);
      if(typeof sbLoadPersonnage==='function') await sbLoadPersonnage();
      if(typeof updateUI==='function') updateUI();
    }finally{actif=false;}
  }
  async function terminer() {
    if(actif)return;
    actif=true;
    try {
      const info=await lire();
      if(!info)return;
      const cout=info.bois_prochain||0;
      if(cout>0&&!window.confirm('Régler les nuits dues ('+cout+' bois) et terminer la récupération si les trois jours sont écoulés ?'))return;
      const r=await requete('sovarka_goulag_refuge_terminer',{p_max_bois:cout});
      if(r.ok && r.inventory && typeof sbAdopterInventaireServeur==='function')sbAdopterInventaireServeur(r);
      avertir(r.ok?'Repos terminé':'Repos en cours',
        r.ok?'Votre récupération est terminée.':r.raison||'Les trois jours ou les deux nuits ne sont pas terminés.',r.ok);
      if(r.ok)refugeCourant={...info,termine:true};
      if(r.ok && typeof sbLoadPersonnage==='function')await sbLoadPersonnage();
      if(r.ok && typeof updateUI==='function')updateUI();
    }finally{actif=false;}
  }
  function ordresRefuge(batiment,piece,ville){
    if(!refugeCourant || refugeCourant.termine || typeof state==='undefined' || state.country!=='soviet' || piece!=='piece_maison')return [];
    if ((ville==='ville_a' && batiment==='maison-starovka')
      || (ville==='ville_b' && batiment==='maison-krasnov')){
      return [
       {fn:'goulag_refuge_nuit',label:'Nuit de refuge (bois)',pa:0,cost:0,type:'legal',
        icon:'ti-moon',successRate:100,desc:'Première nuit : 5 bois. Deuxième nuit : 3 bois. Réservé à la récupération après la toundra.'},
       {fn:'goulag_refuge_terminer',label:'Achever la convalescence',pa:0,cost:0,type:'legal',
        icon:'ti-check',successRate:100,desc:'Après trois jours de repos et deux nuits auprès de l’habitant.'}
      ];
    }
    return [];
  }
  window.RP_ORDRES_DYNAMIQUES=window.RP_ORDRES_DYNAMIQUES||[];
  window.RP_ORDRES_DYNAMIQUES.push(ordresRefuge);
  window.goulagRefugeRejoindre=rejoindre;
  window.goulagRefugeNuit=nuit;
  window.goulagRefugeTerminer=terminer;
  window.goulagRefugeLire=lire;
  // Reprise de session, sans état d'arrivée inventé par le navigateur.
  document.addEventListener('DOMContentLoaded',()=>{
    let essais=0;
    const intervalle=window.setInterval(async()=>{
      essais++;
      if(typeof state!=='undefined' && state.personnageChargeDepuisServeur===true){
        window.clearInterval(intervalle);
        if(state.country==='soviet'
          && (state.currentCity==='ville_a'||state.currentCity==='ville_b')){
          const r=await lire();
          if(r && !r.termine){
            if(!state.currentBuilding && r.nuits===0)await rejoindre();
            else if(typeof updateUI==='function')updateUI();
          }
        }
      }else if(essais>=20)window.clearInterval(intervalle);
    },1500);
  });
})();
