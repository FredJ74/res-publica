'use strict';
// Garde négative : la fonction de fusion doit refuser un delta de jauge
// fabriqué par un navigateur, MÊME lorsque popBase/infBase est courant.
// Fermeture livrée par migrations/20261104000000_pop_inf_serveur_seul_379.sql (03/11/2026) :
// la variation du navigateur est IGNORÉE (valeur serveur conservée), la sauvegarde passe.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {PGlite}=require('../vercel/node_modules/@electric-sql/pglite');
async function fixture(strict=true){
 const db=new PGlite();
 await db.exec("CREATE TABLE public.personnages_donnees(name text PRIMARY KEY, resources jsonb NOT NULL DEFAULT '{}'::jsonb)");
 await db.exec("CREATE FUNCTION public.est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$");
 const migration=fs.readFileSync('migrations/20261103183000_pop_inf_refuser_deltas_perimes_379.sql','utf8');
 await db.exec(migration.slice(migration.indexOf('CREATE OR REPLACE FUNCTION')));
 if(strict){const m=fs.readFileSync('migrations/20261104000000_pop_inf_serveur_seul_379.sql','utf8');await db.exec(m.slice(m.indexOf('CREATE OR REPLACE FUNCTION')));}
 await db.exec("CREATE TRIGGER controle BEFORE UPDATE ON public.personnages_donnees FOR EACH ROW EXECUTE FUNCTION public.personnages_fusionner_pop()");
 await db.exec("INSERT INTO personnages_donnees VALUES ('Fixture','{\"pop\":10,\"inf\":10}')");
 await db.exec("SELECT set_config('request.path','/rest/v1/personnages_donnees',false)");
 return db;
}
for(const cle of ['pop','inf']){
 test('un ancien navigateur ne peut pas inventer '+cle+' avec une base courante',async()=>{
  const db=await fixture();
  try{
   const charge={pop:10,popBase:10,inf:10,infBase:10};
   charge[cle]=99;
   charge.dis=42;
   await db.query("UPDATE personnages_donnees SET resources=$1::jsonb WHERE name='Fixture'",[JSON.stringify(charge)]);
   const row=(await db.query("SELECT resources FROM personnages_donnees WHERE name='Fixture'")).rows[0];
   assert.equal(Number(row.resources[cle]),10,'jauge serveur modifiée par une sauvegarde générale');
   assert.equal(Number(row.resources.dis),42,'le reste de la sauvegarde doit passer');
   assert.equal(row.resources.popBase,undefined,'base du navigateur stockée');
   assert.equal(row.resources.infBase,undefined,'base du navigateur stockée');
  }finally{await db.close();}
 });
}

test('contre-preuve : le premier garde seul autorise encore un delta forge',async()=>{
 const db=await fixture(false);
 try{
  const charge={pop:99,popBase:10,inf:99,infBase:10};
  await db.query("UPDATE personnages_donnees SET resources=$1::jsonb WHERE name='Fixture'",[JSON.stringify(charge)]);
  const row=(await db.query("SELECT resources FROM personnages_donnees WHERE name='Fixture'")).rows[0];
  assert.equal(Number(row.resources.pop),99,'ancienne faille POP doit être reproduite');
  assert.equal(Number(row.resources.inf),99,'ancienne faille INF doit être reproduite');
 }finally{await db.close();}
});

test('base périmée, deux onglets : aucune variation client appliquée',async()=>{
 const db=await fixture();
 try{
  await db.query("UPDATE personnages_donnees SET resources=$1::jsonb WHERE name='Fixture'",[JSON.stringify({pop:3,popBase:50,inf:80,infBase:1})]);
  const row=(await db.query("SELECT resources FROM personnages_donnees WHERE name='Fixture'")).rows[0];
  assert.equal(Number(row.resources.pop),10); assert.equal(Number(row.resources.inf),10);
 }finally{await db.close();}
});

test('une commande serveur (/rpc/) écrit toujours ses jauges',async()=>{
 const db=await fixture();
 try{
  await db.exec("SELECT set_config('request.path','/rpc/jauges_ordre_executer',false)");
  await db.query("UPDATE personnages_donnees SET resources=$1::jsonb WHERE name='Fixture'",[JSON.stringify({pop:17,inf:12})]);
  const row=(await db.query("SELECT resources FROM personnages_donnees WHERE name='Fixture'")).rows[0];
  assert.equal(Number(row.resources.pop),17); assert.equal(Number(row.resources.inf),12);
 }finally{await db.close();}
});
