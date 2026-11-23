/* Inventaire des URL d'images du client : AST JavaScript, HTML/CSS et réécritures Vercel.
 * Aucun réseau ni accès à la base dans scanner(). Les commentaires ne sont pas des appels.
 */
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const ROOT=path.resolve(__dirname,'../..');
const acorn=require('../vercel/node_modules/acorn');
const EXT='(?:webp|png|jpe?g|gif|svg|avif|ico)';
function extraire(texte){
  const urls=[...texte.matchAll(new RegExp('(?:https?://[^\\s"\'`<>\\\\]*?|/?images/)[^\\s"\'`<>\\\\(){}$]*?\\.'+EXT+'(?:[?#][^\\s"\'`<>\\\\()]*)?','gi'))].map(m=>m[0]);
  // Une image peut aussi être rangée hors de images/ (HTML, CSS ou HTML dans une chaîne JS).
  const ajouter=url=>{if(!/^(?:https?:|data:|\/?images\/)/i.test(url)&&new RegExp('\\.'+EXT+'(?:[?#].*)?$','i').test(url))urls.push(url);};
  for(const m of texte.matchAll(/\b(?:src|href|poster)\s*=\s*["']([^"']+)["']/gi))ajouter(m[1]);
  for(const m of texte.matchAll(/url\(\s*["']?([^\s"')]+)["']?\s*\)/gi))ajouter(m[1]);
  return urls;
}
function scanner(root=ROOT){
  const fichiers=cp.execFileSync('git',['ls-files','-z'],{cwd:root}).toString().split('\0').filter(Boolean);
  const references=[],dynamiques=[],suivis=new Set(fichiers);
  function ajouter(texte,fichier,ligne){for(const url of extraire(texte))references.push({fichier,ligne,url});}
  for(const fichier of fichiers){
    if(!/\.(?:js|mjs|cjs|html|css|json)$/.test(fichier)||/^(?:\.|outils\/|historique\/|baseline\/|Blender\/|referentiel-game-design\/)/.test(fichier))continue;
    const texte=fs.readFileSync(path.join(root,fichier),'utf8');
    if(fichier==='vercel.json'){
      const v=JSON.parse(texte);for(const r of v.rewrites||[])if(r.destination?.startsWith('/images/'))ajouter(r.destination,fichier,0);
      continue;
    }
    if(/\.(?:js|mjs|cjs)$/.test(fichier)){
      const ast=acorn.parse(texte,{ecmaVersion:'latest',sourceType:'module',locations:true});
      const visiter=n=>{if(!n||typeof n!=='object')return;
        if(n.type==='Literal'&&typeof n.value==='string')ajouter(n.value,fichier,n.loc.start.line);
        if(n.type==='Property'&&/^(?:image(?:Url|GrosPlan)?|photoUrl|photo_url|portrait|vignette|avatar)$/.test(n.key.name||n.key.value||'')&&typeof n.value.value==='string'&&(/^https?:/.test(n.value.value)||new RegExp('\\.'+EXT+'(?:[?#].*)?$','i').test(n.value.value))&&!extraire(n.value.value).length)
          references.push({fichier,ligne:n.loc.start.line,url:n.value.value});
        if(n.type==='BinaryExpression'&&n.operator==='+'&&n.left.type==='Literal'&&typeof n.left.value==='string'&&n.left.value.startsWith('images/'))
          dynamiques.push({fichier,ligne:n.loc.start.line,expression:texte.slice(n.start,n.end)});
        if(n.type==='TemplateLiteral'){
          if(!n.expressions.length)ajouter(n.quasis[0].value.cooked||'',fichier,n.loc.start.line);
          else if(n.quasis.some(q=>/images\//.test(q.value.raw)))dynamiques.push({fichier,ligne:n.loc.start.line,expression:texte.slice(n.start,n.end)});
        }
        for(const[k,v]of Object.entries(n))if(k!=='loc'){if(Array.isArray(v))v.forEach(visiter);else if(v&&typeof v==='object')visiter(v);}
      };visiter(ast);
    }else ajouter(texte.replace(/<!--[\s\S]*?-->|\/\*[\s\S]*?\*\//g,''),fichier,1);
  }
  const v=JSON.parse(fs.readFileSync(path.join(root,'vercel.json'),'utf8'));
  const rewrites=new Map((v.rewrites||[]).filter(x=>x.source.startsWith('/images/')).map(x=>[x.source,x.destination]));
  const urls=[...new Set(references.map(r=>r.url))].sort().map(url=>{
    const externe=/^https?:/.test(url)&&!/^https?:\/\/(?:www\.)?human-gambit\.com\//.test(url);
    let local=externe?null:decodeURIComponent(url.replace(/^https?:\/\/(?:www\.)?human-gambit\.com\//,'').split(/[?#]/)[0]).replace(/^\//,'');
    const rewrite=local&&rewrites.get('/'+local);if(rewrite)local=decodeURIComponent(rewrite.slice(1));
    return{url,local,rewrite:rewrite||null,externe,existe:local?suivis.has(local)&&fs.existsSync(path.join(root,local)):null};
  });
  return{references,urls,dynamiques,compteurs:{fichiers:new Set(references.map(x=>x.fichier)).size,references:references.length,urls:urls.length,locales:urls.filter(x=>!x.externe).length,externes:urls.filter(x=>x.externe).length},absentes:urls.filter(x=>x.existe===false)};
}
if(require.main===module){const r=scanner();const i=process.argv.indexOf('--rapport');if(i>=0)fs.writeFileSync(process.argv[i+1],JSON.stringify(r,null,2)+'\n');console.log(JSON.stringify({compteurs:r.compteurs,absentes:r.absentes,dynamiques:r.dynamiques},null,2));}
module.exports={scanner,extraire};

// Exécute les référentiels, pas les déplacements : les noms de fichiers construits
// à partir d'un préfixe et d'une ville sont ainsi contrôlés eux aussi.
function parcourirLieux(){
  const {charger}=require('../audits/auditer-republia-complet.cjs');
  const references=[],lieux=[];
  for(const pays of ['republic','soviet','narco','khalija']){
    const data=charger(pays);lieux.push({pays,villes:data.villes});
    const visiter=(val,localisation,cle)=>{
      if(typeof val==='string'&&(val.startsWith('images/')||(/^(?:image|imageUrl|photoUrl|imageGrosPlan)$/.test(cle)&&/^https?:/.test(val))))references.push({pays,localisation,url:val});
      else if(val&&typeof val==='object')for(const[k,v]of Object.entries(val))visiter(v,localisation+'.'+k,k);
    };visiter(data,pays,'');
  }
  return{references,lieux};
}
module.exports.parcourirLieux=parcourirLieux;
