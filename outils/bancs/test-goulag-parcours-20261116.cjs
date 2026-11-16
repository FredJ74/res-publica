'use strict';
const t=require('node:test'),a=require('node:assert/strict');
const g=require('../../api/_goulag-parcours.js');
const rejet=(f,code)=>a.throws(f,e=>e instanceof g.RefusParcours&&e.code===code);
t.test('seul juge sovarkien, jugement QHS réel validé',()=>{
 const j={country:'soviet',poste:'juge',nom:'Juge',titulaireConfirmeServeur:true};
 const d={country:'soviet',accuse:'Dissident',juge:'Juge',genre:'qhs',verdict:'condamnation',jours:7,affaireValideeServeur:true,id:'jug-1'};
 a.equal(g.verifierCondamnation({juge:j,cible:'Dissident',jugement:d}).destination,'qhs');
 for(const poste of ['min_just','chef_gouv','commissaire']) rejet(()=>g.verifierCondamnation({juge:{...j,poste},cible:'Dissident',jugement:d}),'reserve_juge_sovarka');
 rejet(()=>g.verifierCondamnation({juge:{...j,country:'republic'},cible:'Dissident',jugement:d}),'reserve_juge_sovarka');
 rejet(()=>g.verifierCondamnation({juge:j,cible:'Autre',jugement:d}),'condamnation_invalide');
 rejet(()=>g.verifierCondamnation({juge:j,cible:'Dissident',jugement:{...d,affaireValideeServeur:false}}),'condamnation_invalide');
});
t.test('transport nominatif et pays du poste, détenu bloqué',()=>{
 const p={country:'soviet',city:'ville_a',nom:'PJ',dansCentreMultimodalServeur:true,poste:'juge',postePays:'soviet',posteVerifieServeur:true};
 a.equal(g.verifierVoyage({acteur:p,destination:'qhs'}).piece,'entree_qhs');
 rejet(()=>g.verifierVoyage({acteur:{...p,detenu:true},destination:'qhs'}),'detenu_transport_interdit');
 rejet(()=>g.verifierVoyage({acteur:{...p,postePays:'republic'},destination:'qhs'}),'autorisation_goulag_requise');
 const habilitation={etat:'accordee',personnage:'PJ',pays:'soviet',signeeParMinistreServeur:true,valideServeur:true};
 a.equal(g.verifierVoyage({acteur:{...p,poste:'aucun'},destination:'qhs',habilitation}).ville,'qhs');
 rejet(()=>g.verifierVoyage({acteur:{...p,poste:'aucun'},destination:'qhs',habilitation:{...habilitation,personnage:'Autre'}}),'autorisation_goulag_requise');
});
t.test('confiscation, clés conservées, restitution idempotente, perte irréversible',()=>{
 const source=[{id:'cle-maison',stackKey:'cle'},{id:'pomme',stackKey:'pomme',qty:9},{id:'unique',meta:{x:1}}];
 const depot=g.confisquer({inventaire:source,isCle:o=>o.stackKey==='cle',detentionId:'det-1'});
 a.deepEqual(depot.conserve,[source[0]]);a.deepEqual(depot.depot,source.slice(1));
 source[1].qty=1;
 a.equal(depot.depot[0].qty,9);
 const liber=g.cloreDepot(depot,'liberation');a.equal(liber.etatDepot,'restitue');a.equal(liber.aRestituer[0].qty,9);
 a.deepEqual(g.cloreDepot({...depot,etatDepot:'restitue'},'liberation').aRestituer,[]);
 rejet(()=>g.cloreDepot({...depot,etatDepot:'perdu'},'liberation'),'depot_deja_clos');
 a.deepEqual(g.cloreDepot(depot,'evasion').aRestituer,[]);
});
t.test('parcours visiteur et détenu, destination géographique, PA et peine',()=>{
 for(const dest of ['starovka','krasnov']){
   const minimum=g.ENTREE[dest].minimumPA;
   rejet(()=>g.debuterMarche({destination:dest,statut:'detenu',pa:minimum-1,presenceServeur:true,peineRestante:3}),'pa_insuffisants_depart');
   const visiteur=g.debuterMarche({destination:dest,statut:'visiteur',pa:minimum,presenceServeur:true});
   a.equal(visiteur.pa,minimum);a.equal(visiteur.peineGelee,null);a.equal(visiteur.recherche,false);
   const detenu=g.debuterMarche({destination:dest,statut:'detenu',pa:minimum,presenceServeur:true,peineRestante:.25});
   a.equal(detenu.peineGelee,.25);a.equal(detenu.recherche,true);
   const donnees={...detenu,progressions:g.ENTREE[dest].progressions};
   // Le camp est désormais un nœud réel ; une valeur cliente ne le remplace pas.
   a.equal(g.arriver({marche:donnees,paApresProgression:3,noeudKrasnovVerifie:'faux-noeud'}).rue,g.ENTREE[dest].noeud);
   const arrivee=g.arriver({marche:donnees,paApresProgression:3,noeudKrasnovVerifie:'krasnov-camp-reel'});
   a.equal(arrivee.pa,1);a.equal(arrivee.reposForceJours,3);
   a.equal(arrivee.ville,g.ENTREE[dest].ville);
   a.equal(arrivee.recherche,true);
   a.equal(g.arriver({marche:{...visiteur,progressions:g.ENTREE[dest].progressions},paApresProgression:2,noeudKrasnovVerifie:'krasnov-camp-reel'}).recherche,false);
 }
});
t.test('refuge : 5 et 3 bois, deux nuits maximum, aucun doublon',()=>{
 const init={nuits:0,dernierJour:0};
 rejet(()=>g.heberger({refuge:init,nuit:1,bois:4}),'bois_insuffisant');
 const n1=g.heberger({refuge:init,nuit:1,bois:8});a.equal(n1.boisRestant,3);
 rejet(()=>g.heberger({refuge:{nuits:1,dernierJour:1},nuit:1,bois:8}),'nuit_deja_prise');
 const n2=g.heberger({refuge:{nuits:1,dernierJour:1},nuit:2,bois:3});
 a.equal(n2.boisRestant,0);a.equal(n2.nuits,2);
 rejet(()=>g.heberger({refuge:{nuits:2,dernierJour:2},nuit:3,bois:10}),'nuit_deja_prise');
});
t.test('pas de taux d arrestation ni pénalité de champignons inventés',()=>{
 for(const action of ['penalite_champignons','arrestation_hotel_hopital','autorisation_validite'])
 rejet(()=>g.regleNonArbitree(action),'arbitrage_game_designer_requis');
});
