// node --test outils/bancs/banc-archives-musee.cjs
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const racine = path.resolve(__dirname, '../..');
function archives(cache, ancienne = true, recherche = '') {
  const zone = {innerHTML:'',textContent:''};
  const ctx = vm.createContext({console,Intl,Date,document:{getElementById:id=>
    id === 'archives-tribune-liste' ? zone : id === 'archives-tribune-recherche' ? {value:recherche} : null}});
  vm.runInContext(fs.readFileSync(path.join(racine, 'plateau-enigme-portrait.js'), 'utf8'),ctx);
  ctx.cache = cache;
  vm.runInContext(`_archivesTribuneCache=cache;_archivesTribuneOnglet='${ancienne?'anciennes':'recentes'}';archivesTribuneFiltrer()`, ctx);
  return {ctx,zone};
}
test('les deux indices historiques restent lisibles pendant une panne du catalogue', () => {
  const {ctx,zone} = archives(null);
  assert.match(zone.innerHTML,/Catalogue temporairement indisponible/);
  assert.match(zone.innerHTML,/Un nouvel élan industriel pour Luthécia/);
  assert.match(zone.innerHTML,/affaire Caillon/);
  assert.match(zone.innerHTML,/enigme1AfficherArticlePresse\(0\)/);
  assert.match(zone.innerHTML,/enigme1AfficherArticlePresse\(1\)/);
  const corps={innerHTML:''};ctx.document.getElementById=()=>corps;
  ctx.enigme1AfficherArticlePresse(0);assert.match(corps.innerHTML,/Jacques Moulin/);
  ctx.enigme1AfficherArticlePresse(1);assert.match(corps.innerHTML,/Maurice Caillon/);
});
test('une panne ne pretend pas que les parutions recentes sont vides', () => {
  const {zone} = archives(null,false);assert.match(zone.textContent,/indisponible/);
});
test('recentes, anciennes PJ et historiques respectent la limite existante de 30 jours', () => {
  const lignes=[{id:'pj',date_edition:'2000-01-01',titre:'Ancienne PJ',contient_pj:true},
    {id:'pnj',date_edition:'2000-01-01',titre:'Ancienne PNJ',contient_pj:false},
    {id:'recent',date_edition:'2999-01-01',titre:'Recente',contient_pj:false}];
  const ancien=archives(lignes).zone.innerHTML;
  assert.match(ancien,/Ancienne PJ/);assert.doesNotMatch(ancien,/Ancienne PNJ|Recente/);
  const recent=archives(lignes,false).zone.innerHTML;
  assert.match(recent,/Recente/);assert.doesNotMatch(recent,/Ancienne PJ|affaire Caillon/);
});
test('recherche historique et echappement HTML restent actifs', () => {
  const html=archives(null,true,'Caillon').zone.innerHTML;
  assert.match(html,/affaire Caillon/);assert.doesNotMatch(html,/nouvel élan industriel/);
  const hostile=archives([{id:'x',date_edition:'2000-01-01',titre:'<script>alert(1)</script>',contient_pj:true}]).zone.innerHTML;
  assert.doesNotMatch(hostile,/<script>/);assert.match(hostile,/&lt;script&gt;/);
});
function index(lire) {
  const src=fs.readFileSync(path.join(racine,'supabase.js'),'utf8');
  const a=src.indexOf('async function sbGetArchivesTribuneIndex()');
  const b=src.indexOf('async function sbLirePresseEdition(',a);
  const ctx=vm.createContext({sbGet:lire});vm.runInContext(src.slice(a,b),ctx);
  return ctx.sbGetArchivesTribuneIndex();
}
test('le catalogue conserve les parutions au-dela du plafond de 1000', async () => {
  const appels=[];
  const lignes=Array.from({length:1001},(_,id)=>({id}));
  const resultat=await index(async(table,filtre)=>{
    assert.equal(table,'archives_tribune_index');appels.push(filtre);
    const offset=Number(new URLSearchParams(filtre).get('offset'));
    return lignes.slice(offset,offset+1000);
  });
  assert.equal(resultat.length,1001);assert.equal(appels.length,2);
  assert.ok(appels.every(f=>f.includes('order=date_edition.desc,id.asc')));
});
test('une panne de la seconde page ne livre pas un catalogue tronque', async () => {
  let n=0;assert.equal(await index(async()=>++n===1?Array(1000).fill({}):null),null);
});
test('un catalogue vide est bien distinct de la panne', async () => {
  assert.equal((await index(async()=>[])).length,0);
});
