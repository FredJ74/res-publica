// Referentiel des parcelles declarees : lecture du WORLD et des ordres effectifs existants.
// Aucune superficie ou tarification reconstituee. Ne modifie jamais les etats persistants.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const acorn=require('../vercel/node_modules/acorn');
const root=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(root,f),'utf8');
const c=vm.createContext({window:{},console});vm.runInContext(lire('data.js'),c);
const pnj=lire('plateau-pnj.js'),noeud=acorn.parse(pnj,{ecmaVersion:'latest'}).body.find(n=>n.type==='VariableDeclaration'&&n.declarations.some(d=>d.id.name==='SURFACE_TERRAINS'));
if(!noeud)throw Error('referentiel_surfaces_absent');vm.runInContext(pnj.slice(noeud.start,noeud.end),c);
const lignes=vm.runInContext(`Object.entries(WORLD).flatMap(([pays,villes])=>Object.entries(villes).flatMap(([ville,v])=>(v.buildings||[]).filter(id=>id.startsWith('terrain-a-batir')).map(id=>{
 const b=BUILDINGS[id],pieceId=Object.keys(b?.rooms||{})[0],piece=b?.rooms?.[pieceId];
 const ordre=ordresDeclaresDeLaPiece(piece||{},v.buildingContext?.[id],pieceId).find(o=>o.fn==='acheter_terrain');
 const surface=SURFACE_TERRAINS[id],prix=ordre?.cost;
 return {pays,ville,id,surface:typeof surface==='number'&&Number.isFinite(surface)&&surface>0?surface:null,
 prix:typeof prix==='number'&&Number.isSafeInteger(prix)&&prix>=0?prix:null};
}))).sort((a,b)=>[a.pays,a.ville,a.id].join('/').localeCompare([b.pays,b.ville,b.id].join('/')))`,c);
const cles=new Set();for(const r of lignes){const k=[r.pays,r.ville,r.id].join('/');if(cles.has(k))throw Error('parcelle_dupliquee');cles.add(k);}
if(!process.argv.includes('--sql')){process.stdout.write(JSON.stringify({parcelles:lignes,donneesManquantes:lignes.filter(r=>r.surface===null||r.prix===null)},null,2)+'\n');}
else{
 const q=s=>"'"+s.replaceAll("'","''")+"'";
 const valeurs=lignes.map(r=>'('+[q(r.pays),q(r.ville),q(r.id),r.surface??'NULL',r.prix??'NULL'].join(',')+')').join(',\n');
 process.stdout.write(`-- GENERE par outils/generateurs/generer_terrains_occupation.cjs --sql ; jamais de donnees joueur.
BEGIN;
CREATE TABLE IF NOT EXISTS public.terrains_referentiel (
 pays text NOT NULL,ville text NOT NULL,batiment text NOT NULL,surface numeric,prix_achat numeric,
 PRIMARY KEY(pays,ville,batiment),CHECK(surface IS NULL OR surface>0),
 CHECK(prix_achat IS NULL OR prix_achat>=0 AND prix_achat=trunc(prix_achat))
);
ALTER TABLE public.terrains_referentiel ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.terrains_referentiel FROM PUBLIC,anon,authenticated;
INSERT INTO public.terrains_referentiel(pays,ville,batiment,surface,prix_achat) VALUES
${valeurs}
ON CONFLICT(pays,ville,batiment) DO NOTHING;
DO $verification$ BEGIN
 IF EXISTS(WITH attendu(pays,ville,batiment,surface,prix_achat) AS (VALUES ${valeurs})
 SELECT 1 FROM attendu a LEFT JOIN public.terrains_referentiel r USING(pays,ville,batiment)
 WHERE r.batiment IS NULL OR r.surface IS DISTINCT FROM a.surface OR r.prix_achat IS DISTINCT FROM a.prix_achat)
 THEN RAISE EXCEPTION 'catalogue_terrain_divergent';END IF;
END;$verification$;
COMMIT;
`);
}
