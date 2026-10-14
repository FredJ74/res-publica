// Planificateur pur des cours universitaires. Aucune ecriture client ne valide un cours.
// Le serveur doit recalculer les memes echeances et les verrouiller transactionnellement.
(function(root){'use strict';
const JOUR=86400000;
// 1re semaine : lundi/mercredi/vendredi ; semaines 2 a 8 : lundi/mercredi et stage jeudi.
function modules(){const items=[];let numero=0;for(let semaine=1;semaine<=8;semaine++){
 const jours=semaine===1?[0,2,4]:[0,2];
 for(const jour of jours)items.push(Object.freeze({id:'cours_'+String(++numero).padStart(2,'0'),semaine,genre:'cours',jourOffset:(semaine-1)*7+jour,pa:6}));
 if(semaine>1)items.push(Object.freeze({id:'stage_'+String(semaine).padStart(2,'0'),semaine,genre:'stage',jourOffset:(semaine-1)*7+3,pa:0}));
}return Object.freeze(items);}
const PROGRAMME=modules();
function prochaineEcheance(debut,validations){
 const start=new Date(debut);if(!Number.isFinite(start.getTime()))throw new Error('debut invalide');
 const faits=validations||{};let decalage=0;let precedent=null;
 for(const module of PROGRAMME){
  const planifie=new Date(start.getTime()+(module.jourOffset+decalage)*JOUR);
  const dateValidation=faits[module.id]?new Date(faits[module.id]):null;
  if(dateValidation&&(!Number.isFinite(dateValidation.getTime())||dateValidation<planifie))throw new Error('validation incoherente');
  if(!dateValidation)return {module,ouvreLe:planifie.toISOString(),decalageJours:decalage};
  // Toute validation tardive decale les echeances suivantes du retard effectif.
  const retard=Math.max(0,Math.ceil((dateValidation.getTime()-planifie.getTime())/JOUR));
  decalage+=retard;precedent=module;
 }
 return {termine:true,dernier:precedent,decalageJours:decalage};
}
const api=Object.freeze({PROGRAMME,prochaineEcheance});if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.UNIVERSITE_CALENDRIER=api;
})(typeof globalThis!=='undefined'?globalThis:this);
