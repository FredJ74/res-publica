// Interview d'accueil (Fred, 22/11/2026, point 23) : mode « accueil » de /api/journal-interview (aucune nouvelle fonction
// Vercel). Le vrai api/journal-interview.js, avec une base PostgREST et le fournisseur d'IA simulés en mémoire :
//  - l'action 'accueil_publier' ne reçoit que le nom ; elle relit le chemin et le mot en base (accueil_personnages) ;
//  - l'entretien d'une question est écrit dans interviews_jodie (accueil = true, journaliste) puis publié comme une
//    interview ordinaire (même verbatim, même persistance) ; l'état d'accueil passe à « faite » ;
//  - en Sovarka, Vera Pravdina rédige avec la consigne « à la gloire du Parti » ; Jodie en Républia, sans elle ;
//  - l'interview d'accueil n'arme pas le délai de 10 jours de l'interview volontaire ; rejouer = réussite idempotente.
// Usage : node --test outils/bancs/banc-accueil-interview-api-20261123.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

process.env.SUPABASE_URL = 'https://base.test';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service-test';
process.env.DEEPSEEK_API_KEY = 'ia-test';

let tables, prompts, compteurs;
function remise() {
  tables = {
    personnages_donnees: [{ name: 'Tom', user_id: 'u-tom' }, { name: 'Ivan', user_id: 'u-ivan' }],
    personnages: [{ name: 'Tom', country: 'republic', current_city: 'capitale', photo_url: null }, { name: 'Ivan', country: 'soviet', current_city: 'capitale', photo_url: null }],
    accueil_personnages: [
      { personnage: 'Tom', pays: 'republic', etat_interview: 'article_a_publier', chemin: 'crime', mot: 'Je connais du monde.' },
      { personnage: 'Ivan', pays: 'soviet', etat_interview: 'article_a_publier', chemin: 'uniforme', mot: null }],
    accueil_journalistes: [
      { pays: 'republic', journaliste: 'Jodie Moitout', journal: "L'Autruche Entravée", question: 'Quel chemin ?' },
      { pays: 'soviet', journaliste: 'Vera Pravdina', journal: 'La Voix de Sovarka', question: 'Quelle voie, camarade ?' }],
    accueil_chemins: [{ pays: 'republic', chemin: 'crime', libelle: 'Le crime' }, { pays: 'soviet', chemin: 'uniforme', libelle: "L'uniforme (armée ou police)" }],
    interviews_jodie: [],
    journaux: [], journal_editions: [], mariages: [], detentions: [], jugements: [], candidatures: [], organisations: [], forum_topics: []
  };
  prompts = []; compteurs = { ia: 0 };
}
// Filtres PostgREST utiles : col=eq.x, col=is.x ; select, order, limit ignorés.
function filtrer(lignes, qs) {
  const p = new URLSearchParams(qs);
  return lignes.filter(l => [...p.entries()].every(([k, v]) => {
    if (['select', 'order', 'limit'].includes(k)) return true;
    const m = /^(eq|is)\.(.*)$/.exec(v); if (!m) return true;
    const val = m[2] === 'true' ? true : m[2] === 'false' ? false : m[2] === 'null' ? null : m[2];
    return (l[k] ?? null) === val || String(l[k]) === String(val);
  }));
}
globalThis.fetch = async (url, opt = {}) => {
  const u = new URL(url), methode = opt.method || 'GET';
  const rep = (corps, ok = true) => ({ ok, status: ok ? 200 : 500, json: async () => corps, text: async () => JSON.stringify(corps) });
  if (u.hostname === 'api.deepseek.com' || /deepseek/.test(u.hostname)) {
    const corps = JSON.parse(opt.body); prompts.push(corps.messages.at(-1).content); compteurs.ia++;
    // Le contrôle du verbatim reste actif : une citation inventée serait refusée (Vera ne cite donc rien ici).
    const texte = /Vera Pravdina/.test(prompts.at(-1)) ? 'Un camarade sous l’uniforme\n\nLe Parti salue ce nouveau citoyen.' : 'Un nouveau visage\n\nUn portrait fidèle : « Je connais du monde. »';
    return rep({ choices: [{ message: { content: texte }, finish_reason: 'stop' }] });
  }
  if (u.pathname === '/auth/v1/user') return rep({ id: opt.headers.Authorization === 'Bearer jeton-ivan' ? 'u-ivan' : 'u-tom' });
  if (u.pathname.startsWith('/rest/v1/rpc/')) return rep({ ok: true });
  const table = u.pathname.replace('/rest/v1/', '');
  const t = tables[table]; if (!t) return rep([], true);
  if (methode === 'GET') return rep(filtrer(t, u.search.slice(1)));
  if (methode === 'POST') { const l = JSON.parse(opt.body); t.push({ created_at: new Date().toISOString(), publie: false, ...l }); return rep([l]); }
  if (methode === 'PATCH') { const lignes = filtrer(t, u.search.slice(1)); lignes.forEach(l => Object.assign(l, JSON.parse(opt.body))); return rep(lignes); }
  return rep([]);
};

