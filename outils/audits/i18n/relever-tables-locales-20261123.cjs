'use strict';
// Analyse AST seule ; aucun module du jeu ni appel réseau exécuté.
const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib'),{execFileSync}=require('node:child_process');
const {parse,walk,normalize}=require('../audit-i18n-global.cjs');
const R=path.resolve(__dirname,'../../..'),langs=['en','es','zh-TW','ru','ko','ar','pt-BR','de'];
const props=n=>n?.type==='ObjectExpression'?n.properties.filter(p=>p.type==='Property'):[];
const key=p=>p.key.name??p.key.value;
function leaves(n,prefix=''){const result={};for(const p of props(n)){const k=prefix+key(p);if(p.value.type==='Literal'&&typeof p.value.value==='string')result[k]=p.value.value;else if(p.value.type==='ObjectExpression')Object.assign(result,leaves(p.value,k+'.'));}return result;}
const sources=process.argv[2];if(!sources)throw Error('Usage : node relever-tables-locales-20261123.cjs <ressources.json.gz>');
const resources=JSON.parse(zlib.gunzipSync(fs.readFileSync(sources))),byText=new Map();for(const r of resources){const k=normalize(r.fr);if(!byText.has(k))byText.set(k,[]);byText.get(k).push(r);}
const out=[];
for(const file of execFileSync('git',['ls-files','-z'],{cwd:R,encoding:'utf8'}).split('\0').filter(f=>/\.js$/.test(f)&&!f.startsWith('outils/')&&!f.startsWith('i18n/')&&!f.includes('node_modules'))){
 const tree=parse(fs.readFileSync(path.join(R,file),'utf8'));walk(tree,n=>{const p=props(n).find(p=>key(p)==='fr');if(!p||p.value.type!=='ObjectExpression')return;
 const fr=leaves(p.value),maps=Object.fromEntries(langs.map(l=>[l,leaves(props(n).find(p=>key(p)===l)?.value)]));
 for(const [k,text] of Object.entries(fr)){const direct=langs.filter(l=>!maps[l][k]);if(!direct.length)continue;const alternatives=byText.get(normalize(text))||[],missing=direct.filter(l=>!alternatives.some(r=>['available-unreviewed','neutral'].includes(r.status[l])));
 out.push({fichier:file,ligne:n.loc.start.line,cle_locale:k,fr:text,langues_absentes_de_la_table:direct,langues_sans_ressource_alternative:missing,ressources_alternatives:alternatives.map(r=>({fichier:r.file,cle:r.key})),statut:'analyse-statique-a-verifier-au-rendu'});
 }
 });
}
fs.writeFileSync(path.join(__dirname,'TABLES-LOCALES-FR-20261123.json'),JSON.stringify(out,null,2)+'\n');console.log(JSON.stringify({clesLocalesAvecAbsence:out.length,sansAlternative:out.filter(x=>x.langues_sans_ressource_alternative.length).length}));
