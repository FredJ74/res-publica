// Banc client PRIME DE SIGNATURE (31/10/2026, migration 20261031220000).
// Exécute la vraie fonction repondreTransfertJoueur avec un serveur simulé : l'écran n'ajoute plus
// aucune prime lui-même, il adopte la fiche rendue par le serveur, ne verse rien sur un refus ni
// sur un rejeu, et un double clic ne déclenche qu'un appel. Aucun réseau.
// Contre-épreuve : `--ancien <fichier>` exécute une ancienne version (doit échouer).
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert/strict');

const racine = path.resolve(__dirname, '..', '..');
const iAncien = process.argv.indexOf('--ancien');
const fichier = iAncien > 0 ? path.resolve(process.argv[iAncien + 1]) : path.join(racine, 'plateau-organisations-quetes.js');
const ORG = fs.readFileSync(fichier, 'utf8');
let echecs = 0;
const cas = async (nom, fn) => {
  try { await fn(); console.log('ok  ' + nom); }
  catch (e) { echecs++; console.log('ECHEC ' + nom + '\n    ' + e.message); }
};
function extraire(src, nom) {
  const m = src.match(new RegExp('(async\\s+)?function\\s+' + nom + '\\s*\\('));
  assert.ok(m, nom + ' introuvable');
  let i = src.indexOf('{', m.index), prof = 0;
  for (; i < src.length; i++) {
    if (src[i] === '{') prof++;
    else if (src[i] === '}' && --prof === 0) return src.slice(m.index, i + 1);
  }
  throw new Error(nom + ' non terminée');
}
const CORE = fs.readFileSync(path.join(racine, 'plateau-core.js'), 'utf8');

const TRANSFERT = { joueur: 'Vince Kubrick', clubDepartId: 'olympique-luthecia', clubArriveeId: 'cheminote-montrouge',
                    prixClub: 400, prixJoueur: 300, statut: 'attente_joueur' };

function contexte(reponse, delai = 0) {
  const appels = [], toasts = [], journal = [];
  const ctx = {
    console, JSON, Math, Number, String, Object, Array, Promise, setTimeout,
    state: { char: { name: 'Vince Kubrick', arg: 200 }, liquide: 200, arg: 200, day: 3 },
    document: { getElementById: () => ({ classList: { remove() {} } }) },
    sbGet: async () => [{ data: JSON.parse(JSON.stringify(TRANSFERT)) }],
    sbMajTransfert: async () => true,
    sbRpc: async (rpc, params) => {
      appels.push({ rpc, params });
      if (delai) await new Promise(r => setTimeout(r, delai));
      if (reponse instanceof Error) throw reponse;
      return reponse;
    },
    chargerOuInitialiserSaison: async () => ({ numero: 2 }),
    getClub: id => ({ nom: id }),
    updateUI: () => {}, enterRoom: () => {},
    showToast: (t, m, ok) => toasts.push([t, m, ok]),
    addJournalEntry: m => journal.push(m),
  };
  vm.createContext(ctx);
  vm.runInContext(extraire(CORE, 'crediterFondsOrdinaires'), ctx);
  vm.runInContext(extraire(ORG, 'repondreTransfertJoueur'), ctx);
  return { ctx, appels, toasts, journal };
}

(async () => {
  await cas('accepté : l écran adopte la fiche du serveur, sans ajouter la prime une seconde fois', async () => {
    const { ctx, appels, toasts } = contexte({ ok: true, prime: 300, fiche: { liquide: 500, arg: 500 } });
    await ctx.repondreTransfertJoueur('t1', true);
    assert.equal(appels.length, 1);
    assert.deepEqual([ctx.state.liquide, ctx.state.arg, ctx.state.char.arg], [500, 500, 500]);
    assert.equal(ctx.state.char.licenceSportive.clubId, 'cheminote-montrouge');
    assert.match(toasts.at(-1)[1], /Prime de signature reçue : 300/);
  });
  await cas('refus du serveur (caisse insuffisante) : ni argent ni licence', async () => {
    const { ctx, toasts } = contexte({ ok: false, raison: 'caisse_club_insuffisante' });
    await ctx.repondreTransfertJoueur('t1', true);
    assert.deepEqual([ctx.state.liquide, ctx.state.arg], [200, 200]);
    assert.equal(ctx.state.char.licenceSportive, undefined);
    assert.equal(toasts.at(-1)[2], false);
  });
  await cas('réponse perdue : rien n est versé', async () => {
    const { ctx } = contexte(new Error('réseau'));
    await ctx.repondreTransfertJoueur('t1', true);
    assert.deepEqual([ctx.state.liquide, ctx.state.arg], [200, 200]);
  });
  await cas('reconnexion / rejeu : la fiche canonique est adoptée, aucun second versement', async () => {
    const { ctx, toasts } = contexte({ ok: true, rejeu: true, prime: 300, fiche: { liquide: 500, arg: 500 } });
    await ctx.repondreTransfertJoueur('t1', true);
    assert.deepEqual([ctx.state.liquide, ctx.state.arg], [500, 500]);
    assert.equal(toasts.at(-1)[0], 'Transfert déjà conclu');
  });
  await cas('double clic : un seul appel au serveur, une seule adoption', async () => {
    const { ctx, appels } = contexte({ ok: true, prime: 300, fiche: { liquide: 500, arg: 500 } }, 20);
    await Promise.all([ctx.repondreTransfertJoueur('t1', true), ctx.repondreTransfertJoueur('t1', true)]);
    assert.equal(appels.length, 1);
    assert.deepEqual([ctx.state.liquide, ctx.state.arg], [500, 500]);
  });
  await cas('source : plus aucun crédit local de la prime', async () => {
    const f = extraire(ORG, 'repondreTransfertJoueur');
    assert.doesNotMatch(f, /crediterFondsOrdinaires|state\.liquide\s*\+=|prixJoueur/);
  });
  console.log(echecs ? echecs + ' échec(s).' : 'Tous les cas passent.');
  process.exit(echecs ? 1 : 0);
})();
