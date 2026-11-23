const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),cp=require('node:child_process'),os=require('node:os');
const ROOT=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(ROOT,f),'utf8');
const {scanner,extraire,parcourirLieux}=require('../images/auditer-references-images.cjs');
const acorn=require('../vercel/node_modules/acorn');
function valeur(source,nom){const n=acorn.parse(source,{ecmaVersion:'latest'}).body.find(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name===nom));assert.ok(n,nom);return JSON.parse(vm.runInNewContext(source.slice(n.start,n.end)+';JSON.stringify('+nom+')'));}
test('aucune référence image littérale absente : code, HTML, CSS et destinations Vercel',()=>{
 const r=scanner();assert.ok(r.compteurs.references>=1200);assert.ok(r.compteurs.locales>=950);assert.deepEqual(r.absentes,[]);
});
test('le contrôle refuse une image absente, une casse incorrecte et une cible de réécriture absente',()=>{
 const d=fs.mkdtempSync(path.join(os.tmpdir(),'hg-images-'));
 try{fs.mkdirSync(path.join(d,'images'));fs.writeFileSync(path.join(d,'images','Photo.webp'),'fixture');
 fs.writeFileSync(path.join(d,'test.js'),"// images/commentaire.png\nconst a='images/Photo.webp', b='images/photo.webp', c='images/manquante.png', d='images/ancienne.png';");
 fs.writeFileSync(path.join(d,'vercel.json'),JSON.stringify({rewrites:[{source:'/images/ancienne.png',destination:'/images/cible.webp'}]}));
 cp.execFileSync('git',['init','-q'],{cwd:d});cp.execFileSync('git',['add','.'],{cwd:d});
 const r=scanner(d);assert.deepEqual(r.absentes.map(x=>x.local).sort(),['images/cible.webp','images/cible.webp','images/manquante.png','images/photo.webp'].sort());
 assert.ok(!r.references.some(x=>x.url.includes('commentaire')));
 fs.writeFileSync(path.join(d,'images','non-suivie.webp'),'fixture');fs.appendFileSync(path.join(d,'test.js'),"const oubliee='images/non-suivie.webp';");
 assert.ok(scanner(d).absentes.some(x=>x.url==='images/non-suivie.webp'),'un fichier non ajouté à Git ne sera pas déployé');
 }finally{fs.rmSync(d,{recursive:true,force:true});}
});
test('URL encodée et paramètres conservés ; aucun faux appel issu d’un commentaire',()=>{
 assert.deepEqual(extraire('url("images/Salle%20presse.webp?v=2")'),['images/Salle%20presse.webp?v=2']);
 assert.deepEqual(extraire('<img src="icones/portrait.svg">'),['icones/portrait.svg']);
 assert.deepEqual(extraire('background:url(logos/logo.webp)'),['logos/logo.webp']);
});
test('les référentiels exécutés couvrent les quatre empires et les noms construits',()=>{
 const p=parcourirLieux();assert.equal(p.lieux.length,4);assert.ok(p.references.length>3000);
 for(const r of p.references)if(r.url.startsWith('images/'))assert.ok(fs.existsSync(path.join(ROOT,decodeURIComponent(r.url.split(/[?#]/)[0]))),r.localisation+' : '+r.url);
});
test('chemins construits : forêt et toundra présentes, aucun nouveau candidat absent de chantier',()=>{
 const {inventorier}=require('../images/auditer-candidats-images.cjs');
 const connus=new Set(JSON.parse(lire('outils/audits/images-cassees-20261122/IMAGES-MANQUANTES-20261122.json')).candidats_chantiers_non_produits);
 const suivis=new Set(cp.execFileSync('git',['ls-files','-z'],{cwd:ROOT}).toString().split('\0'));
 for(const r of inventorier()){
  if(r.url)assert.ok(suivis.has(r.url)&&fs.existsSync(path.join(ROOT,r.url)),r.systeme+' : '+r.url);
  if(r.candidats){assert.ok(r.existants.some(u=>suivis.has(u)),'aucune illustration affichable : '+JSON.stringify(r));
   for(const u of r.candidats)if(!suivis.has(u)||!fs.existsSync(path.join(ROOT,u)))assert.ok(connus.has(u),'nouveau chemin construit absent : '+u);
  }
 }
});
test('neuf cartes postales et trois armes soviétiques : alias exact vers le vrai WebP',()=>{
 const v=JSON.parse(lire('vercel.json')).rewrites;
 const cartes=['luthecia-carte-postale-culture','luthecia-carte-postale-institutions','luthecia-carte-postale-internationale','montrouge/montrouge-carte-postale-musee-rail','montrouge/montrouge-carte-postale-place-rail','montrouge/montrouge-carte-postale-touristique','port-sainte-marie-carte-postale-culture-marine','port-sainte-marie-carte-postale-notre-dame-mer','port-sainte-marie-carte-postale-touristique'];
 for(const n of [...cartes,...['baionnette','makarov','kalachnikov'].map(n=>'arme-'+n+'-soviet')]){const r=v.find(x=>x.source==='/images/'+n+'.png');assert.equal(r?.destination,'/images/'+n+'.webp');assert.ok(fs.existsSync(path.join(ROOT,r.destination.slice(1))));}
});
test('anciennes URL GitHub : même illustration, pas de conversion aveugle ni mutation d’objet',()=>{
 const ctx={};vm.runInNewContext(lire('plateau-images.js')+';this.f=imagePubliqueUrl',ctx);
 const prefix='https://raw.githubusercontent.com/FredJ74/res-publica/main/images/';
 for(const n of ['arme-fusil-republic','arme-mitraillette-militaire','arme-pistolet-militaire','calepin-enigme-musee','stade-brise-mariannaise','stade-olympique-luthecia']){assert.equal(ctx.f(prefix+n+'.png'),'images/'+n+'.webp');assert.ok(fs.existsSync(path.join(ROOT,ctx.f(prefix+n+'.png'))));}
 for(const u of [prefix+'militaire-trousse-secours.png','https://exemple.invalid/photo.png','images/absente-nouvelle.png',null])assert.equal(ctx.f(u),u);
 assert.equal(ctx.f('images/armoire-a-souvenirs.png'),'');
 const src=lire('plateau-personnage.js'),a=src.indexOf('const IMAGES_OBJETS_PAR_IDENTITE'),b=src.indexOf('\n}\n',src.indexOf('function imageUrlObjet('))+3;
 vm.runInNewContext(lire('plateau-images.js')+'\n'+src.slice(a,b)+';this.f=imageUrlObjet',ctx);
 const objet={imageUrl:prefix+'calepin-enigme-musee.png',qte:2,nom:'Témoin',argent:45};const avant=JSON.stringify(objet);assert.equal(ctx.f(objet),'images/calepin-enigme-musee.webp');assert.equal(JSON.stringify(objet),avant);
});
test('noms, descriptions françaises, prix, bonus et recettes inchangés',()=>{
 const temoin=JSON.parse(lire('outils/bancs/fixtures/images-mecaniques-20261122.json'));
 for(const[nom,fichier]of [['ARMES_CATALOGUE','plateau-actions-illegales-rumeurs.js'],['PRODUITS_MANUFACTURES_USINE','plateau-justice-economie.js']]){
  const actuel=valeur(lire(fichier),nom);const nettoyer=x=>{if(Array.isArray(x))return x.map(nettoyer);if(x&&typeof x==='object')return Object.fromEntries(Object.entries(x).filter(([k])=>k!=='imageUrl').map(([k,v])=>[k,nettoyer(v)]));return x;};
  assert.deepEqual(nettoyer(actuel),temoin[nom]);
 }
});
