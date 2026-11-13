// Configuration de présentation uniquement ; aucune donnée d'ordre ou de pays n'est créée.
// Un nouveau catalogue ajoute une déclaration et son fichier de ressources, jamais une branche moteur.
(function(global){
 'use strict';
 global.RP_ORDER_DESCRIPTION_CATALOGUES=[
  {id:'common',shared:true,rows:global.RP_INFOBULLES_COMMUNES,keys:{
   'orders.description.common.bar-menu':'Voir ce qui est disponible au bar et commander.'
  }},
  {id:'republic',countries:['republic'],rows:global.RP_INFOBULLES_REPUBLIA},
  {id:'soviet',countries:['soviet'],builtin:true}
 ];
})(window);
