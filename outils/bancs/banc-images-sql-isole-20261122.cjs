// Aucun Supabase : schéma de six tables fictives, illustration seule, rejeu et annulation.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),lire=f=>fs.readFileSync(path.join(root,f),'utf8');
const charger=process.env.PGLITE_DIR?require('node:module').createRequire(path.join(process.env.PGLITE_DIR,'index.js')):require;
let PGlite;try{({PGlite}=charger('@electric-sql/pglite'));}catch(e){if(process.env.PGLITE_DIR)throw e;test('SQL isolé exécuté par le workflow images (PGlite)',{skip:true},()=>{});return;}
test('SQL en attente : seize règles, mêmes objets, aucune écriture au rejeu, rollback intégral',async()=>{
 const db=new PGlite(),rules=JSON.parse(lire('outils/audits/images-cassees-20261122/corrections-base.json'));
 try{
 const tables=[...new Map(rules.map(r=>[r.table,r])).values()];
 await db.exec('CREATE TABLE ecritures (id integer); CREATE FUNCTION compter() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN INSERT INTO ecritures VALUES(NEW.id); RETURN NEW; END $$;');
 for(const r of tables){await db.exec(`CREATE TABLE "${r.table}" (id integer PRIMARY KEY, "${r.column}" ${r.type}); CREATE TRIGGER compter AFTER UPDATE ON "${r.table}" FOR EACH ROW EXECUTE FUNCTION compter();`);}
 for(const[i,r]of rules.entries()){
  const objet={imageUrl:r.old,nested:{imageUrl:r.old,qte:4},pa:70,argent:200,position:'témoin',texte:'Le chemin '+r.old+' reste dans le récit.'};
  await db.query(`INSERT INTO "${r.table}" (id,"${r.column}") VALUES($1,$2)`,[i,r.type==='text'?r.old:JSON.stringify(objet)]);
 }
 const sql=lire('migrations/20261122210046_correction_chemins_images_non_appliquee.sql');
 await db.exec('BEGIN');await db.exec(sql);
 for(const[i,r]of rules.entries()){
  const v=(await db.query(`SELECT "${r.column}" v FROM "${r.table}" WHERE id=$1`,[i])).rows[0].v;
  if(r.type==='text')assert.equal(v,r.new);
  else assert.deepEqual(v,{imageUrl:r.new,nested:{imageUrl:r.new,qte:4},pa:70,argent:200,position:'témoin',texte:'Le chemin '+r.old+' reste dans le récit.'});
 }
 const avant=(await db.query('SELECT count(*) n FROM ecritures')).rows[0].n;assert.equal(Number(avant),rules.length);
 await db.exec(sql);assert.equal((await db.query('SELECT count(*) n FROM ecritures')).rows[0].n,avant,'aucun UPDATE au deuxième passage');
 await db.exec('ROLLBACK');
 assert.equal(Number((await db.query('SELECT count(*) n FROM ecritures')).rows[0].n),0);
 for(const[i,r]of rules.entries()){const v=(await db.query(`SELECT "${r.column}" v FROM "${r.table}" WHERE id=$1`,[i])).rows[0].v;assert.equal(r.type==='text'?v:v.imageUrl,r.old);}
 }finally{await db.close();}
});
