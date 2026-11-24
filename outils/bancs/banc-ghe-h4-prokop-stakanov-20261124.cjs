'use strict';
// Mission « Purge » (Fred, 24/11/2026), point H.4 : l'habitué du Bar Sever s'appelle Prokop Stakanov ; 3 h entre deux
// visites, un verre par jour. L'identifiant technique « habitue_krasnov » reste (R4 : rien ne pointe dans le vide).
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const MIGRATION = 'migrations/20261124143000_ghe_h4_prokop_stakanov.sql';

test('H.4 — Prokop Stakanov partout côté écran et fiche, identifiant habitue_krasnov conservé', async () => {
  const d = lire('data.js');
  assert.match(d, /name: 'Prokop Stakanov \(PNJ\)', role: 'Habitué du bar', rel: 'friendly',\s+ancienNom: 'L’habitué du Bar Sever', job: 'habitue', profilId: 'habitue_krasnov'/);
  assert.doesNotMatch(d, /name: 'L’habitué du Bar Sever \(PNJ\)'/);
  const soc = lire('plateau-social-pnj.js');
  assert.match(soc, /pnj: 'Prokop Stakanov' \}/);
  assert.match(soc, /sbRpc\('habitue_krasnov_accueillir'/);
  const { TOUS_PROFILS } = await import(path.join(R, 'api/_pnj-profils.js'));
  assert.equal(TOUS_PROFILS.habitue_krasnov.nom, 'Prokop Stakanov');
  assert.match(TOUS_PROFILS.habitue_krasnov.caractere, /Tu es Prokop Stakanov, l'habitué du Bar Sever/);
  assert.equal(TOUS_PROFILS.prokop_stakanov.nom, 'Prokop Stakanov', 'l’identifiant du nom affiché renvoie à la fiche');
  const { SCENES_PNJ } = await import(path.join(R, 'api/_pnj-scenes-generes.js'));
  assert.ok(SCENES_PNJ[JSON.stringify(['soviet', 'ville_b', 'cafe-tabac-cheminots-montrouge', 'salle'])].personnes.includes('Prokop Stakanov'));
  const { NON_FONCTIONNAIRES } = await import(path.join(R, 'api/_pnj-fonctionnaires-sovarka.js'));
  assert.ok(NON_FONCTIONNAIRES.has('habitue_krasnov') && NON_FONCTIONNAIRES.has('prokop_stakanov'));
  assert.match(lire('outils/generateurs/generer-informateurs-lieux.cjs'), /nom: 'Prokop Stakanov', role: 'Habitué du bar'/);
  // L'informateur se retrouve par son identifiant, jamais par son nom.
  assert.match(lire('plateau-informateurs.js'), /pnj\.profilId === 'habitue_krasnov'/);
  // 3 h entre deux visites, un verre par jour : réglages MJ lus par la RPC.
  const bloc3 = lire('migrations/20261123211000_bloc3_pnj_habitue_sociaux.sql');
  assert.match(bloc3, /\('habitue_krasnov_verres_par_jour', 1,/);
  assert.match(bloc3, /\('habitue_krasnov_accueil_heures', 3,/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
test('H.4 — migration rejouable : nom de l’informateur et libellés MJ (PGlite)', { skip: !PGlite && 'PGlite absent (PGLITE_DIR)' }, async () => {
  const db = new PGlite();
  await db.exec(`CREATE TABLE public.informateurs_pnj (id text PRIMARY KEY, nom text);
    CREATE TABLE public.sante_parametres (cle text PRIMARY KEY, valeur numeric, groupe text, libelle text);
    INSERT INTO public.informateurs_pnj VALUES ('habitue_krasnov', 'L’habitué du Bar Sever'), ('autre', 'Grigori Zaitsev');
    INSERT INTO public.sante_parametres VALUES ('habitue_krasnov_verres_par_jour', 1, 'pnj', 'Verres offerts par l’habitué du Bar Sever (Krasnov), par PJ et par jour (0 = aucun)'),
      ('habitue_krasnov_accueil_heures', 3, 'pnj', 'Heures avant que l’habitué du Bar Sever accueille de nouveau le même PJ');`);
  await db.exec(lire(MIGRATION)); await db.exec(lire(MIGRATION));
  assert.equal((await db.query("SELECT nom FROM informateurs_pnj WHERE id = 'habitue_krasnov'")).rows[0].nom, 'Prokop Stakanov');
  assert.equal((await db.query("SELECT nom FROM informateurs_pnj WHERE id = 'autre'")).rows[0].nom, 'Grigori Zaitsev');
  const p = (await db.query("SELECT cle, valeur::int v, libelle FROM sante_parametres ORDER BY cle")).rows;
  assert.deepEqual(p.map(x => x.v), [3, 1]);
  assert.ok(p.every(x => x.libelle.includes('Prokop Stakanov')));
});
