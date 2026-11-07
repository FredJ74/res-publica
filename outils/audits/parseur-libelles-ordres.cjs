'use strict';
/* Extraction littérale des ordres JS, lecture seule.
 * Contrairement à une regexp arrêtée au premier apostrophe, accepte \'
 * et les échappements Unicode ; ne lance jamais le code du jeu.
 */
const literal=String.raw`(['"])((?:\\.|(?!\1)[^\\\r\n])*)\1`;
const fnThenLabel=new RegExp(String.raw`\\bfn\\s*:\\s*`+literal+String.raw`\\s*,\\s*label\\s*:\\s*`+literal,'g');
const labelThenFn=new RegExp(String.raw`\\blabel\\s*:\\s*`+literal+String.raw`\\s*,\\s*fn\\s*:\\s*`+literal,'g');
function decode(value){
 return value.replace(/\\(?:u\{([0-9a-fA-F]{1,6})\}|u([0-9a-fA-F]{4})|x([0-9a-fA-F]{2})|([\\'"nrtbfv0]))/g,(_,long,short,hex,simple)=>{
  if(long) { const cp=Number.parseInt(long,16);return cp<=0x10ffff?String.fromCodePoint(cp):'�'; }
  if(short||hex)return String.fromCharCode(Number.parseInt(short||hex,16));
  return ({'\\':'\\',"'":"'",'"':'"','n':'\n','r':'\r','t':'\t','b':'\b','f':'\f','v':'\v','0':'\0'})[simple];
 });
}
function extract(source){
 const found=[];
 for(const m of source.matchAll(fnThenLabel))found.push({fn:decode(m[2]),label:decode(m[4])});
 for(const m of source.matchAll(labelThenFn))found.push({fn:decode(m[4]),label:decode(m[2])});
 return found;
}
module.exports={extract,decode};
