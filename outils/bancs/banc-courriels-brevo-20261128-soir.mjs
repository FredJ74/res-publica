// Chantier 2 de Fred (28/11/2026 au soir) : E-MAILS PAR BREVO. Aucun appel réseau : Brevo et la base sont des doublures.
// Format de l'API transactionnelle (POST /v3/smtp/email, en-tête api-key, sender, replyTo, textContent, htmlContent),
// expéditeur et adresse de réponse, échecs (clé absente, refusée, expirée, refus, panne) consignés sans envoi,
// vérification de livraison (GET /v3/smtp/statistics/events), actions MJ (/api/courriel), alerte de la page MJ,
// migration, raccords, et plus aucune trace de l'ancien fournisseur.
// Lancer : node --test outils/bancs/banc-courriels-brevo-20261128-soir.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { envoyerCourriel, evenementsCourriel, courrielConfigure, classerReponseBrevo, texteEnHtml, EXPEDITEUR, ADRESSE_REPONSE } from '../../api/_courriel.js';
import { creerHandlerCourriel, SUJET_TEST } from '../../api/_courriel-mj.js';
import { traiterComptesInactifs } from '../../api/_comptes-inactifs.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const CLE = 'cle-de-banc-' + Math.random().toString(36).slice(2);   // jamais une vraie clé

function brevo(status = 201, corps = { messageId: '<202611282300.1@smtp-relay.mailin.fr>' }) {
  const appels = [];
  const fetchFn = async (url, init) => { appels.push({ url, init, corps: init.body ? JSON.parse(init.body) : null });
    if (status === 'reseau') throw new TypeError('fetch failed');
    return { ok: status >= 200 && status < 300, status, json: async () => corps }; };
  return { appels, fetchFn };
}
function journal() { const lignes = []; return { lignes, fn: async (raison, contexte, detail) => { lignes.push({ raison, contexte, detail }); } }; }
function reponse() { const r = { code: 0, corps: null, entetes: {} }; r.status = c => { r.code = c; return r; }; r.json = j => { r.corps = j; return r; };
  r.setHeader = (k, v) => { r.entetes[k] = v; }; return r; }

test('envoi : API transactionnelle de Brevo, expéditeur fixe, adresse de réponse sur demande, HTML échappé', async () => {
  const b = brevo(), j = journal();
  const r = await envoyerCourriel({ a: 'joueur@example.org', sujet: 'Sujet', texte: 'Ligne <1> & « 2 »\n\nFin', repondre: true, cle: 'achat-1', contexte: 'paiement_achat', langue: 'ar' },
    { env: { BREVO_API_KEY: ' ' + CLE + ' ' }, fetchFn: b.fetchFn, journal: j.fn });
  assert.deepEqual(r, { ok: true, messageId: '<202611282300.1@smtp-relay.mailin.fr>' });
  assert.equal(b.appels.length, 1);
  const { url, init, corps } = b.appels[0];
  assert.equal(url, 'https://api.brevo.com/v3/smtp/email'); assert.equal(init.method, 'POST');
  assert.equal(init.headers['api-key'], CLE, 'clé sans espaces'); assert.equal(init.headers['Content-Type'], 'application/json');
  assert.equal(init.headers.Authorization, undefined);
  assert.deepEqual(corps.sender, { name: 'Human Gambit', email: 'noreply@human-gambit.com' });
  assert.deepEqual(corps.to, [{ email: 'joueur@example.org' }]);
  assert.deepEqual(corps.replyTo, { name: 'Human Gambit', email: 'contact@human-gambit.com' });
  assert.equal(corps.subject, 'Sujet'); assert.equal(corps.textContent, 'Ligne <1> & « 2 »\n\nFin');
  assert.match(corps.htmlContent, /^<!DOCTYPE html><html lang="ar" dir="rtl">/);
  assert.match(corps.htmlContent, /<p>Ligne &lt;1&gt; &amp; « 2 »<\/p><p>Fin<\/p>/);
  assert.deepEqual(corps.headers, { idempotencyKey: 'achat-1' }); assert.deepEqual(corps.tags, ['hg-paiement_achat']);
  assert.equal(j.lignes.length, 0, 'un succès ne consigne rien');
  const sans = brevo();
  await envoyerCourriel({ a: 'x@example.org', sujet: 's', texte: 't' }, { env: { BREVO_API_KEY: CLE }, fetchFn: sans.fetchFn, journal: null });
  assert.equal(sans.appels[0].corps.replyTo, undefined, 'pas d’adresse de réponse sans « repondre »');
  assert.equal(sans.appels[0].corps.headers, undefined);
  assert.deepEqual(EXPEDITEUR, { name: 'Human Gambit', email: 'noreply@human-gambit.com' });
  assert.deepEqual(ADRESSE_REPONSE, { name: 'Human Gambit', email: 'contact@human-gambit.com' });
  assert.match(texteEnHtml('a', 'zh-TW'), /lang="zh-TW">/); assert.match(texteEnHtml('a', '"><script>'), /lang="fr">/);
});

