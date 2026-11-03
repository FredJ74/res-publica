'use strict';
// Garde négative : la fonction de fusion doit refuser un delta de jauge
// fabriqué par un navigateur, MÊME lorsque popBase/infBase est courant.
// Ce banc est intentionnellement BLOQUANT tant que tous les producteurs
// légitimes n'ont pas été portés vers les commandes serveur.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {PGlite}=require('../vercel/node_modules/@electric-sql/pglite');
async function fixture(){
 const db=new PGlite();
 await db.exec("CREATE TABLE public.personnages_donnees(name text PRIMARY KEY, resources jsonb NOT NULL DEFAULT '{}'::jsonb)");
 await db.exec("CREATE FUNCTION public.est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$");
 const migration=fs.readFileSync('migrations/20261103183000_pop_inf_refuser_deltas_perimes_379.sql','utf8');
 await db.exec(migration.slice(migration.indexOf('CREATE OR REPLACE FUNCTION')));
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
   let refuse=false;
   try{
    await db.query("UPDATE personnages_donnees SET resources=$1::jsonb WHERE name='Fixture'",[JSON.stringify(charge)]);
   }catch(e){refuse=true;}
   const row=(await db.query("SELECT resources FROM personnages_donnees WHERE name='Fixture'")).rows[0];
   assert.equal(refuse,true,'un client a pu imposer '+cle+' sans preuve serveur');
   assert.equal(Number(row.resources[cle]),10,'jauge serveur modifiée illégitimement');
  }finally{await db.close();}
 });
}
