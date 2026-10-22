// Inventaire de sources, pas des soldes/projets reels. Aucun prix ni surface persistante remplace.
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path'),acorn=require('../vercel/node_modules/acorn');
const racine=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(racine,f),'utf8');
const c=vm.createContext({console,window:{},state:{country:'republic'}});
for(const f of ['data.js','plateau-immobilier.js','plateau-chantiers.js','plateau-construction-parcours.js'])vm.runInContext(lire(f),c);
function declarer(f,noms){const s=lire(f);for(const n of acorn.parse(s,{ecmaVersion:'latest'}).body)if(n.type==='VariableDeclaration'&&n.declarations.some(d=>noms.includes(d.id.name)))vm.runInContext(s.slice(n.start,n.end),c);}
declarer('plateau-pnj.js',['SURFACE_TERRAINS']);declarer('plateau-actions-illegales-rumeurs.js',['PRIX_RACHAT_COMMERCE','PRIX_RACHAT_ARMURERIE','PRIX_RACHAT_IMPRIMERIE']);
const migration=lire('migrations/20261021203047_immobilier_offres_fonds_murs.sql');
const tarif=Number(migration.match(/INSERT INTO public\.immobilier_tarifs_pays VALUES\('republic',(\d+)\)/)?.[1]);
const surface=Number(migration.match(/immobilier_surfaces_validees VALUES\('republic','capitale','hotel-republica',(\d+)\)/)?.[1]);
if(!Number.isFinite(tarif)||!Number.isFinite(surface))throw Error('donnees_approuvees_introuvables');
const src=lire('plateau-construction-parcours.js'),fn=acorn.parse(src,{ecmaVersion:'latest'}).body.find(n=>n.type==='FunctionDeclaration'&&n.id.name==='choisirTerrainPermis');
const appel=fn.body.body.find(n=>n.type==='ReturnStatement').argument;
if(appel.callee.name!=='doDeposerDemandePermis'||appel.arguments[1].type!=='Literal')throw Error('cout_du_permis_non_extrait');
const permis=appel.arguments[1].value;
const parcelles=vm.runInContext(`Object.entries(WORLD.republic).flatMap(([ville,v])=>v.buildings.filter(id=>id.startsWith('terrain-a-batir')).map(id=>({ville,id,...constructionReferenceTerrain(id,{})})))`,c);
const chantier=vm.runInContext("coutTotalConstruction('building')",c);
const comparaisons=parcelles.map(p=>({...p,budget_chantier:chantier,permis_declare_client:permis,
 sous_total_connu:p.prix===null?null:p.prix+chantier+permis,
 murs_reference_comparaison:surface*tarif,geometrie_a_verifier:p.surface===null?'surface_parcelle_absente':'capacite_du_projet_et_reception_a_confirmer_PR58',
 comparaison_complete:false}));
process.stdout.write(JSON.stringify({portee:'Sources locales uniquement ; aucune demonstration de cout complet ou comparabilite en production',
 barreme_murs_republic:tarif,la_republica:{surface_validee:surface,murs_reference:surface*tarif,fonds_catalogue:vm.runInContext("PRIX_RACHAT_COMMERCE['hotel-republica']",c)},
 prix_fonds_existants:vm.runInContext('({commerces:PRIX_RACHAT_COMMERCE,armurerie:PRIX_RACHAT_ARMURERIE,imprimerie:PRIX_RACHAT_IMPRIMERIE})',c),
 comparaisons,limites:['Acompte de 1000 FR non ajoute au prix : il est deja compris dans celui-ci.','Materiaux et travail deja dans le budget forfaitaire, pas de double compte.','Frais reels, geometrie admissible et reception dependant de PR58 non verifies ; aucun tarif modifie.','Seule la surface de La Republica est approuvee pour les commerces PNJ ; autres comparaisons non etablies.']},null,2)+'\n');