const { default: handler } = await import('../../api/journal-interview.js');
async function appel(jeton, body) {
  let code = 0, json = null;
  const res = { setHeader() {}, status(n) { code = n; return this; }, json(j) { json = j; return this; }, end() { return this; } };
  await handler({ method: 'POST', headers: { authorization: 'Bearer ' + jeton }, body }, res);
  return { code, json };
}

test('Républia : Jodie publie l’article de bienvenue depuis le chemin enregistré en base ; état « faite » ; rejouable', async () => {
  remise();
  const r = await appel('jeton-tom', { action: 'accueil_publier', personnage: 'Tom' });
  assert.equal(r.code, 200, JSON.stringify(r.json));
  assert.equal(r.json.ok, true);
  assert.equal(r.json.journaliste, 'Jodie Moitout');
  assert.equal(r.json.titre, 'Un nouveau visage');
  const it = tables.interviews_jodie[0];
  assert.equal(it.accueil, true); assert.equal(it.journaliste, 'Jodie Moitout'); assert.equal(it.publie, true);
  assert.deepEqual(it.transcript, [{ question: 'Quel chemin ?', reponse: 'Le crime — Je connais du monde.' }]);
  assert.equal(it.article_texte, 'Un portrait fidèle : « Je connais du monde. »');
  assert.equal(tables.accueil_personnages[0].etat_interview, 'faite');
  assert.match(prompts[0], /Tu es Jodie Moitout/);
  assert.doesNotMatch(prompts[0], /gloire du Parti/);
  const encore = await appel('jeton-tom', { action: 'accueil_publier', personnage: 'Tom' });
  assert.equal(encore.json.ok, true); assert.equal(encore.json.dejaPubliee, true);
  assert.equal(compteurs.ia, 1, 'aucune seconde rédaction');
});

test('Sovarka : Vera Pravdina rédige avec la consigne « à la gloire du Parti » ; aucun champ libre du navigateur', async () => {
  remise();
  const refus = await appel('jeton-ivan', { action: 'accueil_publier', personnage: 'Ivan', chemin: 'crime' });
  assert.equal(refus.code, 400, 'le navigateur ne fournit ni chemin ni mot');
  const r = await appel('jeton-ivan', { action: 'accueil_publier', personnage: 'Ivan' });
  assert.equal(r.json.ok, true, JSON.stringify(r.json));
  assert.equal(r.json.journaliste, 'Vera Pravdina');
  assert.match(prompts[0], /Tu es Vera Pravdina, journaliste de La Voix de Sovarka/);
  assert.match(prompts[0], /retouché à la gloire du Parti/);
  assert.equal(tables.interviews_jodie[0].transcript[0].reponse, "L'uniforme (armée ou police)");
});

test('pas de chemin enregistré : rien à publier ; personnage d’un autre compte : refusé', async () => {
  remise();
  tables.accueil_personnages[0].chemin = null; tables.accueil_personnages[0].etat_interview = 'a_faire';
  assert.equal((await appel('jeton-tom', { action: 'accueil_publier', personnage: 'Tom' })).code, 409);
  assert.equal((await appel('jeton-tom', { action: 'accueil_publier', personnage: 'Ivan' })).code, 403);
});

test('l’interview d’accueil n’arme pas le délai de 10 jours de l’interview volontaire', async () => {
  remise();
  tables.interviews_jodie.push({ id: 'interview_accueil_x', personnage: 'Tom', country: 'republic', accueil: true, publie: true, created_at: new Date().toISOString() });
  const r = await appel('jeton-tom', { action: 'cooldown', personnage: 'Tom' });
  assert.deepEqual(r.json, { ok: true, joursRestants: 0 });
  tables.interviews_jodie.push({ id: 'volontaire', personnage: 'Tom', country: 'republic', publie: true, created_at: new Date().toISOString() });
  tables.interviews_jodie.reverse();
  assert.equal((await appel('jeton-tom', { action: 'cooldown', personnage: 'Tom' })).json.joursRestants, 10);
});

test('aucune nouvelle fonction Vercel : toujours 12 fonctions dans api/', () => {
  const n = fs.readdirSync(new URL('../../api/', import.meta.url)).filter(f => f.endsWith('.js') && !f.startsWith('_')).length;
  assert.equal(n, 12);
});