test('échecs : rien ne part, raison claire, consigné (clé absente, refusée, expirée, refus, panne) ; adresse invalide non consignée', async () => {
  assert.equal(courrielConfigure({}), false); assert.equal(courrielConfigure({ BREVO_API_KEY: '  ' }), false); assert.equal(courrielConfigure({ BREVO_API_KEY: 'k' }), true);
  const cas = [
    [{}, null, 'cle_absente', 0],
    [{ BREVO_API_KEY: CLE }, 401, 'cle_refusee', 1],
    [{ BREVO_API_KEY: CLE }, 403, 'cle_refusee', 1],
    [{ BREVO_API_KEY: CLE }, 400, 'envoi_refuse_400', 1],
    [{ BREVO_API_KEY: CLE }, 502, 'brevo_indisponible_502', 1],
    [{ BREVO_API_KEY: CLE }, 'reseau', 'envoi_echoue', 1]
  ];
  for (const [env, status, raison, appels] of cas) {
    const b = brevo(status || 201, { code: 'unauthorized', message: 'Key not found ' + CLE }), j = journal();
    const r = await envoyerCourriel({ a: 'x@example.org', sujet: 's', texte: 't', contexte: 'comptes_inactifs' }, { env, fetchFn: b.fetchFn, journal: j.fn });
    assert.equal(r.ok, false, raison); assert.equal(r.raison, raison); assert.equal(b.appels.length, appels, raison);
    assert.deepEqual(j.lignes.map(l => [l.raison, l.contexte]), [[raison, 'comptes_inactifs']], raison);
    assert.ok(!String(r.detail || '').includes(CLE) && !String(j.lignes[0].detail || '').includes(CLE), 'la clé ne sort jamais : ' + raison);
  }
  const b = brevo(401, { code: 'unauthorized', message: 'Key not found' }), j = journal();
  const r = await envoyerCourriel({ a: 'x@example.org', sujet: 's', texte: 't' }, { env: { BREVO_API_KEY: CLE }, fetchFn: b.fetchFn, journal: j.fn });
  assert.equal(r.detail, 'HTTP 401 unauthorized : Key not found');
  for (const a of ['', 'pas-une-adresse', 'a@b']) {
    const b2 = brevo(), j2 = journal();
    const r2 = await envoyerCourriel({ a, sujet: 's', texte: 't' }, { env: { BREVO_API_KEY: CLE }, fetchFn: b2.fetchFn, journal: j2.fn });
    assert.equal(r2.ok, false); assert.equal(b2.appels.length, 0); assert.equal(j2.lignes.length, 0);
  }
  // Un journal en panne n'empêche pas l'appelant de continuer.
  const r3 = await envoyerCourriel({ a: 'x@example.org', sujet: 's', texte: 't' }, { env: {}, journal: async () => { throw new Error('base'); } });
  assert.equal(r3.raison, 'cle_absente');
  assert.equal(classerReponseBrevo(401), 'cle_refusee'); assert.equal(classerReponseBrevo(429), 'envoi_refuse_429');
});

