// Mission « Purge » (Fred, 24/11/2026), point A.9 : dans la fenêtre de messages, « Aucun message pour le moment »
// disparaît dès qu'un message existe — y compris quand le premier message arrive par le relevé périodique (reset=false),
// cas où la phrase restait au-dessus des messages. Vrai rafraichirConversationActuelle (plateau-multijoueur.js), zone simulée.
// Lancement : node --test outils/bancs/banc-chat-aucun-message-20261124.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const src = fs.readFileSync(path.resolve(__dirname, '../../plateau-multijoueur.js'), 'utf8');
function bloc(debut) {
  const i = src.indexOf(debut); assert.ok(i >= 0, debut);
  let j = src.indexOf('{', i), p = 0;
  for (; j < src.length; j++) { if (src[j] === '{') p++; else if (src[j] === '}' && --p === 0) break; }
  return src.slice(i, j + 1);
}
function zoneSimulee() {
  const z = { html: '', scrollTop: 0, scrollHeight: 0 };
  Object.defineProperty(z, 'innerHTML', { get: () => z.html, set: v => { z.html = v; } });
  Object.defineProperty(z, 'children', { get: () => ({ length: (z.html.match(/<div class="(rp-chat-vide|msg)/g) || []).length }) });
  z.insertAdjacentHTML = (_, h) => { z.html += '<div class="msg">' + h + '</div>'; };
  z.querySelectorAll = sel => sel === '.rp-chat-vide' && z.html.includes('rp-chat-vide')
    ? [{ remove: () => { z.html = z.html.replace(/<div class="rp-chat-vide"[^>]*>[^<]*<\/div>/, ''); } }] : [];
  return z;
}
test('la phrase « Aucun message pour le moment » disparaît au premier message', async () => {
  const zone = zoneSimulee();
  let reponses = [[], [{ id: 'm1', auteur: 'Bernard', message: 'Bonjour', created_at: '2026-11-24T10:00:00Z' }]];
  const c = vm.createContext({ console, Date, state: { char: { name: 'Tom' } }, document: { getElementById: id => id === 'chat-messages-zone' ? zone : null },
    sbGetMessagesConversation: async () => reponses.shift() || [], chatMoiPour: () => 'Tom', chatLibelleParticipant: n => n,
    verifierNotificationChat: () => {}, _conversationActuelle: { id: 'c1' } });
  vm.runInContext('var _chatDernierMessage = null; var _conversationActuelle = { id: "c1" };\n' + src.slice(src.indexOf('let _chatLectureEnCours'), src.indexOf('let _chatLectureEnCours') + 40).split('\n')[0] + '\n' + bloc('async function rafraichirConversationActuelle('), c);
  await c.rafraichirConversationActuelle(true);
  assert.match(zone.html, /Aucun message pour le moment/);
  await c.rafraichirConversationActuelle(false);
  assert.doesNotMatch(zone.html, /Aucun message pour le moment/, 'la phrase a disparu');
  assert.match(zone.html, /Bonjour/);
});
