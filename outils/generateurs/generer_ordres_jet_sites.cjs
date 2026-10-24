// Emplacements et coûts déjà déclarés des actes à jet : aucune mécanique ni valeur ajoutée.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({window:{},console});vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),c);
const lignes=vm.runInContext(`Object.entries(WORLD).flatMap(([pays,villes])=>Object.entries(villes).flatMap(([ville,v])=>(v.buildings||[]).flatMap(batiment=>Object.entries(BUILDINGS[batiment]?.rooms||{}).flatMap(([piece,r])=>ordresDeclaresDeLaPiece(r,v.buildingContext?.[batiment],piece).filter(o=>['mener_enquete','organiser_filature','organiser_chasse_homme','tentative_evasion','voler_materiel_chantier'].includes(o.fn)).map(o=>({pays,ville,batiment,piece,ordre:o.fn,pa:o.pa,cout:o.cost,poste:o.requiresPost||null,caisse:o.requiresPost==='commissaire'?pays+'_'+caisseTerritorialeId('commissariat',ville):null})))))).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)))`,c);
const cles=new Set();for(const r of lignes){if(!Number.isSafeInteger(r.pa)||r.pa<0||!Number.isSafeInteger(r.cout)||r.cout<0)throw Error('cout_non_reference');const k=JSON.stringify([r.pays,r.ville,r.batiment,r.piece,r.ordre]);if(cles.has(k))throw Error('ordre_duplique');cles.add(k);}
if(!process.argv.includes('--sql'))process.stdout.write(JSON.stringify(lignes,null,2)+'\n');
else{
 const q=x=>x===null?'NULL':typeof x==='number'?String(x):"'"+x.replaceAll("'","''")+"'";
 const valeurs=lignes.map(r=>'('+['pays','ville','batiment','piece','ordre','pa','cout','poste','caisse'].map(k=>q(r[k])).join(',')+')').join(',\n');
 process.stdout.write(`-- GENERE depuis data.js par outils/generateurs/generer_ordres_jet_sites.cjs --sql.
BEGIN;
CREATE TABLE IF NOT EXISTS public.ordres_jets_sites(pays text,ville text,batiment text,piece text,ordre text,pa integer NOT NULL CHECK(pa>=0),cout integer NOT NULL CHECK(cout>=0),poste text,caisse text,PRIMARY KEY(pays,ville,batiment,piece,ordre));
ALTER TABLE public.ordres_jets_sites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ordres_jets_sites FROM PUBLIC,anon,authenticated,service_role;
DO $catalogue$ DECLARE n integer;BEGIN
 WITH attendu(pays,ville,batiment,piece,ordre,pa,cout,poste,caisse) AS(VALUES ${valeurs}),
 inseres AS(INSERT INTO public.ordres_jets_sites SELECT * FROM attendu ON CONFLICT(pays,ville,batiment,piece,ordre) DO NOTHING RETURNING *),
 effectif AS(SELECT * FROM public.ordres_jets_sites UNION ALL SELECT * FROM inseres)
 SELECT count(*) INTO n FROM attendu a FULL JOIN effectif r USING(pays,ville,batiment,piece,ordre)
 WHERE a.pa IS DISTINCT FROM r.pa OR a.cout IS DISTINCT FROM r.cout OR a.poste IS DISTINCT FROM r.poste OR a.caisse IS DISTINCT FROM r.caisse;
 IF n>0 THEN RAISE EXCEPTION 'referentiel_sites_jets_divergent';END IF;
END;$catalogue$;
COMMIT;
`);
}
