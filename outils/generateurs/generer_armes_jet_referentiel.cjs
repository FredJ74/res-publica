// Catalogue du chemin existant d'achat clandestin ; aucune règle ni valeur ajoutée.
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),source=fs.readFileSync(path.join(root,'plateau-actions-illegales-rumeurs.js'),'utf8');
const c=vm.createContext({window:{},console});vm.runInContext(fs.readFileSync(path.join(root,'data.js'),'utf8'),c);
for(const n of ['ARMES_CATALOGUE','ARMES_OVERRIDES_VILLE','BONUS_CARRIERE_VOL']){const a=source.indexOf('const '+n+' = ');if(a<0)throw Error(n);const b=source.indexOf('\n};',a);vm.runInContext(source.slice(a,b+3),c);}
const a=source.indexOf('function resoudreArmeAffichage('),b=source.indexOf('\n}\n',a);vm.runInContext(source.slice(a,b+2),c);
const rows=vm.runInContext(`Object.entries(WORLD).flatMap(([pays,villes])=>Object.entries(villes).flatMap(([ville,v])=>(v.buildings||[]).flatMap(batiment=>Object.entries(BUILDINGS[batiment]?.rooms||{}).flatMap(([piece,r])=>ordresDeclaresDeLaPiece(r,v.buildingContext?.[batiment],piece).filter(o=>o.fn==='choisir_arme').flatMap(()=> (ARMES_CATALOGUE[pays]||ARMES_CATALOGUE.republic).map(a=>{const x=resoudreArmeAffichage(a,ville);return {pays,ville,batiment,piece,arme:a.id,data:{objet:{type:'arme',sousType:a.type,name:x.name,icon:a.icon,desc:x.desc,legal:false,bonus:a.bonus,imageUrl:x.imageUrl},bonusCarrieres:BONUS_CARRIERE_VOL}}}))))))`,c);
const keys=new Set();for(const r of rows){const k=JSON.stringify([r.pays,r.ville,r.batiment,r.piece,r.arme]);if(keys.has(k))throw Error('doublon');keys.add(k);}
if(!process.argv.includes('--sql'))process.stdout.write(JSON.stringify(rows,null,2)+'\n');
else{const q=x=>"'"+x.replaceAll("'","''")+"'";const values=rows.map(r=>'('+['pays','ville','batiment','piece','arme'].map(k=>q(r[k])).join(',')+','+q(JSON.stringify(r.data))+'::jsonb)').join(',\n');process.stdout.write(`-- GENERE par generer_armes_jet_referentiel.cjs --sql depuis les déclarations existantes.
BEGIN;
CREATE TABLE IF NOT EXISTS public.armes_jets_referentiel(pays text,ville text,batiment text,piece text,arme text,data jsonb NOT NULL,PRIMARY KEY(pays,ville,batiment,piece,arme));
ALTER TABLE public.armes_jets_referentiel ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.armes_jets_referentiel FROM PUBLIC,anon,authenticated,service_role;
DO $r$ DECLARE divergent boolean;BEGIN
 WITH attendu(pays,ville,batiment,piece,arme,data) AS(VALUES ${values}),inseres AS(INSERT INTO public.armes_jets_referentiel SELECT * FROM attendu ON CONFLICT DO NOTHING RETURNING *),effectif AS(SELECT * FROM public.armes_jets_referentiel UNION ALL SELECT * FROM inseres) SELECT EXISTS(SELECT 1 FROM attendu a FULL JOIN effectif e USING(pays,ville,batiment,piece,arme) WHERE a.data IS DISTINCT FROM e.data) INTO divergent;
 IF divergent THEN RAISE EXCEPTION 'referentiel_armes_jets_divergent';END IF;
END;$r$;
COMMIT;
`);}
