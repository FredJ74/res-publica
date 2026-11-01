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

test('le contrôle des ressources emploie sa projection réelle et refuse une sentinelle fausse',()=>{
 const {spawnSync}=require('node:child_process');
 const code=String.raw`
import runpy,json,copy,contextlib,io
m=runpy.run_path('outils/baseline/verifier-referentiels.py',run_name='importe');cfg=json.load(open('outils/baseline/referentiels.json'))['empreintes']['miroirs']['ressources_economie']
h,err=m['empreinte_du_generateur'](cfg['generateur']);assert not err and h==cfg['data_js']==cfg['reelle']
faux=copy.deepcopy(cfg);faux['posee']='0'*16;erreurs=[]
with contextlib.redirect_stdout(io.StringIO()):m['axe_empreintes']({'empreintes':{'miroirs':{'ressources_economie':faux}}},erreurs)
assert any('ressources_economie/posee' in x for x in erreurs),erreurs
`;
 const p=spawnSync('python3',['-c',code],{cwd:require('node:path').resolve(__dirname,'../..'),encoding:'utf8'});assert.equal(p.status,0,p.stderr||p.stdout);
});
