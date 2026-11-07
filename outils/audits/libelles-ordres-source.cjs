'use strict';
/* Extraction non autoritaire des libellés littéraux JS :
 * les apostrophes échappées ne doivent pas tronquer le catalogue d'audit.
 * Aucun eval, aucune logique de jeu exécutée.
 */
function decode(raw){
 return raw.replace(/\\u([0-9a-fA-F]{4})/g,(_,hex)=>String.fromCharCode(parseInt(hex,16)))
  .replace(/\\x([0-9a-fA-F]{2})/g,(_,hex)=>String.fromCharCode(parseInt(hex,16)))
  .replace(/\\(['"\\])/g,'$1')
  .replace(/\\n/g,'\n').replace(/\\t/g,'\t').replace(/\\r/g,'\r');
}
const fnFirst=/\bfn\s*:\s*(['"])((?:\\.|(?!\1)[^\\\n])*)\1\s*,\s*label\s*:\s*(['"])((?:\\.|(?!\3)[^\\\n])*)\3/g;
const labelFirst=/\blabel\s*:\s*(['"])((?:\\.|(?!\1)[^\\\n])*)\1\s*,\s*fn\s*:\s*(['"])((?:\\.|(?!\3)[^\\\n])*)\3/g;
function extract(text){
 const found=[];
 for(const row of String(text).matchAll(fnFirst))
  found.push({fn:decode(row[2]),label:decode(row[4])});
 for(const row of String(text).matchAll(labelFirst))
  found.push({fn:decode(row[4]),label:decode(row[2])});
 return found;
}
module.exports={extract,decode};
