/* Protection de dérive : traduction d'un guide seulement si son texte source
 * français correspond à la version revue. En cas de changement métier,
 * afficher le guide FR plutôt qu'une traduction qui décrirait d'anciennes règles.
 * Hash FNV-1a sur UTF-16, déterministe et sans dépendance réseau.
 */
(function(global){
 'use strict';
 const expected=Object.freeze({
  "tuto": "9354c59c",
  "intro": "d7411672",
  "personnage": "937d3ff3",
  "plateau": "083b085e",
  "politique": "adc8371c",
  "interactions": "9f5399e4",
  "sport": "4893a600",
  "religion": "b7d8641c",
  "economie": "6677017c"
});
 function hash(value){
  const text=String(value);
  let h=0x811c9dc5;
  for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),0x01000193)>>>0;
  return h.toString(16).padStart(8,'0');
 }
 function valid(section,regle){
  if(typeof section!=='string'||!Object.hasOwn(expected,section))return false;
  if(typeof regle?.titre!=='string'||typeof regle?.contenu!=='string')return false;
  return expected[section]===hash(regle.titre+'\u0000'+regle.contenu);
 }
 global.RPGuideIntegrity=Object.freeze({valid,hash});
})(window);
