/* Choix du libellé traduit des ordres, sans modifier fn, PA, argent ni accès.
 * Ne jamais traduire automatiquement un fn ambigu : le contexte détermine le texte
 * et parfois le prix affiché. Ordres non couverts = français d'origine.
 */
(function(global){
 'use strict';
 const ambiguities=new Set([
  'louer_local','gerer_local','produire_commerce','vendre_matiere_commerce',
  'acheter_terrain','reserver_chambre_hotel','ecouter_rumeurs','consulter_carte_commerce',
  'conference_presse','propagande_etat','dementi','gerer_finances',
  'archives_police','repartition_budget_local','prier','faire_don',
  'corrompre_fonctionnaire_permis','corrompre_fonct',
  'expedier_colis','receptionner_commande'
 ]);
 const validKey=/^[a-zA-Z0-9_.-]+$/;
 function label(order,engine,locale) {
  const original=typeof order?.label==='string'?order.label:'';
  if(!order || !engine || typeof engine.t!=='function')return original;
  const code=typeof order.fn==='string'?order.fn:'';
  let key=null;
  if(typeof order.i18nKey==='string' && validKey.test(order.i18nKey))
   key='orders.'+order.i18nKey;
  else if(validKey.test(code) && !ambiguities.has(code))key='orders.'+code;
  if(!key)return original;
  const value=engine.t(key,{lng:locale,defaultValue:original});
  return typeof value==='string'&&value.length?value:original;
 }
 global.RPOrderI18n=Object.freeze({label,ambiguous:(fn)=>ambiguities.has(fn)});
})(window);
