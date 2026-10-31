// Banc client #295 (31/10/2026) : l'écran ne calcule ni n'écrit plus aucune caisse collective.
// Exécute les vraies fonctions (sbCaisseCollective, executerOrdreOrgaFinancier, sauvegarderOrga)
// avec un serveur simulé, et vérifie le code source pour les écritures directes. Aucun réseau.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert/strict');

const racine = path.resolve(__dirname, '..', '..');
const lire = f => fs.readFileSync(path.join(racine, f), 'utf8');
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
const SB = lire('supabase.js'), ORG = lire('plateau-organisations-quetes.js'), POL = lire('plateau-politique.js');

function contexte(reponses) {
  const stock = new Map(), appels = [], toasts = [], journal = [];
  const ctx = {
    console, JSON, Math, Number, String, Object, Array, Promise,
    crypto: { randomUUID: () => 'uuid-' + (appels.length + 1) + '-0000-0000' },
    localStorage: { getItem: k => stock.has(k) ? stock.get(k) : null, setItem: (k, v) => stock.set(k, String(v)), removeItem: k => stock.delete(k) },
    rpAuthUid: () => 'uid-1',
    state: { char: { name: 'Jean Jaaj' }, country: 'republic', pa: 10, liquide: 5000, arg: 5000, organisations: [] },
    COUNTRIES: { republic: { cur: 'FR' } },
    sbRpc: async (rpc, params) => { appels.push({ rpc, params }); const r = reponses.shift(); if (r instanceof Error) throw r; return r; },
    showToast: (t, m, ok) => toasts.push([t, m, ok]),
    addJournalEntry: m => journal.push(m),
    updateUI: () => {}, chargerOrganisations: () => { ctx._recharge = (ctx._recharge || 0) + 1; },
    appliquerPaiementServeur: r => { if (typeof r.pa === 'number') ctx.state.pa = r.pa; if (typeof r.liquide === 'number') ctx.state.liquide = r.liquide; },
    document: { getElementById: () => ({ classList: { remove() {} } }) }
  };
  vm.createContext(ctx);
  vm.runInContext(extraire(SB, 'sbCaisseCollective'), ctx);
  return { ctx, stock, appels, toasts, journal };
}

