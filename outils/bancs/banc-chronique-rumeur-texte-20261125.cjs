'use strict';
// Mission de fin de soirée du 25/11/2026, point 3.1 (décision de Fred) : dans « L'empire », une rumeur est citée avec son
// texte (600 caractères au plus), l'auteur restant anonyme tant qu'il n'est pas identifié ; le texte est un texte de joueur,
// échappé puis confié à l'affichage des textes de joueurs (traduction et « Voir l'original »). Migration 20261125860000.
// Usage : PGLITE_DIR=<…/node_modules/@electric-sql/pglite> node --test outils/bancs/banc-chronique-rumeur-texte-20261125.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG_CHRONIQUE = 'migrations/20261125200000_chronique_empire.sql', MIG = 'migrations/20261125860000_chronique_rumeur_texte.sql';

// Faux document : assez pour poser la chronique et lire les citations de rumeur.
function ecran() {
  const noeuds = [];
  class El {
    constructor(tag) { this.tagName = tag; this.dataset = {}; this.attrs = {}; this.hidden = false; this.textContent = ''; this.isConnected = true; this.ecoute = []; }
    setAttribute(k, v) { this.attrs[k] = String(v); } removeAttribute(k) { delete this.attrs[k]; }
    addEventListener(t, fn) { this.ecoute.push(fn); } removeEventListener(t, fn) { this.ecoute = this.ecoute.filter(x => x !== fn); }
    click() { this.ecoute.slice().forEach(fn => fn({})); }
  }
  const zone = {
    set innerHTML(h) {
      this._h = h; noeuds.length = 0;
      for (const m of h.matchAll(/<q class="hg-chron-rumeur" data-ref="([^"]*)">([\s\S]*?)<\/q> <button type="button" class="hg-chron-original" data-ref="([^"]*)" hidden><\/button>/g)) {
        const q = new El('q'); q.dataset.ref = m[1]; q.textContent = m[2]; q.cls = 'hg-chron-rumeur';
        const b = new El('button'); b.dataset.ref = m[3]; b.hidden = true; b.cls = 'hg-chron-original';
        noeuds.push(q, b);
      }
    },
    get innerHTML() { return this._h; },
    querySelectorAll(sel) { return noeuds.filter(n => sel === 'q.hg-chron-rumeur' ? n.cls === 'hg-chron-rumeur' : n.cls === 'hg-chron-original'); }
  };
  const doc = { readyState: 'complete', getElementById: id => (id === 'journal-empire' ? zone : null), querySelector: () => null, querySelectorAll: () => [],
    head: { appendChild() {} }, addEventListener() {}, createElement: () => new El('div') };
  const ctx = { console, Promise, Map, Array, Set, String, document: doc };
  ctx.window = ctx; vm.createContext(ctx);
  ctx.WORLD = { soviet: { capitale: { name: 'Novomirsk' } } };
  ctx.BUILDINGS = { marche: { name: 'Marché de Novomirsk', shortName: 'Marché' } };
  ctx.state = { country: 'republic', currentCity: 'capitale' };
  ctx.RP_I18N_LANGUAGES = { fr: {}, en: {} };
  vm.runInContext(lire('i18n/texte-joueur.js'), ctx);
  vm.runInContext(lire('plateau-chronique-empire.js'), ctx);
  return { ctx, zone, noeuds };
}

