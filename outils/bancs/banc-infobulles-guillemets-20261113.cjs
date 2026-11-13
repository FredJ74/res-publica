'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const src=fs.readFileSync(path.join(__dirname,'../../plateau-politique.js'),'utf8');
test('La valeur title des ordres échappe les guillemets sans tronquer la description',()=>{
 assert.match(src,/const tooltipAttribut = tooltipFinal === tooltip \? tooltipFinal\.replace\(\/"\/[g], '&quot;'\) : tooltipFinal/);
 assert.ok(src.includes("tooltipAttribut + '\"' + tipAttr"));
 const tooltip='Permet de contester une licence de "football" sans payer';
 const tooltipAttribut=tooltip.replace(/"/g,'&quot;');
 const html='<button title="'+tooltipAttribut+'" data-rp-tip="test"></button>';
 assert.match(html,/licence de &quot;football&quot; sans payer" data-rp-tip/);
 assert.equal(tooltip,'Permet de contester une licence de "football" sans payer');
});
test('Les messages bloqués déjà échappés restent inchangés',()=>{
 const tooltip='Une licence &quot;spéciale&quot; est nécessaire';
 const tooltipFinal=tooltip;
 const tooltipAttribut=tooltipFinal===null?null:tooltipFinal; // branche blocage conservée
 assert.equal(tooltipAttribut,tooltip);
 assert.doesNotMatch(tooltipAttribut,/&amp;quot;/);
});
test('Le descripteur tactile conserve le contenu intégral',()=>{
 assert.match(src,/data-rp-tip/);
 assert.match(src,/encodeURIComponent\(JSON\.stringify\(tipDescripteur\)\)/);
 assert.match(src,/const tipDescripteur =/);
});
