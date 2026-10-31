'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {extraire}=require('../generateurs/extraire-ordres-modules.cjs');
test('le coût déclaré reste trouvé quand fn suit les montants et utilise une constante',()=>{
 const r=extraire("const PA=1;deduireCoutOrdre({pa:PA,cost:0,fn:'gerer_commandement'});");
 assert.deepEqual(r.litteraux.map(({fn,pa,cost})=>({fn,pa,cost})),[{fn:'gerer_commandement',pa:1,cost:0}]);
});
test('une expression inconnue ne devient jamais un coût gratuit',()=>{
 const r=extraire("const ordre={fn:'soins',label:'Soin',pa:coutVariable,cost:0};");
 assert.equal(r.litteraux.length,0);assert.equal(r.dynamiques[0].fn,'soins');
});
test('le vrai achat après ouverture du catalogue conserve ses PA et son prix',()=>{
 const r=extraire("function achat(){const prix=600;acheterObjetServeur('acheter_gilet','gilet',1,prix);}function autre(){const prix=400;acheterObjetServeur('acheter_parapluie','poison',0,prix);}");
 assert.deepEqual(r.litteraux.map(({fn,pa,cost})=>({fn,pa,cost})),[{fn:'acheter_gilet',pa:1,cost:600},{fn:'acheter_parapluie',pa:0,cost:400}]);
});
test('une mention ou une action de messagerie ne devient pas un ordre payable',()=>{
 const r=extraire("// {fn:'faux',label:'Faux',pa:2,cost:99}\nconst mail={fn:'accepterInvitationOrga',label:'Accepter'};const texte=\"{fn:'faux',label:'Faux',pa:2,cost:99}\";");
 assert.equal(r.litteraux.length,0);
});
