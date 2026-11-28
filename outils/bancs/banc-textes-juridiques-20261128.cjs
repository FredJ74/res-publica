// Banc des textes juridiques (Fred, 28/11/2026, étape 5) : fichiers juridique/<langue>/<texte>.md (9 × 4) et leur en-tête,
// registre des versions = migration, livraison Vercel des .md, module client neuf langues (case NON cochée), raccords
// dans l'écran (création, accueil, Aide, fiche, forum, refus commun), migration (marques, interrupteur éteint),
// traitement de nuit des comptes inactifs (pas d'avertissement noté sans e-mail envoyé). Aucun appel distant.
const test = require('node:test'), assert = require('node:assert'), fs = require('node:fs'), path = require('node:path');
const vm = require('node:vm'), os = require('node:os');
const R = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(R, f), 'utf8');
const LANGUES = ['fr', 'en', 'es', 'de', 'ru', 'ko', 'ar', 'pt-BR', 'zh-TW'];
const TEXTES = ['mentions-legales', 'cgu', 'cgv', 'confidentialite'];
const MIG = 'migrations/20261128130000_juridique_accords_comptes.sql';
const MIG2 = 'migrations/20261128131000_juridique_blocage_interrupteur.sql';

test('36 fichiers juridiques : en-tête texte/version/date conforme au registre, titre et une ligne provisoire', () => {
  const reg = JSON.parse(lire('juridique/versions.json'));
  assert.deepStrictEqual(reg.langues, LANGUES);
  assert.strictEqual(reg.langue_qui_fait_foi, 'fr');
  for (const t of TEXTES) {
    const v = reg.textes[t];
    assert.ok(v && /^\d+(\.\d+)*$/.test(v.version) && /^\d{4}-\d{2}-\d{2}$/.test(v.date), t);
    for (const l of LANGUES) {
      const md = lire('juridique/' + l + '/' + t + '.md');
      const m = /^---\ntexte: (.+)\nversion: (.+)\ndate: (.+)\n---\n# (.+)\n\n(.+)\n/.exec(md);
      assert.ok(m, l + '/' + t + ' : en-tête absent');
      assert.deepStrictEqual([m[1], m[2], m[3]], [t, v.version, v.date], l + '/' + t);
      assert.ok(m[4].trim() && m[5].trim(), l + '/' + t + ' : titre ou texte vide');
    }
  }
});

test('le registre des versions correspond à une ligne réelle du serveur (juridique_versions)', () => {
  const reg = JSON.parse(lire('juridique/versions.json'));
  for (const [t, v] of Object.entries(reg.textes)) {
    const sql = lire('migrations/' + v.migration + '.sql');
    const ligne = new RegExp("\\('" + t + "', '" + v.version.replace('.', '\\.') + "', DATE '" + v.date + "', " + v.importante + ',');
    assert.ok(ligne.test(sql), t + ' ' + v.version + ' absent de ' + v.migration);
  }
});

test('Vercel livre les .md juridiques (et eux seuls) ; un changement de texte relance la compilation', () => {
  const ign = lire('.vercelignore').split(/\r?\n/).map(s => s.trim());
  const i = ign.indexOf('*.md'), j = ign.indexOf('!juridique/**/*.md');
  assert.ok(i >= 0 && j > i, 'négation après *.md');
  assert.deepStrictEqual(ign.filter(s => s.startsWith('!')), ['!juridique/**/*.md']);
  const b = lire('vercel-ignore-build.cjs');
  assert.ok(b.includes("s !== '!juridique/**/*.md'"));
  assert.ok(!/juridique/.test(b.match(/fichiers\.every\(f => (.*)\)/)[1]), 'un .md juridique n’est jamais « documentation seule »');
});

function chargerClient(langue, elements) {
  const els = elements || {};
  const document = { readyState: 'complete', getElementById: id => els[id] || null, querySelector: () => null, querySelectorAll: () => [],
    addEventListener() {}, body: { appendChild() {} }, createElement: () => ({ setAttribute() {}, style: {} }) };
  const window = { localStorage: { getItem: () => langue }, document };
  const ctx = vm.createContext({ window, document, console, setTimeout, URL, Blob: function () {} });
  vm.runInContext(lire('juridique-client.js'), ctx);
  return ctx.window.RPJuridique;
}

