'use strict';
// Présence permanente et synchronisation immédiate (décisions de Fred du 20/11/2026).
// Essai annulé en base le 20/11 : Arnie dans la salle d'écoute de Krasnov, battement vieux d'une heure → toujours dans
// crim_presents de Tom Tom (connecte=false) ; neutralisation (Arnie envoyé à l'hôpital) → version de la salle d'écoute
// 2→3, salle d'hôpital signalée, signal d'Arnie 1→2, presences d'Arnie = hôpital ; l'écran d'Arnie qui repose l'ancien
// lieu dans presences est ignoré (position canonique).
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');

function chargerTempsReel(ctx) {
  const g = Object.assign({ document: { readyState: 'loading', hidden: false, addEventListener() {} }, setTimeout: (f) => f(), clearTimeout() {},
    setInterval() {}, clearInterval() {}, JSON, Number, Object, Promise, String }, ctx);
  g.window = g; g.globalThis = g;
  vm.runInNewContext(lire('plateau-temps-reel.js'), g);
  return g;
}

test('Serveur : présents tirés des positions, battement = « connecté », signaux sans nom publiés', () => {
  const sql = lire('migrations/20261120280000_presence_permanente_signaux.sql');
  assert.match(sql, /FROM public\.personnages_donnees q\s+LEFT JOIN public\.presences p ON p\.name = q\.name/);
  assert.match(sql, /coalesce\(p\.updated_at > now\(\) - interval '5 minutes', false\) AS connecte/);
  const masques = sql.slice(sql.indexOf('FUNCTION public.crim_masques_piece_interne'), sql.indexOf('FUNCTION public.crim_presents'));
  assert.doesNotMatch(masques, /presences/);
  assert.match(sql, /ALTER PUBLICATION supabase_realtime ADD TABLE public\.salles_signaux/);
  assert.match(sql, /ALTER PUBLICATION supabase_realtime ADD TABLE public\.personnages_signaux/);
  assert.match(sql, /USING \(personnage = public\.mon_personnage\(\)\)/);
  assert.match(sql, /CREATE TRIGGER presences_position_canonique BEFORE INSERT OR UPDATE ON public\.presences/);
  assert.match(sql, /NEW\.hospitalisation IS DISTINCT FROM OLD\.hospitalisation OR NEW\.pa IS DISTINCT FROM OLD\.pa/);
});

test('Déconnecté : reste visible et ciblable, marqué « Absent », jamais retiré', async () => {
  const sb = lire('supabase.js');
  const debut = sb.indexOf('async function sbGetPresencesInRoom('), fin = sb.indexOf('\n}\n', debut);
  const g = { state: null, sbRpc: null, Date, Object,
    sbGet: async () => [{ name: 'Arnie', updated_at: new Date(Date.now() - 3600e3).toISOString() }, { name: 'Bob', updated_at: new Date().toISOString() }] };
  vm.runInNewContext(sb.slice(debut, fin + 3) + ';this.f=sbGetPresencesInRoom;', g);
  const rows = await g.f('soviet', 'ville_b', 'station-radar-krasnov', 'salle_ecoutes');
  assert.equal(rows.length, 2);
  assert.equal(rows.find(r => r.name === 'Arnie').connecte, false);
  assert.equal(rows.find(r => r.name === 'Bob').connecte, true);
  const multi = lire('plateau-multijoueur.js');
  assert.match(multi, /p\.connecte === false\s+\? '<span class="rp-absent"/);
  assert.match(multi, /connecte: p\.connecte !== false,/);   // la cible reste dans getCurrentRoomPersons
});

test('Victime : un signal sur SON personnage recale l\'écran sans rechargement, avec un message', async () => {
  const appels = { position: null, toast: null, presents: 0 };
  const state = { country: 'soviet', currentCity: 'ville_b', currentBuilding: 'station-radar-krasnov', currentRoom: 'salle_ecoutes',
    char: { name: 'Arnie' }, hospitalisation: null, estEmprisonne: null };
  const g = chargerTempsReel({ state,
    sbLoadPersonnage: async () => ({ country: 'soviet', currentCity: 'ville_b', currentBuilding: 'dispensaire-public-v', currentRoom: 'chambre',
      hospitalisation: { lieu: 'dispensaire' }, estEmprisonne: null, hp: 1, pa: 0 }),
    afficherPositionNavigationConfirmee: (f) => { appels.position = f.currentBuilding; },
    showToast: (t, b) => { appels.toast = t + ' — ' + b; },
    chargerVraisJoueursPresents: () => { appels.presents++; } });
  g.RPTempsReel.traiterMessage({ topic: 'realtime:hg-personnage', event: 'postgres_changes', payload: { data: { record: { version: 2 } } } });
  await new Promise(r => setImmediate(r));
  await new Promise(r => setImmediate(r));
  assert.equal(appels.position, 'dispensaire-public-v');
  assert.match(appels.toast, /^Hospitalisation — Vous avez été conduit\(e\) à l’hôpital\.$/);
  assert.equal(state.hp, 1); assert.equal(state.pa, 0);
  assert.ok(appels.presents >= 1);
});

test('Présents : un signal de la salle relit la liste (sortie ou entrée visible aussitôt)', () => {
  let relu = 0;
  const g = chargerTempsReel({ state: { country: 'soviet', currentCity: 'ville_b', currentBuilding: 'b', currentRoom: 'r', char: { name: 'Tom Tom' } },
    chargerVraisJoueursPresents: () => { relu++; } });
  g.RPTempsReel.traiterMessage({ topic: 'realtime:hg-salle', event: 'postgres_changes', payload: { data: { record: { version: 3 } } } });
  assert.equal(relu, 1);
  assert.equal(g.RPTempsReel.cleSalle('soviet', 'ville_b', 'station-radar-krasnov', 'salle_ecoutes', null), 'soviet|ville_b|station-radar-krasnov|salle_ecoutes');
  assert.equal(g.RPTempsReel.cleSalle('soviet', 'ville_b', null, null, 'krasnov-rue-gare'), 'soviet|ville_b|rue|krasnov-rue-gare');
  // Messages explicatifs des déplacements subis.
  const m = g.RPTempsReel.messageChangement;
  assert.equal(m({ lieu: 'a', estEmprisonne: null }, { lieu: 'b', estEmprisonne: { jours: 2 } })[0], 'Arrestation');
  assert.equal(m({ lieu: 'a', estEmprisonne: { jours: 2 } }, { lieu: 'b', estEmprisonne: null })[0], 'Libération');
  assert.equal(m({ lieu: 'a' }, { lieu: 'b' })[0], 'Déplacement');
  assert.equal(m({ lieu: 'a' }, { lieu: 'a' }), null);
});

test('État périmé : un refus de position relance la resynchronisation ; module chargé par le plateau', () => {
  const sb = lire('supabase.js');
  assert.match(sb, /v\.ok === false && RP_RAISONS_ETAT_PERIME\.has\(v\.raison\)/);
  assert.match(sb, /'pas_sur_place', 'personnage_indisponible', 'sortie_invalide'/);
  assert.match(lire('plateau.html'), /<script src="plateau-temps-reel\.js\?v=[^"]+"><\/script>/);
  assert.match(lire('plateau-temps-reel.js'), /postgres_changes: \[\{ event: '\*', schema: 'public', table, filter: filtre \}\]/);
});