test('livraison : événements Brevo par messageId et adresse', async () => {
  const b = brevo(200, { events: [{ event: 'requests', date: '2026-11-28T23:01:00Z', email: 'x@example.org', messageId: '<m>' },
    { event: 'delivered', date: '2026-11-28T23:01:05Z', email: 'x@example.org', messageId: '<m>' }] });
  const r = await evenementsCourriel({ messageId: '<m@brevo>', email: 'x@example.org' }, { env: { BREVO_API_KEY: CLE }, fetchFn: b.fetchFn });
  assert.equal(r.ok, true); assert.equal(r.livre, true); assert.deepEqual(r.evenements.map(e => e.event), ['requests', 'delivered']);
  const u = new URL(b.appels[0].url);
  assert.equal(u.origin + u.pathname, 'https://api.brevo.com/v3/smtp/statistics/events');
  assert.equal(u.searchParams.get('messageId'), '<m@brevo>'); assert.equal(u.searchParams.get('email'), 'x@example.org');
  assert.equal(b.appels[0].init.headers['api-key'], CLE);
  const sansLivraison = brevo(200, { events: [{ event: 'softBounces', date: 'd', reason: 'mailbox full' }] });
  const r2 = await evenementsCourriel({ messageId: '<m>' }, { env: { BREVO_API_KEY: CLE }, fetchFn: sansLivraison.fetchFn });
  assert.equal(r2.livre, false); assert.equal(r2.evenements[0].reason, 'mailbox full');
  assert.equal((await evenementsCourriel({ messageId: '<m>' }, { env: {} })).raison, 'cle_absente');
  assert.equal((await evenementsCourriel({ messageId: '<m>' }, { env: { BREVO_API_KEY: CLE }, fetchFn: brevo(401, {}).fetchFn })).raison, 'cle_refusee');
});

function base(reponses) {
  const appels = [];
  const rpc = async (fn, params, options) => { appels.push({ fn, params, options }); const v = reponses[fn]; return { etat: 'ok', donnees: typeof v === 'function' ? v(params, options) : v }; };
  return { appels, rpc };
}

test('actions MJ : e-mail de test (jeton à usage unique ou compte MJ), statut, sanction dans la langue du joueur', async () => {
  // Jeton de test : adresse lue en base avec la clé de service, identifiant du message noté.
  const b = brevo(), db = base({ courriel_test_jeton_service: p => p.p_lire ? { ok: true, email: 'dest@example.org', message_id: '<t@brevo>' } : { ok: true, email: 'dest@example.org' } });
  const h = creerHandlerCourriel({ env: { BREVO_API_KEY: CLE }, fetch: b.fetchFn, rpc: db.rpc, journal: null });
  let r = reponse();
  await h({ method: 'POST', headers: {}, body: { action: 'test', jeton: 'j'.repeat(40) } }, r);
  assert.equal(r.code, 200); assert.equal(r.corps.ok, true); assert.equal(r.corps.messageId, '<202611282300.1@smtp-relay.mailin.fr>');
  assert.equal(b.appels[0].corps.subject, SUJET_TEST); assert.equal(SUJET_TEST, 'Human Gambit — e-mail de test (Brevo)');
  assert.deepEqual(b.appels[0].corps.to, [{ email: 'dest@example.org' }]); assert.equal(b.appels[0].corps.replyTo.email, 'contact@human-gambit.com');
  assert.ok(db.appels.every(a => a.options && a.options.service === true));
  assert.deepEqual(db.appels[1].params, { p_jeton: 'j'.repeat(40), p_message_id: '<202611282300.1@smtp-relay.mailin.fr>' });
  r = reponse();
  const ev = brevo(200, { events: [{ event: 'delivered', date: 'd' }] });
  await creerHandlerCourriel({ env: { BREVO_API_KEY: CLE }, fetch: ev.fetchFn, rpc: db.rpc })({ method: 'POST', headers: {}, body: { action: 'test_statut', jeton: 'j'.repeat(40) } }, r);
  assert.equal(r.corps.livre, true); assert.equal(new URL(ev.appels[0].url).searchParams.get('messageId'), '<t@brevo>');
  // Jeton refusé : rien ne part.
  const b2 = brevo(); r = reponse();
  await creerHandlerCourriel({ env: { BREVO_API_KEY: CLE }, fetch: b2.fetchFn, rpc: base({ courriel_test_jeton_service: { ok: false, raison: 'jeton_deja_utilise' } }).rpc })(
    { method: 'POST', headers: {}, body: { action: 'test', jeton: 'j'.repeat(40) } }, r);
  assert.equal(r.code, 403); assert.equal(r.corps.raison, 'jeton_deja_utilise'); assert.equal(b2.appels.length, 0);
  // Sans identité : refus. Compte MJ : son adresse, avec SON jeton (la base revérifie admin_exiger).
  r = reponse(); await h({ method: 'POST', headers: {}, body: { action: 'test' } }, r); assert.equal(r.code, 401);
  const b3 = brevo(), db3 = base({ admin_courriel_test_adresse: { ok: true, email: 'mj@example.org' } }); r = reponse();
  await creerHandlerCourriel({ env: { BREVO_API_KEY: CLE }, fetch: b3.fetchFn, rpc: db3.rpc, journal: null })({ method: 'POST', headers: { authorization: 'Bearer jeton-mj' }, body: { action: 'test' } }, r);
  assert.equal(r.corps.ok, true); assert.deepEqual(db3.appels[0].options, { jeton: 'jeton-mj' }); assert.deepEqual(b3.appels[0].corps.to, [{ email: 'mj@example.org' }]);
  // Clé absente : réponse claire, consignée, rien ne part.
  const j = journal(), b4 = brevo(); r = reponse();
  await creerHandlerCourriel({ env: {}, fetch: b4.fetchFn, rpc: db3.rpc, journal: j.fn })({ method: 'POST', headers: { authorization: 'Bearer jeton-mj' }, body: { action: 'test' } }, r);
  assert.equal(r.corps.ok, false); assert.equal(r.corps.raison, 'cle_absente'); assert.equal(b4.appels.length, 0); assert.equal(j.lignes[0].contexte, 'test_mj');
  // Sanction : texte préparé par la base, langue du joueur, adresse de réponse contact@.
  const b5 = brevo(), db5 = base({ admin_sanction_courriel_preparer: { ok: true, email: 'p@example.org', langue: 'ko', sujet: 'Human Gambit — 운영 결정', texte: '경고\n\ncontact@human-gambit.com' } });
  r = reponse();
  await creerHandlerCourriel({ env: { BREVO_API_KEY: CLE }, fetch: b5.fetchFn, rpc: db5.rpc, journal: null })({ method: 'POST', headers: { authorization: 'Bearer jeton-mj' }, body: { action: 'sanction', sanction: 12 } }, r);
  assert.deepEqual(r.corps, { ok: true }); assert.deepEqual(db5.appels[0].params, { p_id: 12 }); assert.deepEqual(db5.appels[0].options, { jeton: 'jeton-mj' });
  assert.equal(b5.appels[0].corps.replyTo.email, 'contact@human-gambit.com'); assert.match(b5.appels[0].corps.htmlContent, /lang="ko"/);
  r = reponse(); await h({ method: 'POST', headers: {}, body: { action: 'inconnue' } }, r); assert.equal(r.code, 400);
  r = reponse(); await h({ method: 'GET', headers: {}, body: {} }, r); assert.equal(r.code, 405);
});

