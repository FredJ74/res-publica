'use strict';
// Mission du 27/11/2026 (soir), étape 5 : cartons d'invitation de la Grande Salle du Pavillon (Novomirsk). Réservation
// inchangée ; invités choisis par celui qui a réservé ; carton nominatif valable le jour même ; remis à un PNJ de
// l'accueil sans contrôle d'identité ; accès à la seule Grande Salle jusqu'à minuit. Épreuves SQL passées en transaction
// annulée en production avant application.
// Usage : node --test outils/bancs/banc-pavillon-cartons-20261127.cjs
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const root = path.resolve(__dirname, '../..'), lire = f => fs.readFileSync(path.join(root, f), 'utf8');
const MIG = lire('migrations/20261127235000_pavillon_cartons_invitation.sql');
const fonction = n => { const i = MIG.indexOf('FUNCTION public.' + n + '('); const j = MIG.indexOf('CREATE OR REPLACE FUNCTION', i + 10); return MIG.slice(i, j > 0 ? j : undefined); };

test('serveur : envoi réservé à celui qui a réservé aujourd’hui ; carton du jour ; remise sans contrôle d’identité ; Grande Salle seule', () => {
  const env = fonction('pavillon_cartons_envoyer');
  assert.match(env, /r\.acteur IS DISTINCT FROM moi/);
  assert.match(env, /inventaire_deposer_interne\(v_nom, public\.pavillon_carton_objet_interne\(j, v_nom/);
  assert.match(env, /mail_systeme_poser_interne\('Pavillon des Ambassadeurs', v_nom/);
  const rem = fonction('pavillon_carton_remettre');
  assert.match(rem, /current_room IS DISTINCT FROM 'hall_pavillon'/);
  assert.match(rem, /'Touyana Dachieva', 'Alina Belokourova', 'Arkadi Belov'/);
  assert.match(rem, /\{carton,jour\}'\) IS DISTINCT FROM to_char\(j, 'YYYY-MM-DD'\)/);
  assert.doesNotMatch(rem, /nominatif'\) *(=|IS DISTINCT FROM) *moi/, 'aucun contrôle d’identité');
  const acc = fonction('acces_reserve_raison_interne');
  assert.match(acc, /p_piece = 'salle_reception' AND EXISTS \(SELECT 1 FROM public\.pavillon_acces_cartons/);
  assert.doesNotMatch(MIG, /FUNCTION public\.pavillon_acte\(/, 'réservation inchangée (1 500 PSK)');
});

test('écran : choix des invités après réservation, remise du carton par « Donner », descriptions corrigées', () => {
  assert.match(lire('plateau-pavillon.js'), /action==='reception' && typeof ouvrirCartonsInvitation==='function'/);
  assert.match(lire('plateau-justice-economie.js'), /obj\.type === 'carton_invitation' && typeof remettreCartonInvitation === 'function'/);
  const html = lire('plateau.html');
  assert.ok(html.indexOf('plateau-pavillon-cartons.js') > 0 && html.indexOf('plateau-pavillon-cartons.js') < html.indexOf('src="plateau-router.js'));
  const data = lire('data.js'), i = data.indexOf('      bureau_republia_novomirsk: {'), bloc = data.slice(i, data.indexOf('      bureau_khalija_novomirsk: {', i));
  assert.doesNotMatch(bloc, /Salle de Réception commune/);
  assert.match(bloc, /Grande Salle de Réception du Pavillon des Ambassadeurs/);
  assert.match(data, /acces_reserve_info/, '« Demander l’accès aux salons » garde sa fenêtre');
});

test('textes : neuf langues, mêmes clés', () => {
  const ctx = { window: {} };
  vm.runInNewContext(lire('plateau-pavillon-cartons.js'), ctx);
  const T = ctx.window.RP_PAVILLON_CARTONS_T, cles = o => Object.keys(o).sort().join() + '|' + Object.keys(o.r).sort().join();
  assert.deepEqual(Object.keys(T), ['fr', 'en', 'es', 'zh-TW', 'ru', 'ko', 'ar', 'pt-BR', 'de']);
  for (const l of Object.keys(T)) assert.equal(cles(T[l]), cles(T.fr), l);
});
