// Garde-fou : départ lisible de l'enquête du musée de Luthécia (décisions de Fred, 13/11/2026).
// Charge plateau-enigme-portrait.js hors navigateur, avec un serveur simulé (sbRpcVerdict).
// Vérifie : ordre et description seulement pendant l'enquête et dans les 4 salles ; l'examen passe
// par le serveur et la fiche rendue est adoptée ; le calepin liste les cadres vus ; l'accueil de
// Valérie ne s'ouvre qu'à la réponse « premiere » du serveur ; le débarras n'écrit plus la fiche.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const racine = new URL('../../', import.meta.url);
const source = fs.readFileSync(new URL('plateau-enigme-portrait.js', racine), 'utf8');
const routeur = fs.readFileSync(new URL('plateau-router.js', racine), 'utf8');
const navigation = fs.readFileSync(new URL('plateau-navigation.js', racine), 'utf8');

function contexte() {
  const els = {};
  const el = id => (els[id] ||= { id, textContent: '', innerHTML: '', style: {}, classList: { add() { this.open = true; }, remove() { this.open = false; } },
    setAttribute() {}, querySelectorAll: () => [], appendChild() {} });
  const appels = []; const toasts = []; let reponse = null; let sauvegardes = 0;
  const ctx = {
    console, window: {}, document: { getElementById: el },
    state: { char: { name: 'Test', enigme1: { etape: 'declenchee', variante: 'maire' } }, inventory: [], currentBuilding: 'musee-ville-luthecia', currentRoom: 'hall' },
    showToast: (t, m, ok) => toasts.push({ t, m, ok }),
    sbRpcVerdict: async (fn, p) => { appels.push({ fn, p }); return typeof reponse === 'function' ? reponse(p) : reponse; },
    sbSavePersonnage: async () => { sauvegardes++; },
    renderInventory() {}, addJournalEntry() {}, updateUI() {}
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(source, ctx);
  return { ctx, els, appels, toasts, set reponse(r) { reponse = r; }, get sauvegardes() { return sauvegardes; } };
}

// 1. Ordre et description : seulement pendant l'enquête et dans les quatre salles.
{
  const t = contexte(); const { ctx } = t;
  assert.equal(ctx.ordresEnigme1Musee('musee-ville-luthecia', 'salle_maires').length, 1);
  assert.equal(ctx.ordresEnigme1Musee('musee-ville-luthecia', 'salle_maires')[0].fn, 'enigme1_examiner_cadre');
  assert.equal(ctx.ordresEnigme1Musee('musee-ville-luthecia', 'salle_maires')[0].pa, 0);
  for (const s of ['salle_criminels', 'salle_entrepreneurs', 'salle_plumes']) assert.equal(ctx.ordresEnigme1Musee('musee-ville-luthecia', s).length, 1);
  assert.equal(ctx.ordresEnigme1Musee('musee-ville-luthecia', 'salle_unions').length, 0);
  assert.equal(ctx.ordresEnigme1Musee('musee-national-republia', 'salle_maires').length, 0);
  assert.match(ctx.enigme1SuffixeDescription('musee-ville-luthecia', 'salle_plumes'), /cadre vide/);
  ctx.state.char.enigme1 = { etape: 'non_commencee' };
  assert.equal(ctx.ordresEnigme1Musee('musee-ville-luthecia', 'salle_maires').length, 0);
  assert.equal(ctx.enigme1SuffixeDescription('musee-ville-luthecia', 'salle_maires'), '');
  ctx.state.char.enigme1 = { etape: 'resolue' };
  assert.equal(ctx.ordresEnigme1Musee('musee-ville-luthecia', 'salle_maires').length, 0);
  assert.ok(ctx.window.RP_ORDRES_DYNAMIQUES.includes(ctx.ordresEnigme1Musee));
}

// 2. Examen : appel serveur, fiche adoptée, fenêtre ouverte, calepin à jour ; refus nommé.
{
  const t = contexte(); const { ctx, els, appels, toasts } = t;
  ctx.state.currentRoom = 'salle_maires';
  t.reponse = { ok: true, nouveau: true, salle: 'salle_maires', enigme: { etape: 'declenchee', variante: 'maire', cadresVus: ['salle_maires'] } };
  await ctx.enigme1ExaminerCadre();
  assert.equal(JSON.stringify(appels.at(-1)), JSON.stringify({ fn: 'enigme1_musee', p: { p_action: 'examiner', p_salle: 'salle_maires' } }));
  assert.deepEqual([...ctx.state.char.enigme1.cadresVus], ['salle_maires']);
  assert.equal(els['postes-modal-title'].textContent, 'Cadre vide');
  assert.ok(toasts.some(x => x.t === 'Calepin mis à jour'));
  assert.equal(t.sauvegardes, 0, "l'examen ne sauvegarde pas la fiche depuis l'écran");
  ctx.state.inventory = [{}];
  ctx.enigme1AfficherCalepin(0);
  assert.match(els['postes-body'].innerHTML, /Musée : portrait manquant de Marcel Torcieu \(1895–1958\)/);
  assert.ok(els['postes-body'].innerHTML.indexOf('Musée : portrait manquant') < els['postes-body'].innerHTML.indexOf('Énigme du musée'));
  els['postes-modal-title'].textContent = '';
  t.reponse = { ok: false, raison: 'pas_sur_place' };
  await ctx.enigme1ExaminerCadre();
  assert.equal(els['postes-modal-title'].textContent, '', 'pas de fenêtre sur refus');
  assert.ok(toasts.at(-1).ok === false && /plus dans cette salle/.test(toasts.at(-1).m));
}

// 3. Accueil de Valérie : seulement sur « premiere » du serveur, jamais rappelé une fois vu.
{
  const t = contexte(); const { ctx, els, appels } = t;
  t.reponse = { ok: true, premiere: true, enigme: { etape: 'declenchee', accueilValerie: true } };
  await ctx.enigme1AccueilHall('musee-ville-luthecia', 'hall');
  assert.match(els['postes-modal-title'].textContent, /Valérie Loisillon/);
  assert.match(els['postes-body'].innerHTML, /excuses/);
  assert.match(els['postes-body'].innerHTML, /amputée/);
  assert.doesNotMatch(els['postes-body'].innerHTML, /Gérard/);
  const n = appels.length;
  await ctx.enigme1AccueilHall('musee-ville-luthecia', 'hall');
  assert.equal(appels.length, n, 'accueil déjà vu : aucun nouvel appel');
  const t2 = contexte();
  t2.reponse = { ok: true, premiere: false, enigme: { etape: 'declenchee', accueilValerie: true } };
  await t2.ctx.enigme1AccueilHall('musee-ville-luthecia', 'hall');
  assert.equal(t2.els['postes-modal-title']?.textContent || '', '');
  const t3 = contexte(); t3.ctx.state.char.enigme1 = { etape: 'non_commencee' };
  await t3.ctx.enigme1AccueilHall('musee-ville-luthecia', 'hall');
  assert.equal(t3.appels.length, 0, 'pas d\'appel hors enquête');
}

// 4. Débarras : la résolution vient du serveur ; l'écran n'écrit plus « resolue » lui-même.
{
  const t = contexte(); const { ctx, els, appels } = t;
  ctx.state.inventory = [{ id: 'cle-debarras-musee' }];
  t.reponse = { ok: true, premiere: true, enigme: { etape: 'resolue', debarrasOuvert: true } };
  ctx.enigme1VerifierDebarras('musee-ville-luthecia', 'debarras');
  assert.equal(ctx.state.char.enigme1.etape, 'declenchee', "rien n'est écrit avant la réponse");
  await ctx.state._enigme1Sauvegarde; await new Promise(r => setTimeout(r, 0));
  assert.equal(JSON.stringify(appels.at(-1)), JSON.stringify({ fn: 'enigme1_musee', p: { p_action: 'debarras' } }));
  assert.equal(ctx.state.char.enigme1.etape, 'resolue');
  assert.equal(els['postes-modal-title'].textContent, 'Le Débarras');
  assert.equal(t.sauvegardes, 0);
  assert.doesNotMatch(source, /enigme1\.etape = 'resolue'/);
}

// 5. Raccordements : routeur, description et entrée dans le hall.
assert.match(routeur, /fn === 'enigme1_examiner_cadre'[^\n]*enigme1ExaminerCadre\(\)/);
assert.match(navigation, /enigme1SuffixeDescription\(buildingId, roomId\)/);
assert.match(navigation, /enigme1AccueilHall\(buildingId, roomId\)/);

console.log('test-enigme1-musee-depart-20261113 : OK');
