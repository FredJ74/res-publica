const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),c=vm.createContext({window:{},console});vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),c);
const rows=vm.runInContext(`Object.entries(WORLD).flatMap(([pays,villes])=>Object.entries(villes).flatMap(([ville,v])=>(v.buildings||[]).flatMap(batiment=>Object.entries(BUILDINGS[batiment]?.rooms||{}).flatMap(([piece,r])=>(r.persons||[]).filter(p=>p.name&&!p.isPJ).map(p=>({pays,ville,batiment,piece,nom:p.name.replace(/ \\(PNJ\\)$/,''),stats:p.stats||{}}))))))`,c);
const map=new Map();for(const r of rows){const k=JSON.stringify([r.pays,r.ville,r.batiment,r.piece,r.nom]);if(map.has(k)&&JSON.stringify(map.get(k))!==JSON.stringify(r))throw Error('doublon divergent');map.set(k,r);}const lignes=[...map.values()];
if(!process.argv.includes('--sql'))process.stdout.write(JSON.stringify(lignes,null,2)+'\n');else{const q=x=>"'"+x.replaceAll("'","''")+"'";process.stdout.write(`-- GENERE depuis data.js par generer_vol_pnj_referentiel.cjs --sql.
BEGIN;
CREATE TABLE IF NOT EXISTS public.vol_pnj_referentiel(pays text,ville text,batiment text,piece text,nom text,stats jsonb NOT NULL,PRIMARY KEY(pays,ville,batiment,piece,nom));
ALTER TABLE public.vol_pnj_referentiel ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.vol_pnj_referentiel FROM PUBLIC,anon,authenticated,service_role;
DO $r$ DECLARE divergence boolean;BEGIN
 WITH attendu(pays,ville,batiment,piece,nom,stats) AS(VALUES ${lignes.map(r=>'('+['pays','ville','batiment','piece','nom'].map(k=>q(r[k])).join(',')+','+q(JSON.stringify(r.stats))+'::jsonb)').join(',\n')}),inseres AS(INSERT INTO public.vol_pnj_referentiel SELECT * FROM attendu ON CONFLICT DO NOTHING RETURNING *),effectif AS(SELECT * FROM public.vol_pnj_referentiel UNION ALL SELECT * FROM inseres)
 SELECT EXISTS(SELECT 1 FROM attendu a FULL JOIN effectif e USING(pays,ville,batiment,piece,nom) WHERE a.stats IS DISTINCT FROM e.stats) INTO divergence;
 IF divergence THEN RAISE EXCEPTION 'referentiel_vol_pnj_divergent';END IF;
END;$r$;
COMMIT;
`);}
