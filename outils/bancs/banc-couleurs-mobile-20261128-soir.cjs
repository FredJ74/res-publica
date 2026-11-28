// Banc navigateur : l'habillage mobile suit l'empire du personnage (Fred, 28/11/2026 soir, point 4 : « L'habillage mobile
// suit désormais l'empire, avec les mêmes palettes »). HTML et CSS réels de plateau.html (scripts retirés, aucun réseau).
// Vérifie, à 375 px puis en paysage : fonds de la coque tirés des variables d'empire, contraste AA des textes, PA turquoise
// d'Al-Khalija ; sans classe d'empire, la coque bleu nuit d'origine ; à 1440 px, la feuille mobile ne change aucun pixel.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {R,preuve,avecJeu,page}=require('./mobile-navigateur.cjs');
const FEUILLE='plateau-mobile-empires-20261128.css';
const css=fs.readFileSync(path.join(R,FEUILLE),'utf8');
const ENTETE_MOBILE=['plateau-mobile-identite-20261117.js','plateau-mobile-entete-compact.js','plateau-interieurs-mobile.js'];
const EMPIRES=['republic','narco','soviet','khalija'];

async function coque(b,o,w,h,empire){
 const p=await page(b,o,w,h);for(const f of ENTETE_MOBILE)await p.addScriptTag({url:o+'/'+f});
 await p.evaluate(e=>{document.body.classList.remove('empire-republic','empire-narco','empire-soviet','empire-khalija');if(e)document.body.classList.add('empire-'+e);
  document.getElementById('r-pa').textContent='12';document.getElementById('char-fullname-left').textContent='Personnage témoin';},empire);
 await p.waitForTimeout(250);return p;
}
// Contraste WCAG du texte de chaque élément visible sur le premier fond opaque de ses ancêtres.
const mesurer=p=>p.evaluate(()=>{
 const rgb=s=>{const m=s.match(/rgba?\(([^)]+)\)/);if(!m)return null;const v=m[1].split(/[ ,\/]+/).filter(Boolean).map(Number);return {r:v[0],g:v[1],b:v[2],a:v.length>3?v[3]:1};};
 const lum=c=>{const f=x=>{x/=255;return x<=.03928?x/12.92:((x+.055)/1.055)**2.4;};return .2126*f(c.r)+.7152*f(c.g)+.0722*f(c.b);};
 const fond=e=>{for(let n=e;n;n=n.parentElement){const c=rgb(getComputedStyle(n).backgroundColor);if(c&&c.a>=.99)return c;}return {r:0,g:0,b:0,a:1};};
 const SEL=['#hg-mobile-brand .hg-mobile-brand-name','#hg-mobile-brand .hg-mobile-brand-role','#hg-identite-pa','#hg-identite-pa small','#hg-identite-argent small',
  '#vue-rue .hg-explore-place','#vue-rue .game-time-display','#vue-rue #hg-explore-primary button','#vue-rue .hg-presences-total','#vue-rue #actionbar .action-context',
  '#topbar .hg-mobile-acces'];
 const res=[];for(const s of SEL)for(const e of document.querySelectorAll(s)){const r=e.getBoundingClientRect();if(!r.width||!r.height||getComputedStyle(e).visibility==='hidden')continue;
  const t=rgb(getComputedStyle(e).color),f=fond(e),[a,b]=[lum(t),lum(f)].sort((x,y)=>y-x);res.push({s,texte:getComputedStyle(e).color,ratio:Math.round((a+.05)/(b+.05)*100)/100});}
 return res;});
const fonds=p=>p.evaluate(()=>{const v=n=>getComputedStyle(document.body).getPropertyValue(n).trim().toLowerCase();const hex=c=>{const m=c.match(/\d+/g).slice(0,3).map(Number);return '#'+m.map(x=>x.toString(16).padStart(2,'0')).join('');};
 return {topbar:hex(getComputedStyle(document.getElementById('topbar')).backgroundColor),identite:hex(getComputedStyle(document.getElementById('hg-mobile-identite-20261117')).backgroundColor),
  statut:hex(getComputedStyle(document.getElementById('hg-identite-argent')).backgroundColor),bg2:v('--bg2'),bg4:v('--bg4'),
  pa:hex(getComputedStyle(document.getElementById('hg-identite-pa')).color)};});