// Avant la première lecture serveur, le pays n'est pas connu : la ville s'affiche par son identifiant (comme le banc du 25/11).
test('écran : la rumeur citée en toutes lettres, échappée, auteur anonyme tant que le serveur ne le nomme pas', () => {
  const { ctx } = ecran();
  const C = ctx.RPChroniqueEmpire;
  const p = C.phrase({ cat: 'acte', cle: 'fausse_rumeur', ville: 'capitale', batiment: 'marche', auteur: null, ref: 'acte-7',
    params: { cible: 'Ivan', texte: 'Ivan <b>vole</b> les tickets de la Distribution', annonce: 41 } });
  assert.match(p, /^Une rumeur circule à Marché, capitale : « <q class="hg-chron-rumeur" data-ref="acte-7">Ivan &lt;b&gt;vole&lt;\/b&gt; les tickets de la Distribution<\/q>/);
  assert.match(p, /<button type="button" class="hg-chron-original" data-ref="acte-7" hidden><\/button> »$/);
  assert.doesNotMatch(p, /<b>vole/, 'le texte du joueur est échappé');
  const nomme = C.phrase({ cat: 'acte', cle: 'fausse_rumeur', ville: 'capitale', batiment: 'marche', auteur: 'Ivan', ref: 'acte-8', params: { texte: 'x'.repeat(700) } });
  assert.match(nomme, /^<b>Ivan<\/b> fait circuler une rumeur à /);
  assert.ok(!nomme.includes('x'.repeat(600)), 'au plus 600 caractères (599 et l’ellipse)');
  // Sans texte (rumeur d'avant la migration, ou migration absente) : la phrase d'avant.
  assert.equal(C.phrase({ cat: 'acte', cle: 'fausse_rumeur', ville: 'capitale', batiment: 'marche', auteur: null, params: { cible: 'Sovarka' } }),
    'Une rumeur calomnieuse sur Sovarka circule à Marché, capitale.');
});

