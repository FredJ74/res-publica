// Correctif du 26/11/2026 : l'en-tête des entrepôts publics lit la caisse canonique (caisses_batiments.<pays>_entrepot_<ville>)
// et non plus l'ancien emplacement etat.entrepot.caisse (abandonné le 8 octobre), qui affichait 0. Achat : 5 000 → 5 150 FR
// sans rechargement ; échec de lecture : « indisponible », jamais un faux zéro ; réponse tardive ignorée ; six entrepôts.
// Lancer : node --test outils/bancs/test-caisse-entrepot-20261126.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import vm from 'node:vm';

const racine = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = f => readFileSync(path.join(racine, f), 'utf8');
const nav = lire('plateau-navigation.js'), eco = lire('plateau-justice-economie.js');
const extrait = (src, debut, fin) => { const i = src.indexOf(debut); assert.ok(i >= 0, debut); return src.slice(i, src.indexOf(fin, i)); };
const bloc = extrait(nav, 'function rpBuildingHeaderText(', 'function enterBuilding(');
const achat = extrait(eco, 'async function confirmerAchatEntrepot(', '\n}\n') + '\n}\n';

function monde(caisses) {
  const el = { style: {}, texte: '', attrs: {}, setAttribute(k, v) { this.attrs[k] = v; },
    replaceChildren(n) { this.texte = n.textContent; this.cle = n.attrs['data-i18n']; } };
  const lectures = [];
  const ctx = {
    console, Promise, Number, Object, JSON, Math, parseInt,
    state: { currentBuilding: 'entrepot-logistique-luthecia', country: 'republic', currentCity: 'capitale', char: { name: 'Olga', country: 'soviet' } },
    COUNTRIES: { republic: { cur: 'FR' }, soviet: { cur: 'PSK' } },
    RESSOURCES_ECONOMIE: { bois: { label: 'Bois' } },
    document: { createElement: () => ({ textContent: '', attrs: {}, setAttribute(k, v) { this.attrs[k] = v; } }),
      getElementById: id => id === 'bat-caisse' ? el : id === 'achat-entrepot-bois' ? { value: '30' } : null },
    sbGetCaisseBatiment: (cle, opts) => { lectures.push({ cle, opts }); return caisses(cle); },
    executerReceptionInventaire: async () => { ctx.solde += 150; return { ok: true, paye: 150, lignes: [{ qte: 30, cle: 'bois' }] }; },
    renderInventory() {}, updateUI() {}, showToast() {}, addJournalEntry() {}, globalThis: {}, solde: 5000
  };
  vm.createContext(ctx); vm.runInContext(bloc + achat, ctx);
  return { ctx, el, lectures };
}

test('achat à Luthécia : 5 000 FR avant, 5 150 FR après, sans rechargement ; monnaie du pays de l’entrepôt', async () => {
  const m = monde(async () => ({ solde: m.ctx.solde }));
  await m.ctx.rpAfficherCaisseEntrepot();
  assert.equal(m.el.texte, 'Caisse : 5 000 FR');
  await m.ctx.confirmerAchatEntrepot('entrepot-logistique-luthecia', 0, 0);
  await new Promise(r => setTimeout(r, 0));
  assert.equal(m.el.texte, 'Caisse : 5 150 FR');
  assert.deepEqual(m.lectures.map(l => [l.cle, l.opts.strict]), [['republic_entrepot_capitale', true], ['republic_entrepot_capitale', true]]);
});

test('échec de lecture ou caisse absente : « indisponible », jamais 0', async () => {
  for (const reponse of [() => Promise.reject(new Error('reseau')), async () => null, async () => ({})]) {
    const m = monde(reponse);
    assert.equal(await m.ctx.rpAfficherCaisseEntrepot(), null);
    assert.equal(m.el.cle, 'plateau.buildingCashUnavailable');
    assert.doesNotMatch(m.el.texte, /\b0\b/);
  }
});

test('réponse arrivée après un changement de bâtiment, de ville ou de pays : ignorée', async () => {
  for (const changer of [s => { s.currentBuilding = 'marche'; }, s => { s.currentCity = 'ville_a'; }, s => { s.country = 'soviet'; }]) {
    let liberer; const m = monde(() => new Promise(r => { liberer = r; }));
    m.el.texte = 'avant';
    const p = m.ctx.rpAfficherCaisseEntrepot();
    changer(m.ctx.state); liberer({ solde: 5000 }); await p;
    assert.equal(m.el.texte, 'avant');
  }
  let liberer1; let n = 0; const m = monde(() => n++ === 0 ? new Promise(r => { liberer1 = r; }) : Promise.resolve({ solde: 5150 }));
  const p1 = m.ctx.rpAfficherCaisseEntrepot(); await m.ctx.rpAfficherCaisseEntrepot();
  liberer1({ solde: 5000 }); await p1;
  assert.equal(m.el.texte, 'Caisse : 5 150 FR', 'une lecture plus ancienne n’écrase pas la plus récente');
});

test('six entrepôts couverts (Républia et Sovarka), ancien emplacement abandonné, rafraîchi après achat', async () => {
  const cas = [['entrepot-logistique-luthecia', 'republic', 'capitale'], ['entrepot-logistique-psm', 'republic', 'ville_a'],
    ['entrepot-logistique-montrouge', 'republic', 'ville_b'], ['entrepot-logistique-novomirsk', 'soviet', 'capitale'],
    ['entrepot-logistique-starovka', 'soviet', 'ville_a'], ['entrepot-logistique-krasnov', 'soviet', 'ville_b']];
  for (const [b, pays, ville] of cas) {
    const m = monde(async () => ({ solde: 5000 }));
    Object.assign(m.ctx.state, { currentBuilding: b, country: pays, currentCity: ville });
    await m.ctx.rpAfficherCaisseEntrepot();
    assert.equal(m.lectures[0].cle, pays + '_entrepot_' + ville);
    assert.equal(m.el.texte, 'Caisse : 5 000 ' + (pays === 'soviet' ? 'PSK' : 'FR'));
  }
  assert.doesNotMatch(nav, /etat\?\.\[cleCaisse\]\?\.caisse/);
  assert.match(lire('supabase.js'), /if \(!rows && opts && opts\.strict\) throw/);
});
