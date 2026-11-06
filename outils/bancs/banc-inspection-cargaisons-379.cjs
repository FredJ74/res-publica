'use strict';
const {PGlite}=require('../vercel/node_modules/@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict');

(async()=>{
 const db=new PGlite();
 let n=0;
 const check=(v,msg)=>{assert.ok(v,msg);n++};
 try{
  await db.exec("CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;");
  await db.exec(`
   CREATE TABLE personnages_donnees(
    name text PRIMARY KEY,poste jsonb,country text,current_city text,
    current_building text,current_room text,stats jsonb,stats_affaiblies jsonb,
    effets_actifs jsonb,hp numeric,pa integer,resources jsonb,career text,
    moral numeric,arg numeric,liquide numeric,est_emprisonne jsonb);
   CREATE TABLE pnj_membres(leader_pj text,statut text,car_int integer);
   CREATE TABLE comptes_bancaires(personnage text,banque text,solde numeric);
   CREATE TABLE jauges_actions_recus(acteur text NOT NULL,requete uuid NOT NULL,
    ordre text NOT NULL,contexte jsonb NOT NULL,resultat jsonb NOT NULL,
    cree_le timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(acteur,requete));
   CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $x$ SELECT 'Fixture' $x$;
   CREATE FUNCTION payer_ordre(p_acteur text,p_fn text,p_pa integer,p_cost integer)
    RETURNS jsonb LANGUAGE plpgsql AS $x$
    DECLARE v integer;
    BEGIN
     IF p_fn<>'inspecter_cargaisons' OR p_pa<>2 OR p_cost<>0
      THEN RAISE EXCEPTION 'tarif';END IF;
     SELECT pa INTO v FROM personnages_donnees WHERE name=p_acteur FOR UPDATE;
     IF v<2 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants');END IF;
     UPDATE personnages_donnees SET pa=pa-2 WHERE name=p_acteur;
     RETURN jsonb_build_object('ok',true,'pa',v-2);
    END $x$;
   INSERT INTO personnages_donnees VALUES
    ('Fixture','{"id":"min_def"}','republic','port-sainte-marie',
     'port-sainte-marie','quai_principal','{"INT":12}','{}','[]',
     100,10,'{"pop":10,"inf":10}',null,50,100,100,null);
  `);
  const base=fs.readFileSync('migrations/20261103004219_jauges_ordres_transactionnels.sql','utf8');
  await db.exec(base.slice(base.indexOf('CREATE OR REPLACE FUNCTION')));
  const sql=fs.readFileSync('migrations/20261103203000_inspection_cargaisons_jauges_serveur_379.sql','utf8');
  await db.exec(sql); // prévol MD5 du corps précédent, puis installation complète
  const query=async(id,ctx={})=>(await db.query(
   'SELECT public.jauges_ordre_executer($1,$2,$3::jsonb) AS r',
   ['inspecter_cargaisons',id,JSON.stringify(ctx)])).rows[0].r;
  const id='11111111-1111-4111-8111-111111111111';
  const v=await query(id);
  check(v.ok===true,'success');check(v.contrat_jauges===1,'contract');
  check([-3,5].includes(v.gain_inf),'inf range');
  check(typeof v.inspection_reussie==='boolean','server roll');
  check(v.pa===8,'2 PA paid');
  const repeat=await query(id);
  check(repeat.ok===true&&repeat.rejeu===true,'anti replay');
  let p=(await db.query("SELECT pa,resources FROM personnages_donnees WHERE name='Fixture'")).rows[0];
  check(p.pa===8,'no duplicate payment');
  check(Number(p.resources.inf)===10+v.gain_inf,'no duplicate INF');
  const forged=await query('22222222-2222-4222-8222-222222222222',{gain_inf:99});
  check(forged.ok===false&&forged.raison==='contexte_invalide','client delta rejected');
  await db.exec("UPDATE personnages_donnees SET poste='{}' WHERE name='Fixture'");
  const denied=await query('33333333-3333-4333-8333-333333333333');
  check(denied.ok===false&&denied.raison==='poste_requis','server role check');
  p=(await db.query("SELECT pa FROM personnages_donnees WHERE name='Fixture'")).rows[0];
  check(p.pa===8,'denied does not debit');
  await db.exec("UPDATE personnages_donnees SET poste='{\"id\":\"min_def\"}',current_room='parking' WHERE name='Fixture'");
  const place=await query('44444444-4444-4444-8444-444444444444');
  check(place.ok===false&&place.raison==='pas_sur_place','actual port required');
  const src=fs.readFileSync('plateau-navigation.js','utf8');
  const f=src.slice(src.indexOf('async function doInspecterCargaisons('),
                   src.indexOf('// consulter_manifeste',src.indexOf('async function doInspecterCargaisons(')));
  check(f.includes("executerOrdreJaugesServeur('inspecter_cargaisons'"),'client uses server');
  check(!/state\.inf\s*=|Math\.random\(|deduireCoutOrdre\(/.test(f),'no client roll or INF');
  console.log(n+'/'+n+' tests inspection cargaisons, PGlite + client statique');
 }finally{await db.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
