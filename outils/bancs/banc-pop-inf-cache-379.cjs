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
    await db.exec(migration.slice(migration.indexOf('CREATE OR REPLACE FUNCTION')));
    await db.exec("CREATE TRIGGER pop_inf_test BEFORE UPDATE ON public.personnages_donnees FOR EACH ROW EXECUTE FUNCTION public.personnages_fusionner_pop()");
    await db.exec("INSERT INTO personnages_donnees VALUES('Fixture','{\"pop\":10,\"inf\":10}');");
    let tests=0;
    const row=async()=>JSON.parse(JSON.stringify((await db.query("SELECT resources FROM personnages_donnees WHERE name='Fixture'")).rows[0].resources));
    const update=async json=>db.query('UPDATE personnages_donnees SET resources=$1::jsonb WHERE name=\'Fixture\'',[JSON.stringify(json)]);
    const check=async(v,msg)=>{assert.deepEqual(await row(),v,msg);tests++};
    const refuse=async (json,regex)=>{
      let threw=false;
      try{await update(json)}catch(e){threw=true;assert.match(e.message,regex)}
      assert.equal(threw,true,'expected stale rejection');tests++;¶»§q«^