/* Choix du libellé traduit des ordres, sans modifier fn, PA, argent ni accès.
 * Ne jamais traduire automatiquement un fn ambigu : le contexte détermine le texte
 * et parfois le prix affiché. Ordres non couverts = français d'origine.
 */
(function(global){
 'use strict';
 const ambiguities=new Set([
  'louer_local','gerer_local','produire_commerce','vendre_matiere_commerce',
  'acheter_terrain','sovarka_reunion_reserver','reserver_chambre_hotel','ecouter_rumeurs','consulter_carte_commerce',
  'conference_presse','propagande_etat','dementi','gerer_finances',
  'archives_police','repartition_budget_local','prier','faire_don',
  'corrompre_fonctionnaire_permis','corrompre_fonct',
  'expedier_colis','receptionner_commande'
 ]);
 const validKey=/^[a-zA-Z0-9_.-]+$/;
 // Une même commande joue des cérémonies réellement différentes selon l'empire.
 // Ne jamais traduire par fn seul : correspondance stricte avec le libellé
 // canonique du serveur, sans modifier l'ordre ni créer de nouvel effet.
 const exactVariants=Object.freeze({
  prier:Object.freeze({
   'Prier le Formulaire Sacré':'religion_formulaire',
   'Communier avec la Feuille':'religion_feuille',
   "Chanter l'hymne au Tracteur":'religion_tracteur',
   'Communier avec le Loukoum':'religion_loukoum'
  }),
  faire_don:Object.freeze({
   "Faire un don a l'Eglise":'don_eglise',
   'Faire une offrande':'don_offrande',
   'Donner au Kolkhoze':'don_kolkhoze',
   'Offrir des loukoums':'don_loukoums'
  }),
  propagande_etat:Object.freeze({
   "Propagande d'Etat":'politics_propaganda_state',
   'Campagne de propagande':'politics_propaganda_campaign'
  }),
  dementi:Object.freeze({
   'Dementi officiel':'politics_denial_plain',
   'Démenti officiel':'politics_denial_accent'
  }),
  archives_police:Object.freeze({
   'Consulter les archives':'police_archives',
   'Consulter le registre':'police_register'
  }),
  repartition_budget_local:Object.freeze({
   'Repartir le budget municipal':'budget_plain',
   'Répartir le budget municipal':'budget_accent'
  }),
  receptionner_commande:Object.freeze({
   'Réceptionner une caisse':'shipment_receive_crate',
   'Réceptionner une commande':'shipment_receive_order'
  }),
  expedier_colis:Object.freeze({
   'Réserver une caisse de fret':'shipment_book_crate',
   'Expédier un colis':'shipment_send_parcel'
  }),
  corrompre_fonctionnaire_permis:Object.freeze({
   'Corrompre un fonctionnaire (accélérer)':'permit_bribe_general',
   'Corrompre un fonctionnaire (accélérer le permis)':'permit_bribe_permit'
  }),
  corrompre_fonct:Object.freeze({
   'Corrompre le directeur':'corruption_director',
   'Falsifier un proces-verbal':'corruption_false_report'
  })
 });
 function cultLabel(code,original,engine,locale){
  const variant=exactVariants[code]?.[original];
  if(!variant)return original;
  const translated=engine.t('orderVariants.'+variant,{lng:locale,defaultValue:original});
  return typeof translated==='string'&&translated.trim() ? translated : original;
 }
 // Les libellés à prix variables n'utilisent pas une traduction par fn.
 // Seules des formes françaises exactes et des montants déjà présents dans
 // l'ordre sont interpolés, sans aucun calcul ni conversion monétaire.
 function structuredLabel(code,original,engine,locale){
  let key=null,vars={};
  if(code==='louer_local'){
   const match=/^Louer (ce local|cette suite|ce coffre|cet appartement) \((\d[\d ]*) (FR|PSK)\/jour\)$/.exec(original);
   if(!match)return original;
   const types={'ce local':'rental_local','cette suite':'rental_suite',
    'ce coffre':'rental_safe','cet appartement':'rental_apartment'};
   key=types[match[1]];
   vars={price:match[2],currency:match[3]};
  }else if(code==='sovarka_reunion_reserver'){
   // Les tarifs 100/150 PSK proviennent exclusivement du libellé métier :
   // l'internationalisation ne calcule ni ne modifie le prix.
   const match=/^Réserver pour aujourd’hui — (\d+) PSK$/.exec(original);
   if(!match)return original;
   key='sovarka_meeting_today';
   vars={price:match[1]};
  }else if(code==='acheter_terrain'){
   if(original==='Acheter ce terrain')key='buy_plot_plain';
   else{
    const match=/^Acheter ce terrain \((\d[\d ]*) m² — (\d[\d ]*) FR\)$/.exec(original);
    if(!match)return original;
    key='buy_plot';
    vars={area:match[1],price:match[2]};
   }
  }else return original;
  if(!key)return original;
  const translated=engine.t('orderTemplates.'+key,{lng:locale,defaultValue:original,...vars});
  // Si un moteur simulé ou un catalogue absent laisse les marqueurs bruts,
  // ne pas afficher de prix incomplet : repli exact sur le texte français.
  return typeof translated==='string' && translated.trim() &&
   !/\{\{[^}]+\}\}/.test(translated)?translated:original;
 }

 function label(order,engine,locale) {
  const original=typeof order?.label==='string'?order.label:'';
  if(!order || !engine || typeof engine.t!=='function')return original;
  const code=typeof order.fn==='string'?order.fn:'';
  let key=null;
  if(typeof order.i18nKey==='string' && validKey.test(order.i18nKey)) {
   // Variantes avec un même fn : clé explicite et catalogue séparé pour
   // ne jamais compter une variante comme une commande serveur différente.
   key=order.i18nKey.startsWith('variant.')
    ? 'orderVariants.'+order.i18nKey.slice('variant.'.length)
    : 'orders.'+order.i18nKey;
  }
  else if(validKey.test(code) && !ambiguities.has(code))key='orders.'+code;
  if(!key)return exactVariants[code]
   ? cultLabel(code,original,engine,locale)
   : structuredLabel(code,original,engine,locale);
  // Un même fn peut changer de sens ou de prix selon la pièce / le fournisseur.
  // Pour une traduction par ID implicite, accepter uniquement le libellé
  // de référence réellement catalogué en français. Un i18nKey explicite
  // porte sa propre variante et peut être affiché même pour les cas ambigus.
  if(!order.i18nKey) {
    const reference=engine.t(key,{lng:'fr',defaultValue:null});
    if(typeof reference!=='string' || reference!==original)return original;
  }
  const value=engine.t(key,{lng:locale,defaultValue:original});
  return typeof value==='string'&&value.length?value:original;
 }
 // Appelé uniquement pour les contenus des boutons en HTML. Les actions, les coûts
 // et les libellés originaux transmis aux handlers conservent la valeur de o.label.
 // L'échappement s'applique exclusivement aux traductions injectées dans innerHTML.
 function labelHtml(order,engine,locale) {
  const original=typeof order?.label==='string'?order.label:'';
  const translated=label(order,engine,locale);
  if(translated===original)return original;
  return translated.replace(/[&<>"']/g,char=>({
   '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  })[char]);
 }
 global.RPOrderI18n=Object.freeze({label,labelHtml,ambiguous:(fn)=>ambiguities.has(fn)});
})(window);