test('feuille chargée après toutes les feuilles mobiles, entièrement sous max-width:1023px hors jetons',()=>{
 const html=fs.readFileSync(path.join(R,'plateau.html'),'utf8');const liens=[...html.matchAll(/<link rel="stylesheet" href="([^"?]+)/g)].map(m=>m[1]);
 const mobiles=liens.filter(l=>/mobile/.test(l));assert.equal(mobiles.at(-1),FEUILLE);assert.ok(mobiles.length>=7);
 const sans=css.replace(/\/\*[\s\S]*?\*\//g,'');const hors=sans.slice(0,sans.indexOf('@media(max-width:1023px)'));
 assert.deepEqual([...hors.matchAll(/([^{}]+)\{/g)].map(m=>m[1].trim()),['body.empire-republic,body.empire-narco,body.empire-khalija','body.empire-soviet']);
 assert.doesNotMatch(hors,/background|color:/,'les jetons ne peignent rien par eux-mêmes');
});
for(const [w,h] of [[375,667],[852,393]])test(`coque ${w}×${h} : fonds d'empire et contraste AA`,async()=>avecJeu(async(b,o)=>{
 for(const e of EMPIRES){const p=await coque(b,o,w,h,e);const f=await fonds(p);
  assert.equal(f.topbar,f.bg2,e+' : en-tête sur --bg2');assert.equal(f.identite,f.bg2,e+' : bandeau sur --bg2');assert.equal(f.statut,f.bg4,e+' : pastilles sur --bg4');
  if(e==='khalija')assert.equal(f.pa,'#5fa8a7','PA turquoise');else assert.notEqual(f.pa,'#5fa8a7');
  const m=await mesurer(p);assert.ok(m.length>=8,e+' : éléments mesurés');
  for(const x of m)assert.ok(x.ratio>=4.5,`${e} ${w} : ${x.s} ${x.texte} à ${x.ratio}:1`);
  preuve(`couleurs-mobile-${e}-${w}.png`,await p.screenshot());await p.context().close();}
 // Sans empire (avant le chargement du personnage) : la coque bleu nuit d'origine.
 const p=await coque(b,o,w,h,null);const f=await fonds(p);assert.equal(f.topbar,'#172b3c');assert.equal(f.identite,'#172b3c');
 preuve(`couleurs-mobile-sans-empire-${w}.png`,await p.screenshot());
}));
test('bureau 1440 : la feuille mobile ne change aucun pixel, quel que soit l’empire',async()=>avecJeu(async(b,o)=>{
 for(const e of EMPIRES){const p=await coque(b,o,1440,900,e);const avec=await p.screenshot();
  await p.locator(`link[href^="${FEUILLE}"]`).evaluate(l=>l.remove());await p.waitForTimeout(200);
  assert.ok((await p.screenshot()).equals(avec),e+' : bureau identique');preuve(`couleurs-bureau-${e}-1440.png`,avec);await p.context().close();}
}));
test('Al-Khalija au bureau : PA et onglet actif du journal aux contrastes annoncés',async()=>avecJeu(async(b,o)=>{
 const p=await coque(b,o,1440,900,'khalija');
 const c=await p.evaluate(()=>({nom:getComputedStyle(document.querySelector('#hg-jauge-pa .hg-jauge-nom')).color,val:getComputedStyle(document.querySelector('#hg-jauge-pa .hg-jauge-val')).color,
  text3:getComputedStyle(document.body).getPropertyValue('--text3').trim()}));
 assert.equal(c.nom,'rgb(79, 149, 148)');assert.equal(c.val,'rgb(95, 168, 167)');assert.equal(c.text3,'#ad9574');
}));
