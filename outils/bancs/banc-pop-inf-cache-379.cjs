'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {PGlite}=require('../vercel/node_modules/@electric-sql/pglite');
(async()=>{
  const db=new PGlite();
  try {
    await db.exec("CREATE TABLE public.personnages_donnees(name text PRIMARY KEY,resources jsonb NOT NULL DEFAULT '{}'::jsonb);");
    await db.exec("CREATE FUNCTION public.est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;");
    const migration=fs.readFileSync('migrations/20261103183000_pop_inf_refuser_deltas_perimes_379.sql','utf8');
    // Reproduction de la faille sur le corps EXACT extrait de production (sans aucun compte réel).
    const legacy=fs.readFileSync('outils/bancs/fixtures/personnages_fusionner_pop-prod-20261103.sql','utf8');
    await db.exec(legacy);

    await db.exec("CREATE TRIGGER pop_inf_test BEFORE UPDATE ON public.personnages_donnees FOR EACH ROW EXECUTE FUNCTION public.personnages_fusionner_pop()");
    await db.exec("INSERT INTO personnages_donnees VALUES('Fixture','{\"pop\":10,\"inf\":10}');");
    await db.exec("SELECT set_config('request.path','/rest/v1/personnages_donnees',false)");
    const legacyPayload=JSON.stringify({pop:15,popBase:10,inf:10,infBase:10});
    await db.query("UPDATE personnages_donnees SET resources=$1::jsonb WHERE name='Fixture'",[legacyPayload]);
    await db.query("UPDATE personnages_donnees SET resources=$1::jsonb WHERE name='Fixture'",[legacyPayload]);
    const doublon=(await db.query("SELECT (resources->>'pop')::numeric AS pop FROM personnages_donnees WHERE name='Fixture'")).rows[0].pop;
    assert.equal(Number(doublon),20,'la fonction historique doit reproduire 15 vers 20');
    await db.exec("DELETE FROM personnages_donnees WHERE name='Fixture'");
    await db.exec("INSERT INTO personnages_donnees VALUES('Fixture','{\"pop\":10,\"inf\":10}');");
    const legacyInf=JSON.stringify({pop:10,popBase:10,inf:15,infBase:10});
    await db.query("UPDATE personnages_donnees SET resources=$1::jsonb WHERE name='Fixture'",[legacyInf]);
    await db.query("UPDATE personnages_donnees SET resources=$1::jsonb WHERE name='Fixture'",[legacyInf]);
    assert.equal(Number((await db.query("SELECT (resources->>'inf')::numeric AS inf FROM personnages_donnees WHERE name='Fixture'")).rows[0].inf),20,'ancienne INF doublee');
    await db.exec("DELETE FROM personnages_donnees WHERE name='Fixture'");
    await db.exec("INSERT INTO personnages_donnees VALUES('Fixture','{\"pop\":10,\"inf\":10}');");
    await db.exec(migration.slice(migration.indexOf('CREATE OR REPLACE FUNCTION')));
    let tests=2;
    const row=async()=>JSON.parse(JSON.stringify((await db.query("SELECT resources FROM personnages_donnees WHERE name='Fixture'")).rows[0].resources));
    const update=async json=>db.query('UPDATE personnages_donnees SET resources=$1::jsonb WHERE name=\'Fixture\'',[JSON.stringify(json)]);
    const check=async(v,msg)=>{assert.deepEqual(await row(),v,msg);tests++};
    const refuse=async (json,regex)=>{
      let threw=false;
      try{await update(json)}catch(e){threw=true;assert.match(e.message,regex)}
      assert.equal(threw,true,'expected stale rejection');tests++;
    };
    await db.exec("SELECT set_config('request.path','/rest/v1/personnages_donnees',false)");
    await update({pop:15,popBase:10,inf:10,infBase:10});
    await check({pop:15,inf:10},'premier navigateur');
    await refuse({pop:15,popBase:10,inf:10,infBase:10},/379_pop_base_perimee/);
    await check({pop:15,inf:10},'second onglet refuse');
    await db.exec("SELECT set_config('request.path','/rpc/tracts_appliquer_effet_pop',false)");
    await update({pop:20,inf:10});
    await db.exec("SELECT set_config('request.path','/rest/v1/personnages_donnees',false)");
    await refuse({pop:15,popBase:10,inf:10,infBase:10},/379_pop_base_perimee/);
    await check({pop:20,inf:10},'serveur 20 jamais double');
    await update({pop:10,popBase:10,inf:10,infBase:10});
    await check({pop:20,inf:10},'delta nul est accepte');
    await db.exec("SELECT set_config('request.path','/rpc/tracts_appliquer_effet_pop',false)");
    await update({pop:20,inf:15});
    await db.exec("SELECT set_config('request.path','/rest/v1/personnages_donnees',false)");
    await refuse({pop:20,popBase:20,inf:15,infBase:10},/379_inf_base_perimee/);
    await check({pop:20,inf:15},'INF ancien cache refuse');
    await refuse({pop:20,popBase:'10',inf:15,infBase:15},/379_pop_base_invalide/);
    await check({pop:20,inf:15},'base malformee refusee');
    await update({pop:20,popBase:20,inf:17,infBase:15});
    await check({pop:20,inf:17},'gain legitime INF conserve si base courante');
    await refuse({pop:20,popBase:20,inf:17,infBase:15},/379_inf_base_perimee/);
    await check({pop:20,inf:17},'deuxieme onglet INF rejete');
    await db.exec("SELECT set_config('request.path','/rpc/ordres',false)");
    await update({pop:25,inf:17});
    await check({pop:25,inf:17},'commande serveur conservee');
    await refuse({pop:26,popBase:20,inf:17,infBase:17},/379_pop_base_perimee/);
    await check({pop:25,inf:17},'RPC ne contourne pas le conflit ancien cache');
    console.log(tests+'/'+tests+' tests PostgreSQL PGlite passed');
  } finally{await db.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
