'use strict';
const fs=require('node:fs');
const assert=require('node:assert/strict');
const {PGlite}=require('../vercel/node_modules/@electric-sql/pglite');
(async()=>{
 const db=new PGlite();
 let tests=0;
 const yes=(v,msg)=>{assert.ok(v,msg);tests++};
 try{
  await db.exec(`CREATE SCHEMA auth;
   CREATE TABLE public.personnages_donnees (
     name text PRIMARY KEY, user_id uuid, poste text, country text,
     pa integer, resources jsonb, est_emprisonne jsonb);
   CREATE TABLE public.demandes_grace(id text PRIMARY KEY,statut text,data jsonb);
   CREATE TABLE public.prisonniers_qhs(nom text PRIMARY KEY,statut text);
   CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
    $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
   CREATE FUNCTION public.est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
   CREATE FUNCTION public.exiger_poste(p_poste text) RETURNS text LANGUAGE plpgsql AS $$
   DECLARE v_nom text; BEGIN
     SELECT name INTO v_nom FROM public.personnages_donnees WHERE poste=p_poste AND user_id=auth.uid();
     IF v_nom IS NULL THEN RAISE EXCEPTION 'autorite_insuffisante' USING ERRCODE='42501';END IF;
     RETURN v_nom; END $$;
   CREATE FUNCTION public.payer_ordre_interne(p_acteur text,p_fn text,p_pa integer,p_cost integer)
   RETURNS jsonb LANGUAGE plpgsql AS $$
   DECLARE v_pa integer;BEGIN
     IF p_fn<>'gracier' OR p_pa<>2 OR p_cost<>0 THEN RAISE EXCEPTION 'tarif_invalide';END IF;
     SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
     IF v_pa<p_pa THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants');END IF;
     UPDATE public.personnages_donnees SET pa=pa-p_pa WHERE name=p_acteur;
     RETURN jsonb_build_object('ok',true,'pa',v_pa-p_pa);END $$;
   CREATE FUNCTION public.detention_clore_interne(p_nom text,p_mode text,p_jour integer)
   RETURNS jsonb LANGUAGE plpgsql AS $$
   BEGIN
    UPDATE public.personnages_donnees SET est_emprisonne=NULL WHERE name=p_nom;
    UPDATE public.prisonniers_qhs SET statut='libere' WHERE nom=p_nom;
    RETURN jsonb_build_object('qhs_libere',true);END $$;`);
  const sql=fs.readFileSync('migrations/20261103133000_grace_presidentielle_transactionnelle_379.sql','utf8');
  await db.exec(sql.slice(sql.indexOf('CREATE OR REPLACE FUNCTION'),sql.indexOf('REVOKE ALL ON FUNCTION')));
  await db.exec(`INSERT INTO public.personnages_donnees VALUES
   ('Président','11111111-1111-4111-8111-111111111111','president','republic',10,'{"pop":52,"inf":10}',NULL),
   ('Cible','22222222-2222-4222-8222-222222222222',NULL,'republic',10,'{}','{"qhs":true}'),
   ('Intrus','33333333-3333-4333-8333-333333333333',NULL,'republic',10,'{}',NULL);
  INSERT INTO public.demandes_grace VALUES
   ('g1','attente','{"pays":"republic","nomCondamne":"Cible"}'),
   ('g2','attente','{"pays":"republic","nomCondamne":"Cible"}'),
   ('g3','attente','{"pays":"republic","nomCondamne":"Cible"}'),
   ('g4','attente','{"pays":"soviet","nomCondamne":"Cible"}');
  INSERT INTO public.prisonniers_qhs VALUES('Cible','detenu');`);
  const query=async(s,params=[])=> (await db.query(s,params)).rows[0];
  const verdict=async(id,decision)=>(await query('SELECT public.grace_presidentielle_decider($1,$2) AS v',[id,decision])).v;
  await db.exec("SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false)");
  let v=await verdict('g1',true);
  yes(v.ok===true&&v.libere===true&&v.pop_delta===5,'grace accordee');
  let president=await query("SELECT pa,resources FROM public.personnages_donnees WHERE name='Président'");
  yes(president.pa===8&&Number(president.resources.pop)===57,'PA et POP transactionnels');
  yes((await query("SELECT est_emprisonne FROM personnages_donnees WHERE name='Cible'")).est_emprisonne===null,'detenu libere');
  yes((await query("SELECT statut FROM prisonniers_qhs WHERE nom='Cible'")).statut==='libere','QHS libere');
  v=await verdict('g1',true);
  yes(v.ok===true&&v.rejoue===true,'rejeu neutralise');
  president=await query("SELECT pa,resources FROM personnages_donnees WHERE name='Président'");
  yes(president.pa===8&&Number(president.resources.pop)===57,'aucun second debit POP ou PA');
  v=await verdict('g2',false);
  yes(v.ok===true&&v.statut==='refusee','refus enregistré');
  yes((await query("SELECT pa FROM personnages_donnees WHERE name='Président'")).pa===6,'refus paye une fois');
  v=await verdict('g2',false);
  yes(v.rejoue===true&&(await query("SELECT pa FROM personnages_donnees WHERE name='Président'")).pa===6,'refus non rejoue');
  v=await verdict('g4',true);
  yes(v.ok===false&&v.raison==='hors_pays','dossier hors pays refuse');
  await db.exec("UPDATE personnages_donnees SET pa=1 WHERE name='Président'");
  v=await verdict('g3',false);
  yes(v.ok===false&&v.raison==='pa_insuffisants','fonds PA insuffisants');
  yes((await query("SELECT statut FROM demandes_grace WHERE id='g3'")).statut==='attente','dossier intact si PA manquants');
  await db.exec("SELECT set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false)");
  let denied=false;
  try{await verdict('g3',false)}catch(e){denied=/autorite_insuffisante/.test(e.message)}
  yes(denied,'PJ sans présidence refuse');
  await db.exec("SELECT set_config('request.jwt.claim.sub','',false)");
  v=await verdict('g3',false);
  yes(v.ok===false&&v.raison==='acteur_non_authentifie','anonyme refuse');
  yes(sql.includes('REVOKE ALL ON FUNCTION public.presidence_gracier(text,integer)'),'ancienne porte fermee par la migration');
  console.log(tests+'/'+tests+' contre-épreuves grâce SQL isolées réussies');
 }finally{await db.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
