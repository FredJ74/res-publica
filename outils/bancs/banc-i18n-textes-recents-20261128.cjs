'use strict';
// 28/11/2026 : relecture des listes Pour Codex, sans RPC ni personnage connecté.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const langs=['fr','en','es','zh-TW','ru','ko','ar','pt-BR','de'];
function table(f){const s=read(f),a=s.indexOf('const T = {'),b=s.indexOf('\n  };',a),c={};assert.ok(a>=0&&b>a,f);vm.runInNewContext(s.slice(a,b+5)+';this.T=T;',c);return JSON.parse(JSON.stringify(c.T));}
const leaves=(v,p='',out={})=>{for(const [k,x]of Object.entries(v||{}))typeof x==='string'?out[p+k]=x:leaves(x,p+k+'.',out);return out;};
const vars=s=>(s.match(/\{\w+\}/g)||[]).sort();
const reference=JSON.parse(read('outils/audits/i18n/FRANCAIS-REFERENCE-20261128.json'));
for(const [file,fr]of Object.entries(reference.tables))test(file+' : français exact, neuf langues et variables',()=>{
 const T=table(file);assert.deepEqual(T.fr,fr);
 for(const l of langs){assert.ok(T[l],file+' '+l);const m=leaves(T[l]);for(const [k,s]of Object.entries(leaves(fr))){assert.ok(m[k]?.trim(),l+' '+k);assert.deepEqual(vars(m[k]),vars(s),l+' '+k);for(const cur of ['FR','PSK','DR'])if(new RegExp('\\b'+cur+'\\b').test(s))assert.match(m[k],new RegExp('\\b'+cur+'\\b'));}}
});
function setup(){const c={RP_I18N_GAME_ENABLED:true,lang:'fr',RPPlateauI18n:{language:()=>c.lang},RPI18n:{language:'fr'}};c.window=c;vm.createContext(c);vm.runInContext('var state={country:"narco",currentCity:"capitale",pa:12,money:320,room:"accueil",draft:"Texte conservé"};',c);for(const f of ['i18n/infobulles-communes-resources.js','i18n/republia-infobulles-resources.js','i18n/sovarka-infobulles-resources.js','plateau-teaser-traductions.js','plateau-criminalite.js'])vm.runInContext(read(f),c,{filename:f});return c;}
test('capitales : 9 pièces, 3 bâtiments, 17 rôles, 14 descriptions ; noms propres et monnaies inchangés',()=>{
 const c=setup(),{PIECES,BATIMENTS,ROLES,DESCRIPTIONS}=c.RPTeaserCapitalesI18n.tables;
 // Décompte réel relu le 28/11 : les 13 ordres des hôtels et le billet aux douanes = 14 textes distincts.
 assert.equal(Object.keys(PIECES).length,9);assert.equal(Object.keys(BATIMENTS).length,3);assert.equal(Object.keys(ROLES).length,17);assert.equal(DESCRIPTIONS.length,14);
 for(const t of [PIECES,BATIMENTS,ROLES])for(const [fr,m]of Object.entries(t)){assert.equal(m.fr,fr);for(const l of langs)assert.ok(m[l]?.trim(),l+' '+fr);}
 for(const [fr,m]of Object.entries(BATIMENTS))for(const l of langs)for(const name of ['Al-Khalija','Al Madina','Ciudad Roja'])if(fr.includes(name))assert.ok(m[l].includes(name),l+' '+name);
 const order=['fr','en','es','de','ru','ko','ar','pt-BR','zh-TW'];for(const d of DESCRIPTIONS){assert.equal(d.length,9);for(let i=1;i<9;i++){assert.deepEqual(vars(d[i]),vars(d[0]));for(const name of ['Tito Maletas','Roxane Velours','Nabil Naana','PS','DR'])if(d[0].includes(name))assert.ok(d[i].includes(name),order[i]+' '+name);}}
});
test('ancien et nouveau refus : trois objets, neuf langues, aucune action ni modification de l’état',()=>{
 const c=setup(),before=JSON.stringify(c.state);c.sbRpc=()=>{throw Error('RPC inattendue');};
 for(const l of langs){c.lang=l;c.RPI18n.language=l;const t=c.RPCriminalite.texte;assert.equal(t('r_deux_objets_revetus_max'),t('r_trois_objets_revetus_max'));assert.equal(t('r_deux_objets_revetus_max'),c.RPCriminalite.T[l].r_trois_objets_revetus_max);}
 assert.equal(JSON.stringify(c.state),before);
});
test('Produire une fuite : français exact de data.js, huit traductions raccordées au résolveur',()=>{
 const c=setup();c.state.country='republic';const d={};vm.runInNewContext(read('data.js')+';this.B=BUILDINGS;',d);
 const desc=Object.values(d.B['palais-gouvernement'].rooms).flatMap(r=>r.orders||[]).find(o=>o.fn==='fuite_info').desc;
 const row=c.RP_INFOBULLES_REPUBLIA.find(r=>r[0]===desc);assert.ok(row);const before=JSON.stringify(c.state);
 for(const [i,l]of langs.entries()){c.lang=l;assert.equal(c.RPOrderDescriptionsI18n.desc(desc),row[i]);}
 assert.equal(JSON.stringify(c.state),before);
});
for(const [id,fr]of Object.entries(reference.extraTables))test(id+' : français exact, neuf langues, noms propres et variables',()=>{
 const [file,name]=id.split('#'),s=read(file),a=s.indexOf('const '+name+' = {'),b=name==='T_SUITE'?s.indexOf('\n  };',a)+5:s.indexOf('};',a)+2,c={};vm.runInNewContext(s.slice(a,b)+';this.T='+name+';',c);const T=JSON.parse(JSON.stringify(c.T));assert.deepEqual(T.fr,fr);
 for(const l of langs){assert.ok(T[l]);const entries=typeof fr==='string'?{text:fr}:leaves(fr),m=typeof T[l]==='string'?{text:T[l]}:leaves(T[l]);for(const [k,text]of Object.entries(entries)){assert.ok(m[k]?.trim(),l+' '+k);assert.deepEqual(vars(m[k]),vars(text));for(const name of ['Roxane Velours','Tito Maletas','Al-Khalija'])if(text.includes(name))assert.ok(m[k].includes(name),l+' '+name);}}
});
test('clés demandées : ordres et faux documents déjà traduits, sans identifiant nouveau',()=>{
 const c=setup();vm.runInContext(read('i18n/resources.js'),c);vm.runInContext(read('i18n/orders-resources.js'),c);vm.runInContext(read('i18n/equipements-resources.js'),c);
 for(const l of langs){c.lang=l;for(const k of ['indices_interrogatoire','transferts_detenus'])assert.ok(c.RP_I18N_RESOURCES[l].translation.orders[k]);for(const [k,fr]of [['fauxLaissezPasser','Faux laissez-passer'],['fauxCarton',"Faux carton d’invitation"]]){const t=c.texteEquip(k,fr);assert.ok(t);if(l!=='fr')assert.notEqual(t,fr);}}
});