test('module client : neuf langues, mêmes clés partout, case non cochée, liens vers juridique.html', () => {
  const J = chargerClient('fr');
  assert.deepStrictEqual(Object.keys(J.T).sort(), [...LANGUES].sort());
  const cles = o => Object.entries(o).flatMap(([k, v]) => (v && typeof v === 'object') ? cles(v).map(c => k + '.' + c) : [k]).sort();
  for (const l of LANGUES) {
    assert.deepStrictEqual(cles(J.T[l]), cles(J.T.fr), l);
    assert.ok(J.T[l].caseTexte.includes('{cgu}') && J.T[l].caseTexte.includes('{conf}'), l + ' : liens de la case');
    assert.ok(/16/.test(J.T[l].caseTexte), l + ' : 16 ans');
    assert.ok(J.T[l].contester.includes('{c}'), l + ' : contact de contestation');
  }
  const html = J.htmlCaseAcceptation('x');
  assert.ok(html.includes('type="checkbox"') && !/checked/.test(html), 'case non cochée');
  assert.ok(html.includes('juridique.html?texte=cgu&amp;lang=fr') && html.includes('juridique.html?texte=confidentialite&amp;lang=fr'));
  assert.ok(J.tr('foi').includes('française'));
  const ko = chargerClient('ko');
  assert.strictEqual(ko.langue(), 'ko');
  assert.ok(ko.lien('cgv').endsWith('lang=ko'));
});

test('module client : la case non cochée bloque l’accord, aucun appel serveur', async () => {
  const J = chargerClient('fr', { 'hg-case-juridique-input': { checked: false } });
  const r = await J.accepterCreation();
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.raison, 'case_non_cochee');
});

