'use strict';
// Trois regressions remontees par les testeurs, sans reseau ni effet sur les comptes.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const js=fs.readFileSync(path.join(root,'creation.js'),'utf8');
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const data=fs.readFileSync(path.join(root,'data.js'),'utf8');
function func(name){
  const start=js.indexOf('function '+name+'(');
  assert.ok(start>=0,name+' manquante');
  const brace=js.indexOf('{',start);let n=0,end=brace;
  // fonctions selectionnees sans accolades dans des chaines complexes
  for(;end<js.length;end++){if(js[end]==='{')n++;if(js[end]==='}'&&!--n){end++;break;}}
  return js.slice(start,end);
}
test('Gmail valide : ancienne erreur effacee a la nouvelle saisie, types email conserves',()=>{
  assert.match(html,/<input id="auth-email" type="email"[^>]*oninput="effacerErreurIdentifiants\\(\\)"/);
  assert.match(html,/<input id="auth-mdp"[^>]*oninput="effacerErreurIdentifiants\\(\\)"/);
  const msg={style:{display:'block'},textContent:'Adresse invalide',attrs:{'data-i18n':'auth.errEmail'},
    removeAttribute(k){delete this.attrs[k];}};
  const context={document:{getElementById:id=>id==='auth-msg'?msg:null}};
  vm.createContext(context);vm.runInContext(func('effacerErreurIdentifiants'),context);
  assert.match('prenom.nom@gmail.com',/^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$/);
  context.effacerErreurIdentifiants();
  assert.equal(msg.style.display,'none');assert.equal(msg.textContent,'');
  assert.equal(msg.attrs['data-i18n'],undefined);
  assert.match(js,/const email = \\(document.getElementById\\('auth-email'\\)\\?\\.value \\|\\| ''\\)\\.trim\\(\\)/);
});
test('Variations : noms et descriptions via traduction existante, valeurs preservees',()=>{
  const defs=[['INT','Intelligence'],['CHA','Charisme'],['VOL','Volonte'],['PER','Perception'],['DUP','Duplicite'],['ENT','Entregent']];
  for(const [k,n]of defs)assert.ok(data.includes("k:'"+k+"'")&&data.includes(n));
  const s=js.slice(js.indexOf('function libelleVariationStat('),js.indexOf('/* ---- Origin ---- */'));
  assert.match(s,/creation\\.stats\\./);
  const ctx={STAT_DEFS:defs.map(([k,n])=>({k,n,d:n+' description'})),
    t:key=>{const k=key.split('.')[2],prop=key.split('.')[3],d=defs.find(x=>x[0]===k);return prop==='name'?d[1]:d[1]+' description';}};
  vm.createContext(ctx);vm.runInContext(s,ctx);
  assert.match(ctx.libelleVariationStat('ENT',-1),/-1 Entregent/);
  assert.match(ctx.libelleVariationStat('DUP',1),/\\+1 Duplicite/);
  assert.match(ctx.libelleVariationStat('DUP',1),/title="Duplicite description"/);
  for(const key of ['o.bonuses','o.malus','s.bonuses','s.malus','a.bonuses','a.malus'])
    assert.ok(js.includes('Object.entries('+key),key+' toujours utilise');
  assert.match(js,/libelleVariationStat\\(c.statKey,1\\)/);
});
test('Ville : apres selection valide, prochaine etape et retour possible',()=>{
  const city=js.slice(js.indexOf('function selCity('),js.indexOf('/* Variations explicites'));
  const calls=[];const G={country:'republic',city:null};
  const context={G,rpEmpireOuvertCreation:()=>true,goTo:n=>calls.push(n),
    document:{getElementById:id=>id==='modal-city'?{classList:{remove:v=>calls.push(v)}}:{disabled:true}}};
  vm.createContext(context);vm.runInContext(city,context);
  context.selCity('capitale');
  assert.equal(G.city,'capitale');assert.deepEqual(calls,['open',2]);
  assert.match(html,/id="n1"[^>]*onclick="goTo\\(2\\)"/);
  assert.match(html,/id="s2"[\\s\\S]*?onclick="goTo\\(1\\)"/);
});