(async () => {
  await cas('aucune écriture directe de caisse de club ne subsiste dans l’écran', async () => {
    for (const f of fs.readdirSync(racine).filter(f => f.endsWith('.js'))) {
      const s = lire(f).split('\n').filter(l => !l.trim().startsWith('//')).join('\n');
      assert.doesNotMatch(s, /\bsbSaveBudgetClub\s*\(/, f + ' appelle encore sbSaveBudgetClub');
      assert.doesNotMatch(s, /\bcrediterBudgetClub\s*\(/, f + ' appelle encore crediterBudgetClub');
      assert.doesNotMatch(s, /sb(Upsert|Insert|Update|Delete)(Verdict)?\(\s*'budgets_clubs'/, f + ' écrit budgets_clubs');
    }
  });

  await cas('la caisse d’organisation n’est plus calculée par l’écran (collecte, dividendes, adhésion, fiscalité)', async () => {
    const code = [ORG, POL].map(s => s.split('\n').filter(l => !l.trim().startsWith('//')).join('\n')).join('\n');
    assert.doesNotMatch(code, /orga\.caisse\s*=\s*\(orga\.caisse/, 'calcul local de orga.caisse');
    assert.doesNotMatch(code, /o\.caisse\s*=\s*Math\.max/, 'ajustement fiscal local');
    assert.doesNotMatch(code, /orga_collecte:\s*\(\)\s*=>/, 'effet local de collecte');
    assert.doesNotMatch(code, /orga_dividendes:\s*\(\)\s*=>/, 'effet local de dividendes');
  });

  await cas('réponse perdue : le geste rejoue la même requête, une réponse nette la libère', async () => {
    const { ctx, appels, stock } = contexte([null, { ok: true, rejeu: true }, { ok: true }]);
    const r1 = await vm.runInContext("sbCaisseCollective('club_sponsoriser', {p_club:'c', p_montant:500}, ['c','sponsor',500])", ctx);
    assert.equal(r1.indetermine, true);
    assert.equal(stock.size, 1, 'la requête doit être conservée après une réponse perdue');
    await vm.runInContext("sbCaisseCollective('club_sponsoriser', {p_club:'c', p_montant:500}, ['c','sponsor',500])", ctx);
    assert.equal(appels[0].params.p_requete, appels[1].params.p_requete, 'le rejeu doit porter la même requête');
    assert.equal(stock.size, 0, 'une réponse nette libère la requête');
    await vm.runInContext("sbCaisseCollective('club_sponsoriser', {p_club:'c', p_montant:500}, ['c','sponsor',500])", ctx);
    assert.notEqual(appels[2].params.p_requete, appels[0].params.p_requete, 'un nouveau geste porte une nouvelle requête');
    assert.match(appels[2].params.p_requete, /^caisse-[A-Za-z0-9-]{8,100}$/);
  });

  await cas('dividendes : l’écran recopie le serveur (montant, caisse, PA, fiche)', async () => {
    const { ctx, toasts } = contexte([{ ok: true, montant: 300, caisse: 700, paiement: { ok: true, pa: 9 }, fiche: { liquide: 5300, arg: 5300 } }]);
    vm.runInContext(extraire(ORG, 'executerOrdreOrgaFinancier'), ctx);
    ctx.state.organisations = [{ id: 'o1', nom: 'Jaaj SA', caisse: 1000 }];
    await vm.runInContext("executerOrdreOrgaFinancier(state.organisations[0], 'orga_dividendes', {pa:1,cost:0})", ctx);
    assert.equal(ctx.state.organisations[0].caisse, 700);
    assert.equal(ctx.state.pa, 9);
    assert.equal(ctx.state.liquide, 5300);
    assert.deepEqual(toasts[0].slice(0, 1), ['Dividendes versés !']);
    assert.equal(ctx._recharge, 1, 'l’organisation canonique est relue');
  });

  await cas('refus serveur : nommé à l’écran, rien n’est modifié localement', async () => {
    const { ctx, toasts } = contexte([{ ok: false, raison: 'pas_gestionnaire_caisse' }]);
    vm.runInContext(extraire(ORG, 'executerOrdreOrgaFinancier'), ctx);
    ctx.state.organisations = [{ id: 'o1', nom: 'Jaaj SA', caisse: 1000 }];
    await vm.runInContext("executerOrdreOrgaFinancier(state.organisations[0], 'orga_dividendes', {pa:1,cost:0})", ctx);
    assert.equal(ctx.state.organisations[0].caisse, 1000);
    assert.equal(ctx.state.liquide, 5000);
    assert.deepEqual(toasts, [['Opération refusée', 'Vous ne gérez pas la caisse de cette organisation.', false]]);
  });

  await cas('sauvegarde d’organisation refusée : annoncée, état serveur rechargé', async () => {
    const { ctx, toasts } = contexte([]);
    ctx.RP_DERNIER_REFUS_ORGA = '{"message":"organisation_direction_non_autorisee"}';
    ctx.sbSaveOrganisation = async () => null;
    vm.runInContext(ORG.match(/const RP_ORGA_REFUS = \{[\s\S]*?\};/)[0].replace('const ', 'var '), ctx);
    vm.runInContext(extraire(ORG, 'sauvegarderOrga'), ctx);
    const ok = await vm.runInContext("sauvegarderOrga({id:'o1'})", ctx);
    assert.equal(ok, false);
    assert.deepEqual(toasts, [['Organisation non enregistrée', 'Seul le chef peut transmettre la direction.', false]]);
    assert.equal(ctx._recharge, 1);
  });

  await cas('sauvegarde acceptée : relecture de l’organisation corrigée par le serveur', async () => {
    const { ctx, toasts } = contexte([]);
    ctx.sbSaveOrganisation = async () => [{ id: 'o1' }];
    vm.runInContext(ORG.match(/const RP_ORGA_REFUS = \{[\s\S]*?\};/)[0].replace('const ', 'var '), ctx);
    vm.runInContext(extraire(ORG, 'sauvegarderOrga'), ctx);
    assert.equal(await vm.runInContext("sauvegarderOrga({id:'o1'})", ctx), true);
    assert.deepEqual(toasts, []);
    assert.equal(ctx._recharge, 1);
  });

  await cas('transfert : le règlement serveur précède toute bascule de licence', async () => {
    const f = extraire(ORG, 'repondreTransfertJoueur');
    assert.ok(f.indexOf("sbRpc('club_transfert_conclure'") > 0);
    assert.ok(f.indexOf("sbRpc('club_transfert_conclure'") < f.indexOf('licenceSportive ='), 'licence basculée avant le règlement');
    assert.doesNotMatch(f, /t\.statut = 'termine';\s*await sbMajTransfert\(transfertId, t\);\s*showToast\('Transfert accepté/);
  });

  await cas('subvention à un club ou une organisation : une seule porte serveur', async () => {
    const f = extraire(POL, 'confirmerSubventionMontant');
    assert.match(f, /sbCaisseCollective\('subvention_collective_verser'/);
    assert.match(extraire(POL, 'ajusterSoldeCibleFiscale'), /typeCible === 'club_sportif' \|\| typeCible === 'organisation'\) \{[\s\S]*?return null;/);
  });

  console.log(echecs ? echecs + ' échec(s)' : 'Tous les cas passent.');
  process.exit(echecs ? 1 : 0);
})();