test('écran : rumeur ratée, « une rumeur a couru, mais personne n’a su dire laquelle » (Fred, 26/11)', () => {
  const C = ecran().ctx.RPChroniqueEmpire;
  const p = C.phrase({ cat: 'acte', cle: 'fausse_rumeur', ville: 'capitale', batiment: 'marche', auteur: null, params: { issue: 'echec', ratee: true } });
  assert.match(p, /^Une rumeur a couru .*, mais personne n'a su dire laquelle\.$/);
  assert.doesNotMatch(p, /calomnieuse|«/);
});

test('écran : traduction automatique par le service des textes de joueurs, « Voir l’original » qui bascule', async () => {
  const { ctx, noeuds } = ecran();
  const demandes = [];
  ctx.RPPlateauI18n = { language: () => 'en', translate: k => k };
  ctx.RPTraductionTexteJoueur = { traduire: async a => { demandes.push(a); return { ok: true, traduit: '🗯 Ivan steals the Distribution tickets' }; } };
  ctx.sbRpc = async () => ({ ok: true, pays: 'soviet', faits: [{ quand: new Date().toISOString(), cat: 'acte', cle: 'fausse_rumeur', ville: 'capitale', batiment: 'marche',
    auteur: null, ref: 'acte-7', params: { texte: 'Ivan vole les tickets de la Distribution', annonce: 41 } }] });
  await ctx.RPChroniqueEmpire.charger(false);
  await new Promise(r => setTimeout(r, 10));
  assert.deepEqual(JSON.parse(JSON.stringify(demandes)), [{ type: 'annonce_publique', id: '41', field: 'texte', langueCible: 'en' }],
    'la source est l’annonce publique de la rumeur, jamais le texte envoyé par l’écran');
  const [q, b] = noeuds;
  assert.equal(q.textContent, 'Ivan steals the Distribution tickets', 'traduction affichée, sans le préfixe de la place publique');
  assert.equal(b.hidden, false); assert.equal(b.textContent, 'Voir l’original');
  b.click();
  assert.equal(q.textContent, 'Ivan vole les tickets de la Distribution', 'un seul clic suffit (une seule bascule attachée)');
  assert.equal(b.textContent, 'Voir la traduction');
});

test('écran : sans service de traduction, l’original reste affiché et le lien caché', async () => {
  const { ctx, noeuds } = ecran();
  ctx.sbRpc = async () => ({ ok: true, pays: 'soviet', faits: [{ quand: new Date().toISOString(), cat: 'acte', cle: 'fausse_rumeur', ville: 'capitale',
    batiment: 'marche', auteur: null, ref: 'acte-9', params: { texte: 'Le maire boit', annonce: 3 } }] });
  await ctx.RPChroniqueEmpire.charger(false);
  assert.equal(noeuds[0].textContent, 'Le maire boit'); assert.equal(noeuds[1].hidden, true);
  assert.match(lire('api/_traduction-sources.js'), /annonce_publique: Object\.freeze\(\{table:'evenements_globaux',id:'id',fields:Object\.freeze\(\['texte'\]\)/);
  assert.match(lire('plateau.html'), /plateau-chronique-empire\.js\?v=20261125-rumeur/);
});

const charger = process.env.PGLITE_DIR ? require('node:module').createRequire(path.join(process.env.PGLITE_DIR, 'index.js')) : require;
let PGlite = null;
try { ({ PGlite } = charger('@electric-sql/pglite')); } catch (_) { PGlite = null; }
if (!PGlite) { test('PGlite absent : partie SQL exécutée avec PGLITE_DIR', { skip: true }, () => {}); return; }

// Socle de la chronique (comme banc-chronique-empire-pglite-20261125.cjs), plus details sur crim_affaires, l'annonce publique
// et une rumeur_lancer réduite qui porte la ligne d'annonce de production telle quelle (ancrage du remplacement contrôlé).
const SOCLE = String.raw`
CREATE ROLE authenticated; CREATE ROLE anon;
CREATE TABLE personnages_donnees (name text PRIMARY KEY, country text, nationalite text);
CREATE TABLE comptes_test (personnage text PRIMARY KEY);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('banc.moi', true), '') $$;
CREATE FUNCTION personnage_nationalite(p text) RETURNS text LANGUAGE sql STABLE AS $$ SELECT coalesce(nationalite, country) FROM personnages_donnees WHERE name = p $$;
CREATE FUNCTION est_compte_test(p text) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT p IS NOT NULL AND EXISTS (SELECT 1 FROM comptes_test WHERE personnage = p) $$;
CREATE TABLE crim_affaires (id bigserial PRIMARY KEY, acte text, auteur text, cible text, cible_pnj text, pays text, ville text, batiment text, piece text,
  issue text, detecte boolean, identifie boolean, plainte_id text, details jsonb, cree_le timestamptz DEFAULT now(), archivee_le timestamptz);
CREATE TABLE detentions (id text PRIMARY KEY, country text, city text, nom text, raison text, qhs boolean DEFAULT false, motifs jsonb, created_at timestamptz DEFAULT now());
CREATE TABLE jugements (id text PRIMARY KEY, country text, city text, accuse text, motif text, peine text, data jsonb, created_at timestamptz DEFAULT now());
CREATE TABLE plaintes_en_cours (id text PRIMARY KEY, country text, city text, data text, created_at timestamptz DEFAULT now());
CREATE TABLE chronique_nationale (id text PRIMARY KEY, country text, type text, city text, personnages jsonb, libelle text, created_at timestamptz DEFAULT now());
CREATE TABLE climat_evenements (id bigserial PRIMARY KEY, type text, pays text, ville text, debut timestamptz, annule boolean DEFAULT false, alerte_le timestamptz);
CREATE TABLE batailles (id bigserial PRIMARY KEY, pays text, ville text, batiment text, piece text, debut_ts timestamptz, statut text, issue text,
  leader_a text, leader_b text, contexte jsonb);
CREATE TABLE sovarka_foret_rencontres (id bigserial PRIMARY KEY, bucheron text, creature text, statut text, cree_le timestamptz DEFAULT now());
CREATE TABLE evenements_globaux (id bigserial PRIMARY KEY, country text, city text, texte text, jour integer, created_at timestamptz DEFAULT now());
CREATE FUNCTION jour_de_jeu_pays(p text) RETURNS integer LANGUAGE sql STABLE AS $$ SELECT 12 $$;
CREATE FUNCTION annonce_publique_interne(p_pays text, p_texte text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO evenements_globaux (country, city, texte, jour) VALUES (p_pays, NULL, p_texte, jour_de_jeu_pays('republic')) $$;
CREATE FUNCTION rumeur_lancer(p_type text, p_cible text, p_texte text, p_cible_trace text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $function$
DECLARE r jsonb; v_reussi boolean; v_id bigint;
BEGIN
  INSERT INTO crim_affaires (acte, auteur, cible, pays, ville, batiment, issue, detecte, identifie)
  VALUES ('fausse_rumeur', mon_personnage(), p_cible, 'soviet', 'capitale', 'marche', CASE WHEN p_pa = 1 THEN 'reussite' ELSE 'echec' END, false, false)
  RETURNING id INTO v_id;
  r := jsonb_build_object('affaire', v_id, 'reussi', p_pa = 1);
  v_reussi := (r ->> 'reussi')::boolean;
  IF v_reussi THEN
    PERFORM public.annonce_publique_interne('global', '🗯 ' || left(p_texte, 600));
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'affaire', v_id);
END $function$;
INSERT INTO personnages_donnees VALUES ('Lecteur', 'soviet', 'soviet'), ('Ivan', 'soviet', 'soviet');`;
async function base() {
  const db = new PGlite();
  await db.exec(SOCLE);
  await db.exec(lire(MIG_CHRONIQUE));
  await db.exec(lire(MIG));
  return db;
}
const lireChronique = async (db, qui) => {
  await db.query("SELECT set_config('banc.moi', $1, false)", [qui]);
  return (await db.query('SELECT chronique_empire_lire() r')).rows[0].r;
};

test('serveur : la rumeur qui circule garde son texte (600 caractères) et son annonce ; ratée, aucun texte ; auteur anonyme', async () => {
  const db = await base();
  await db.query("SELECT set_config('banc.moi', 'Ivan', false)");
  const long = 'Le directeur du kolkhoze <cache> du grain. ' + 'x'.repeat(700);
  await db.query('SELECT rumeur_lancer($1, $2, $3, $4, 1, 0)', ['pj', 'Lecteur', long, 'Lecteur']);
  await db.query('SELECT rumeur_lancer($1, $2, $3, $4, 2, 0)', ['pj', 'Lecteur', 'Rumeur ratée', 'Lecteur']);
  const annonces = (await db.query('SELECT id, country, texte, jour FROM evenements_globaux')).rows;
  assert.equal(annonces.length, 1, 'une seule annonce publique, comme avant');
  assert.equal(annonces[0].country, 'global'); assert.equal(annonces[0].jour, 12);
  assert.equal(annonces[0].texte, '🗯 ' + long.slice(0, 600), 'annonce identique à celle d’avant');
  const r = await lireChronique(db, 'Lecteur');
  const rumeurs = r.faits.filter(x => x.cat === 'acte');
  assert.equal(rumeurs.length, 2, 'les deux rumeurs restent citées (une rumeur circule par nature)');
  const ok = rumeurs.find(x => x.params.texte), ko = rumeurs.find(x => !x.params.texte);
  assert.equal(ok.params.texte, long.slice(0, 600).trim());
  assert.equal(Number(ok.params.annonce), Number(annonces[0].id));
  assert.ok(ko, 'la rumeur ratée n’a pas de texte');
  assert.equal(ko.params.ratee, true, 'rumeur ratée signalée (Fred, 26/11)'); assert.equal(ko.params.cible, undefined, 'ni cible');
  assert.equal(ok.params.ratee, false);
  assert.doesNotMatch(JSON.stringify(r), /"auteur":"Ivan"/, 'auteur anonyme tant qu’il n’est pas identifié');
  await db.exec("UPDATE crim_affaires SET identifie = true WHERE details ? 'rumeur_texte'");
  const r2 = await lireChronique(db, 'Lecteur');
  assert.equal(r2.faits.find(x => x.params.texte).auteur, 'Ivan', 'identifié : nommé');
  // Rejouable sans effet (marque déjà posée).
  await db.exec(lire(MIG));
  const d = (await db.query("SELECT pg_get_functiondef('rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure) d")).rows[0].d;
  assert.equal(d.split('chronique_rumeur_texte_v1').length - 1, 1);
});
