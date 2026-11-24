// Purge A.10 (Fred, 24/11/2026) : /api/chat?mode=guide (api/_pnj-guide.js), base et IA simulées.
// Aucun message publié ne nomme un parti ni un joueur : l'IA fautive est refusée, une seconde tentative, puis un texte de
// secours sans IA ; 2 ou 3 phrases ; publication par la clé de service seulement ; sans clé de service, rien n'est publié.
// Usage : node --test outils/bancs/banc-pnj-guide-api-20261124.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { creerHandlerGuide, nomInterditCite, troisPhrases, texteSecours } from '../../api/_pnj-guide.js';
import fs from 'node:fs';

const NOMS = { partis: ['Parti du Tracteur Rouge', 'Union des Bouleaux'], joueurs: ['Arnie', 'Olga Petrova', 'Bernard', 'Tom Tom'] };
function base({ textes, reserve, service = true }) {
  const appels = [], publies = [];
  let i = 0;
  const rpc = async (fn, params, options) => {
    appels.push([fn, options && options.service ? 'service' : 'jeton']);
    if (fn === 'guide_reserver') return { etat: 'ok', donnees: reserve };
    if (fn === 'guide_noms_interdits') return { etat: 'ok', donnees: NOMS };
    if (fn === 'guide_publier_service') { publies.push(params.p_texte); return { etat: 'ok', donnees: { ok: true, conversation: 'pnj:x__Bernard' } }; }
    if (fn === 'guide_reponse_autoriser') return { etat: 'ok', donnees: Object.assign({}, reserve, { historique: [{ pnj: true, texte: 'Salut' }, { pnj: false, texte: 'Quel parti ?' }] }) };
    if (fn === 'guide_reponse_publier_service') { publies.push(params.p_texte); return { etat: 'ok', donnees: { ok: true } }; }
    return { etat: 'http' };
  };
  const ia = async () => ({ ok: true, texte: textes[Math.min(i++, textes.length - 1)] });
  const h = creerHandlerGuide({ rpc, ia, auth: async () => ({ id: 'u', jeton: 'j' }), serviceDispo: () => service });
  const res = () => { const r = { code: 0, corps: null, status(c) { this.code = c; return this; }, json(o) { this.corps = o; return this; }, end() { return this; } }; return r; };
  return { h, appels, publies, res };
}
const RESERVE = { ok: true, id: 7, voix: 'habitant', pnj: 'Fiodor Medvedkine', profil: 'guide_fiodor_medvedkine', personnage: 'Bernard', pays: 'soviet', ville: 'ville_b',
  piste: { cle: 's_pol_1', type: 'referent', referent: 'kouzma_lapchine', activite: 'Intégrer une équipe, un réseau : les partis recrutent.', lieu: 'la mairie' },
  nouveau: { chemin: 'politique', carriere: 'worker' }, monde: { partis: 2, elections_en_cours: 1 } };

test('filtre : noms de partis et de joueurs repérés sans accents ni casse, sur mots entiers', () => {
  assert.equal(nomInterditCite('Rejoins le parti du TRACTEUR rouge !', NOMS.partis), 'Parti du Tracteur Rouge');
  assert.equal(nomInterditCite('Demande à arnie.', NOMS.joueurs), 'Arnie');
  assert.equal(nomInterditCite('Bernard, va à la mairie.', NOMS.joueurs, ['Bernard']), null, 'le destinataire peut être nommé');
  assert.equal(nomInterditCite('Les arnies du marché', NOMS.joueurs), null, 'mot entier seulement');
  assert.equal(troisPhrases('Un. Deux ! Trois ? Quatre.'), 'Un. Deux ! Trois ?');
  assert.doesNotMatch(texteSecours(RESERVE.piste), /Tracteur|Arnie/);
});

test('un texte qui nomme un parti puis un joueur est refusé ; le secours sans IA est publié par la clé de service', async () => {
  const { h, publies, appels, res } = base({ textes: ['Va au Parti du Tracteur Rouge, camarade.', 'Demande à Olga Petrova.'], reserve: RESERVE });
  const r = res();
  await h({ method: 'POST', body: { action: 'prochain' }, headers: {} }, r);
  assert.equal(r.corps.ok, true);
  assert.equal(r.corps.source, 'secours');
  assert.equal(publies.length, 1);
  assert.equal(nomInterditCite(publies[0], [...NOMS.partis, ...NOMS.joueurs], ['Bernard']), null, 'aucun nom interdit publié');
  assert.deepEqual(appels.find(a => a[0] === 'guide_reserver'), ['guide_reserver', 'jeton'], 'réservation sous le jeton du joueur');
  assert.deepEqual(appels.find(a => a[0] === 'guide_publier_service'), ['guide_publier_service', 'service']);
});

test('texte propre de l’IA : publié, au plus trois phrases ; réponse au joueur dans le même cadre', async () => {
  const { h, publies, res } = base({ textes: ['Salut toi ! Tu cherches une équipe ? Les partis recrutent. Va voir Kouzma. Bonne chance.'], reserve: RESERVE });
  const r = res();
  await h({ method: 'POST', body: { action: 'prochain' }, headers: {} }, r);
  assert.equal(r.corps.source, 'ia');
  assert.equal(publies[0], 'Salut toi ! Tu cherches une équipe ? Les partis recrutent.');
  const b = base({ textes: ['Le Parti du Tracteur Rouge, sans hésiter.', 'Union des Bouleaux !'], reserve: RESERVE });
  const r2 = b.res();
  await b.h({ method: 'POST', body: { action: 'repondre', pnj: 'Fiodor Medvedkine', message: 'Quel parti ?' }, headers: {} }, r2);
  assert.equal(r2.corps.ok, true);
  assert.equal(nomInterditCite(b.publies[0], NOMS.partis), null, 'jamais de parti, même interrogé');
});

test('sans clé de service : rien n’est publié ; plafonds tenus par le serveur (refus relayé)', async () => {
  const { h, publies, res } = base({ textes: ['Ok.'], reserve: RESERVE, service: false });
  const r = res();
  await h({ method: 'POST', body: { action: 'prochain' }, headers: {} }, r);
  assert.equal(r.code, 503);
  assert.equal(publies.length, 0);
  const b = base({ textes: ['Ok.'], reserve: { ok: false, raison: 'deja_ecrit_aujourdhui' } });
  const r2 = b.res();
  await b.h({ method: 'POST', body: { action: 'prochain' }, headers: {} }, r2);
  assert.deepEqual(r2.corps, { ok: false, raison: 'deja_ecrit_aujourdhui' });
  assert.equal(b.publies.length, 0);
  const chat = fs.readFileSync(new URL('../../api/chat.js', import.meta.url), 'utf8');
  assert.match(chat, /mode === 'guide'\) return handlerGuide/);
});