test('raccords dans l’écran', () => {
  const index = lire('index.html'), plateau = lire('plateau.html'), creation = lire('creation.js');
  assert.ok(index.includes('id="hg-pied-juridique"') && index.includes('id="hg-case-juridique"') && index.includes('juridique-client.js'));
  assert.ok(index.indexOf('juridique-client.js') < index.indexOf('creation.js?v='), 'module chargé avant creation.js');
  assert.ok(plateau.includes('data-section="juridique"') && plateau.includes('juridique-client.js'));
  const iAccord = creation.indexOf('RPJuridique.accepterCreation()'), iCreation = creation.indexOf('await sbCreerPersonnageInitial(');
  assert.ok(iAccord > 0 && iAccord < iCreation, 'accord enregistré avant la création du personnage');
  assert.ok(lire('supabase.js').includes("v.raison === 'conditions_a_accepter' || v.raison === 'compte_suspendu'"));
  assert.ok(lire('forum.js').includes('RPJuridique.htmlSignaler(nom, photo)'));
  const perso = lire('plateau-personnage.js');
  assert.ok(perso.includes('window.RPJuridique.htmlCompte()') && perso.includes('async function rpDetruirePersonnageParSuccession('));
  assert.ok(perso.includes("sbRpc('personnage_suppression_liens_liberer'"));
  assert.ok(lire('plateau-core.js').includes("r.raison === 'conditions_a_accepter' || r.raison === 'compte_suspendu'"));
  const admin = lire('admin-signalements.js');
  assert.ok(admin.includes("rpAdminRpc('admin_sanction_prononcer'") && admin.includes('Règle enfreinte') && admin.includes('Contenu visé'));
  const page = lire('juridique.html');
  assert.ok(page.includes("fetch('juridique/' + encodeURIComponent(lg) + '/' + texte + '.md'") && page.includes("J.tr('traduction'"));
  assert.ok(!/#[0-9a-fA-F]{3,6}\b|rgba?\(/.test(lire('juridique-client.js')), 'pas de couleur en dur dans le module');
});

test('migrations : bornes, marques, droits, textes de sanction en neuf langues, interrupteur éteint', () => {
  for (const f of [MIG, MIG2]) {
    const s = lire(f);
    assert.ok(/^BEGIN;$/m.test(s) && /^COMMIT;$/m.test(s), f);
    const h = Number(path.basename(f).slice(0, 14));
    assert.ok(h >= 20261128130000 && h <= 20261128139999, f + ' hors plage');
  }
  const s = lire(MIG);
  assert.ok(s.includes("'juridique_accord_v1'") && s.includes("pg_temp.rp_remplacer('public.payer_ordre_interne(text,text,integer,integer,integer)'"));
  for (const f of ['comptes_inactifs_lister(integer)', 'comptes_inactifs_avertissement_noter(uuid, timestamptz)', 'compte_inactif_supprimer(uuid)'])
    assert.ok(s.includes('REVOKE ALL ON FUNCTION public.' + f + ' FROM PUBLIC, anon, authenticated;') && s.includes('GRANT EXECUTE ON FUNCTION public.' + f + ' TO service_role;'), f);
  assert.ok(s.includes('REVOKE ALL ON FUNCTION public.juridique_export_lignes_interne(text, text) FROM PUBLIC, anon, authenticated;'));
  assert.ok(s.includes("SET author = 'Ancien joueur'"));
  const dict = JSON.parse(s.match(/DECLARE d jsonb := '(\{[\s\S]*?\n\})'::jsonb;/)[1].replace(/''/g, "'"));
  assert.deepStrictEqual(Object.keys(dict).sort(), [...LANGUES].sort());
  for (const l of LANGUES) {
    assert.deepStrictEqual(Object.keys(dict[l]).sort(), Object.keys(dict.fr).sort(), l);
    assert.ok(dict[l].contester.includes('contact@human-gambit.com'), l);
  }
  const s2 = lire(MIG2);
  assert.ok(s2.includes("VALUES ('blocage_ordres', false,") && s2.includes('juridique_interrupteur_v1'));
});

test('comptes inactifs : avertissement noté seulement si l’e-mail part ; suppression demandée au serveur', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'banc-juridique-'));
  fs.writeFileSync(path.join(dir, '_courriel.mjs'), lire('api/_courriel.js'));
  fs.writeFileSync(path.join(dir, '_comptes-inactifs.mjs'), lire('api/_comptes-inactifs.js').replace("'./_courriel.js'", "'./_courriel.mjs'"));
  const m = await import(path.join(dir, '_comptes-inactifs.mjs'));
  const c = await import(path.join(dir, '_courriel.mjs'));
  assert.deepStrictEqual(await c.envoyerCourriel({ a: 'x@y.z', sujet: 's', texte: 't' }, { env: {} }), { ok: false, raison: 'fournisseur_non_configure' });
  const appels = [];
  const liste = { ok: true, avertir: [{ user_id: 'u1', email: 'a@b.c', activite: '2023-01-01', suppression_le: '2026-12-28', langue: 'de', personnage: 'Arnie' },
    { user_id: 'u2', email: 'd@e.f', activite: '2023-01-01', suppression_le: '2026-12-28', langue: 'xx', personnage: null }],
    supprimer: [{ user_id: 'u3' }] };
  const rpc = async (fn, p) => { appels.push([fn, p]); return fn === 'comptes_inactifs_lister' ? [liste] : { ok: true }; };
  const envois = [];
  const envoyer = async (x) => { envois.push(x); return { ok: x.a === 'a@b.c' }; };
  const b = await m.traiterComptesInactifs({ rpc, envoyer });
  assert.strictEqual(b.avertis, 1); assert.strictEqual(b.avertissements_non_envoyes, 1); assert.strictEqual(b.supprimes, 1);
  assert.deepStrictEqual(appels.filter(a => a[0] === 'comptes_inactifs_avertissement_noter').map(a => a[1].p_uid), ['u1']);
  assert.deepStrictEqual(appels.filter(a => a[0] === 'compte_inactif_supprimer').map(a => a[1].p_uid), ['u3']);
  assert.ok(envois[0].texte.includes('Arnie') && /gelöscht/.test(envois[0].sujet), 'allemand');
  assert.ok(/supprimé/.test(envois[1].sujet), 'langue inconnue : français');
  const vide = await m.traiterComptesInactifs({ rpc: async () => null, envoyer });
  assert.strictEqual(vide.ok, false);
  const cron = lire('api/cron-minuit.js');
  assert.ok(cron.includes("import { traiterComptesInactifs } from './_comptes-inactifs.js';") && cron.includes('traiterComptesInactifs({ rpc: (fn, p) => sbRpc(fn, p, HEADERS_SERVICE) })'));
});
