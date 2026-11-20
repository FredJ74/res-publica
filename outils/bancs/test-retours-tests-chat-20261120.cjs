'use strict';
// Retours des tests à deux comptes de Fred (20/11/2026) : notification « X vous parle », débusquage au journal,
// déplacements du MJ, conversations de proximité.
// Essai annulé en base le 20/11 : Tom Tom écrit à Arnie (même pièce) → envoi accepté, chat_signaux d'Arnie 1 ; Arnie
// déplacé directement en base (comme le MJ) → personnages_signaux 25→26 ; nouvel envoi → 'interlocuteur_absent', écriture
// directe refusée par la règle, historique lisible (1 message) ; Arnie masqué revient → conversation anonyme acceptée,
// signal remis au vrai destinataire (2).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');

test('Serveur : proximité au moment de l\'envoi, signal par destinataire (anonyme résolu au serveur), débusqué masqué', () => {
  const sql = lire('migrations/20261120310000_chat_proximite_signaux_debusque.sql');
  assert.match(sql, /RETURN jsonb_build_object\('ok', false, 'raison', 'interlocuteur_absent'\);/);
  assert.match(sql, /AND \(coalesce\(salon, false\) OR public\.chat_co_presents_interne\(conversation_id\)\)\);/);
  assert.match(sql, /WHERE j\.jeton::text = substr\(p_part, 8\)/);
  assert.match(sql, /CREATE POLICY chat_signaux_soi ON public\.chat_signaux FOR SELECT TO authenticated USING \(personnage = public\.mon_personnage\(\)\);/);
  assert.match(sql, /ALTER PUBLICATION supabase_realtime ADD TABLE public\.chat_signaux/);
  assert.match(sql, /\|\| jsonb_build_object\('vous_masque', v_masque\)\);/);
  // Déplacements du MJ : le déclencheur de table émet déjà le signal, quelle que soit l'origine.
  assert.match(lire('migrations/20261120280000_presence_permanente_signaux.sql'), /CREATE TRIGGER zz_personnages_signaux AFTER INSERT OR UPDATE OR DELETE ON public\.personnages_donnees/);
});

test('Débusquage : ligne au journal, fouilleur nommé ou masqué, rappel du masque', () => {
  const g = { document: { readyState: 'loading', addEventListener() {}, getElementById: () => null }, setTimeout() {}, setInterval() {} };
  g.window = g; vm.runInNewContext(lire('plateau-criminalite.js'), g);
  const l = g.RPCriminalite.ligneDebusquage;
  assert.equal(l({ par: 'Tom Tom' }), 'Tom Tom a fouillé la pièce et vous a débusqué(e) : vous n’êtes plus caché(e).');
  assert.equal(l({ par_masque: true }), 'Un individu masqué a fouillé la pièce et vous a débusqué(e) : vous n’êtes plus caché(e).');
  assert.equal(l({ par_masque: true, vous_masque: true }), 'Un individu masqué a fouillé la pièce et vous a débusqué(e) : vous n’êtes plus caché(e). Vous restez masqué(e).');
});

test('On vous parle : notification cliquable, jamais d\'ouverture automatique ; temps réel', () => {
  const multi = lire('plateau-multijoueur.js');
  const debut = multi.indexOf('async function verifierNotificationChat()'), fin = multi.indexOf('\n}\n', debut);
  const corps = multi.slice(debut, fin);
  assert.doesNotMatch(corps, /panel\.style\.display = 'flex'/);           // la fenêtre ne s'ouvre jamais d'elle-même
  assert.match(corps, /afficherNotificationChat\(nonLu\)/);
  assert.match(multi, /rpLibelleChat\('speaking', '\{\{nom\}\} vous parle', \{ nom: qui \}\)/);
  assert.match(multi, /ouvrirConversationParId\(nonLu\.conversation_id, qui\)/);
  assert.match(lire('supabase.js'), /return \{ conversation_id: cid, auteur: dernierMessage\.auteur, id: dernierMessage\.id, salon: idsSalons\.has\(cid\) \};/);
  assert.match(lire('plateau-temps-reel.js'), /rejoindre\(SUJET_CHAT, 'chat_signaux', 'personnage=eq\.' \+ nom\);/);
});

test('Proximité : envoi par le serveur, « Message non parvenu » à l\'expéditeur', () => {
  assert.match(lire('supabase.js'), /sbRpc\('chat_envoyer', \{ p_conversation: conversationId, p_message: message, p_salon: false \}\)/);
  assert.match(lire('plateau-multijoueur.js'), /'Message non parvenu : votre interlocuteur a quitté la pièce\.'/);
});