test('comptes inactifs : envoi par le module Brevo, réponse vers contact@, langue du compte', async () => {
  const envois = [];
  const liste = { ok: true, avertir: [{ user_id: 'u1', email: 'a@b.c', activite: '2023-01-01', suppression_le: '2026-12-28', langue: 'ar', personnage: 'X' }], supprimer: [] };
  await traiterComptesInactifs({ rpc: async fn => fn === 'comptes_inactifs_lister' ? [liste] : { ok: true }, envoyer: async x => { envois.push(x); return { ok: true }; } });
  assert.equal(envois[0].repondre, true); assert.equal(envois[0].contexte, 'comptes_inactifs'); assert.equal(envois[0].langue, 'ar');
  assert.match(lire('api/_comptes-inactifs.js'), /import \{ envoyerCourriel \} from '\.\/_courriel\.js';/);
  assert.match(lire('api/_paiement.js'), /import \{ envoyerCourriel \} from '\.\/_courriel\.js';/);
  assert.doesNotMatch(lire('api/_paiement-courriels.js'), /fetch|api-key/, 'les textes du paiement n’envoient plus rien eux-mêmes');
});

test('migration : échecs consignés par le serveur seul, lus et acquittés par le MJ, jeton de test haché', () => {
  const s = lire('migrations/20261128230000_courriels_brevo.sql');
  assert.match(s, /^-- E-mails du jeu par Brevo/); assert.match(s, /\nBEGIN;\n/); assert.match(s, /\nCOMMIT;\n$/);
  for (const t of ['courriel_echecs', 'courriel_tests']) {
    assert.match(s, new RegExp('ALTER TABLE public\\.' + t + ' ENABLE ROW LEVEL SECURITY;'));
    assert.match(s, new RegExp('REVOKE ALL ON public\\.' + t + ' FROM anon, authenticated;'));
  }
  const corpsFn = n => s.slice(s.indexOf('FUNCTION public.' + n + '('), s.indexOf('END $$;', s.indexOf('FUNCTION public.' + n + '(')));
  for (const n of ['courriel_echec_noter_service', 'courriel_test_jeton_service']) assert.match(corpsFn(n), /IF NOT public\.est_appel_serveur\(\)/, n);
  for (const n of ['admin_courriel_echecs_lire', 'admin_courriel_echecs_acquitter', 'admin_sanction_courriel_preparer', 'admin_courriel_test_adresse'])
    assert.match(corpsFn(n), /public\.admin_exiger\(\)/, n);
  assert.match(corpsFn('courriel_echec_noter_service'), /courriels_brevo_v1/);
  assert.match(corpsFn('courriel_test_jeton_service'), /sha256\(convert_to/);
  assert.match(s, /GRANT EXECUTE ON FUNCTION public\.courriel_echec_noter_service\(text, text, text\), public\.courriel_test_jeton_service\(text, text, boolean\)\n  TO service_role;/);
  assert.doesNotMatch(s, /@(?!human-gambit\.com)[a-z0-9-]+\.[a-z]{2,}/i, 'aucune adresse personnelle dans la migration');
});

test('page MJ : alerte en tête à l’ouverture, bloc e-mails, sanction notifiée par e-mail ; page en français', () => {
  const html = lire('admin.html');
  assert.match(html, /<html lang="fr">/);
  assert.match(html, /<div id="adm-alerte-courriel" class="adm-message mauvais" role="alert" hidden><\/div>/);
  assert.match(html, /<script src="admin-courriels\.js\?v=[^"]+"><\/script>/);
  assert.match(html, /onclick="admCourrielsCharger\(\)"/);
  assert.match(lire('admin-tribunal.js'), /if \(typeof admCourrielAlerte === 'function'\) admCourrielAlerte\(\);/);
  const js = lire('admin-courriels.js');
  for (const x of ['admin_courriel_echecs_lire', 'admin_courriel_echecs_acquitter', "'/api/courriel'", 'BREVO_API_KEY', 'Marquer comme lu']) assert.ok(js.includes(x), x);
  assert.match(js, /cle_absente: 'Aucun e-mail ne part : la clé BREVO_API_KEY est absente de Vercel/);
  assert.match(js, /cle_refusee: 'Aucun e-mail ne part : Brevo refuse la clé BREVO_API_KEY/);
  assert.match(lire('admin-signalements.js'), /await admCourrielSanction\(r\.sanction\.id\)/);
});

test('raccords : /api/courriel greffé sur chat.js, 12 fonctions, plus aucune trace de l’ancien fournisseur ni de clé', () => {
  const v = JSON.parse(lire('vercel.json'));
  assert.ok(v.rewrites.some(r => r.source === '/api/courriel' && r.destination === '/api/chat?mode=courriel'));
  const chat = lire('api/chat.js');
  assert.match(chat, /import \{ handlerCourriel \} from '\.\/_courriel-mj\.js';/);
  assert.match(chat, /if \(req\.query && req\.query\.mode === 'courriel'\) return handlerCourriel\(req, res\);/);
  const fonctions = fs.readdirSync(path.join(root, 'api')).filter(f => f.endsWith('.js') && !f.startsWith('_'));
  assert.ok(fonctions.length <= 12, fonctions.length + ' fonctions');
  const fichiers = ['api/_courriel.js', 'api/_courriel-mj.js', 'api/_paiement.js', 'api/_paiement-courriels.js', 'api/_comptes-inactifs.js',
    'api/cron-minuit.js', 'admin-courriels.js', 'ARCHITECTURE.md', 'docs/premium/PAIEMENT-STRIPE-20261128.md', 'migrations/20261128230000_courriels_brevo.sql'];
  for (const f of fichiers) {
    const s = lire(f);
    assert.doesNotMatch(s, /RESEND_API_KEY|COURRIEL_EXPEDITEUR|api\.resend\.com|\bResend\b/, f);
    assert.doesNotMatch(s, /xkeysib-[A-Za-z0-9]{8}|xsmtpsib-[A-Za-z0-9]{8}/, 'clé Brevo dans ' + f);
  }
  // « resend » restant : renvoi de l'e-mail de confirmation de Supabase Auth (endpoint /auth/v1/resend), pas un fournisseur.
  assert.match(lire('auth.js'), /fetch\(RP_AUTH_URL \+ '\/resend'/);
});
