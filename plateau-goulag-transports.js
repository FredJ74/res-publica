/* Goulag Sovarka : accès depuis les centres multimodaux et autorisations.
 * Les refus, rôles, paiements et destinations sont exclusivement serveur.
 */
(function(){
 'use strict';
 const dire=(titre,texte,ok=false)=>{
   if(typeof showToast==='function')showToast(titre,texte,ok);
 };
 const rpc=async(fn,args)=>{
   if(typeof sbRpcVerdict!=='function')return {ok:false,raison:'serveur_indisponible'};
   try{return await sbRpcVerdict(fn,args);}catch(_){return {ok:false,raison:'connexion_impossible'};}
 };
 const mode=()=>{
   const reponse=window.prompt('Transport pour le goulag : 1 — Train / 2 — Bus', '1');
   if(reponse===null)return null;
   return reponse.trim()==='1'?'train':reponse.trim()==='2'?'bus':null;
 };
 let occupe=false;
 async function demander(){
   if(occupe)return;
   occupe=true;
   try{const res=await rpc('sovarka_goulag_visite_demander',{});
     dire(res.ok?'Demande déposée':'Demande refusée',
       res.ok?'Votre demande est transmise au ministre de la Justice.':res.raison||'Refus serveur',res.ok);
   }finally{occupe=false;}
 }
 async function voyager(){
   if(occupe)return;
   const choisi=mode();if(!choisi)return;
   if(!window.confirm('Confirmer votre voyage vers le goulag de Sovarka ?'))return;
   occupe=true;
   try{
     const res=await rpc('sovarka_goulag_voyager',{p_mode:choisi});
     dire(res.ok?'Arrivée au goulag':'Voyage refusé',res.ok?'Vous êtes à l’entrée du goulag.':res.raison||'Refus serveur',res.ok);
     if(res.ok){if(typeof sbLoadPersonnage==='function')await sbLoadPersonnage();if(typeof updateUI==='function')updateUI();}
   }finally{occupe=false;}
 }
 async function retour(){
   if(occupe)return;
   const choisi=mode();if(!choisi)return;
   occupe=true;
   try{
     const res=await rpc('sovarka_goulag_visiteur_repartir',{p_mode:choisi,p_destination:null});
     dire(res.ok?'Retour confirmé':'Retour refusé',res.ok?'Vous êtes arrivé au centre multimodal.':res.raison||'Refus serveur',res.ok);
     if(res.ok){if(typeof sbLoadPersonnage==='function')await sbLoadPersonnage();if(typeof updateUI==='function')updateUI();}
   }finally{occupe=false;}
 }
 async function ministre(){
   if(occupe)return;
   occupe=true;
   try{
     const res=await rpc('sovarka_goulag_visite_lire',{});
     if(!res.ok||!res.ministre){dire('Accès refusé',res.raison||'Réservé au ministre de la Justice');return;}
     const demandes=(res.demandes||[]).filter(x=>x.etat==='demandee');
     if(!demandes.length){dire('Demandes de visite','Aucune demande en attente.',true);return;}
     const textes=demandes.map((x,i)=>(i+1)+' — '+x.nom).join('\n');
     const index=Number(window.prompt('Demandes de visite au goulag :\n'+textes+'\n\nNuméro de la demande à traiter :','1'));
     if(!Number.isSafeInteger(index)||index<1||index>demandes.length)return;
     const oui=window.confirm('Accorder l’autorisation de visite à '+demandes[index-1].nom+' ? Annuler = refuser.');
     const decision=oui?'accorder':'refuser';
     const verdict=await rpc('sovarka_goulag_visite_decider',{p_id:demandes[index-1].id,p_decision:decision});
     dire(verdict.ok?'Décision enregistrée':'Décision refusée',verdict.ok?'La décision est conservée au serveur.':verdict.raison||'Refus serveur',verdict.ok);
   }finally{occupe=false;}
 }
 function ordresGoulagTransport(batiment,piece,ville){
   if(typeof state==='undefined'||state.country!=='soviet')return [];
   if(['capitale','ville_a','ville_b'].includes(ville)&&typeof batiment==='string'
       &&batiment.startsWith('centre-multinodal-')){
      return [
        {fn:'goulag_visite_demander',label:'Demander une autorisation pour le goulag',pa:0,cost:0,type:'legal',icon:'ti-mail',
         desc:'Demander au ministre de la Justice un accès personnel au goulag.'},
        {fn:'goulag_voyager',label:'Voyage vers le goulag',pa:0,cost:0,type:'legal',icon:'ti-train',
         desc:'Train ou bus vers le goulag, réservé aux dignitaires habilités ou visiteurs autorisés.'}
      ];
   }
   if(ville==='capitale'&&batiment==='palais-gouvernement'&&piece==='bureau_min_just'){
     return [{fn:'goulag_autorisations_gerer',label:'Autorisations de visite du goulag',pa:0,cost:0,
       type:'legal',icon:'ti-id-badge',requiresPost:'min_just',
       desc:'Approuver ou refuser les demandes de visite, sans pouvoir condamner un dissident.'}];
   }
   if(ville==='qhs'&&batiment==='qhs-prison'&&piece==='entree_qhs'){
     return [{fn:'goulag_visiteur_retour',label:'Retour du visiteur vers la ville',pa:0,cost:0,
       type:'legal',icon:'ti-train',
       desc:'Retour par transport régulier réservé au visiteur non détenu.'}];
   }
   return [];
 }
 window.RP_ORDRES_DYNAMIQUES=window.RP_ORDRES_DYNAMIQUES||[];
 window.RP_ORDRES_DYNAMIQUES.push(ordresGoulagTransport);
 window.goulagAutorisationDemander=demander;
 window.goulagVoyager=voyager;
 window.goulagVisiteurRetour=retour;
 window.goulagAutorisationsGerer=ministre;
})();
