// Banc : la fiche PJ du navigateur n'est jamais autoritaire (clôture Luthécia, 30/10/2026).
// Exécute réellement supabase.js dans un bac à sable (transports simulés, aucun accès à Supabase),
// puis rejoue les mêmes contrôles sur des copies où un défaut connu est réintroduit : chacune doit
// être détectée (contre-épreuves par mutation).
'use strict';
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const R = path.join(__dirname, '..', '..');
const SB = fs.readFileSync(path.join(R, 'supabase.js'), 'utf8');
const CORE = fs.readFileSync(path.join(R, 'plateau-core.js'), 'utf8');
const RUE = fs.readFileSync(path.join(R, 'plateau-rue-centrale.js'), 'utf8');
const MIG = fs.readFileSync(path.join(R, 'migrations/20261030160000_fiche_fusion_trois_voies.sql'), 'utf8');

function bac(source, reponses) {
  const appels = [];
  const ctx = {
    console: { log() {}, error() {}, warn() {} }, setTimeout, clearTimeout, JSON, Object, Array, Map, Set, Symbol,
    Promise, Number, String, Math, Date, Error, encodeURIComponent,
    document: { addEventListener() {}, getElementById() { return null; } },
    localStorage: { getItem() { return null; }, setItem() {}, removeItem() {} },
    navigator: {}, location: { href: '' }, addEventListener() {},
    rpAuthJeton: () => 'jeton-fictif', rpAuthUid: () => 'uid-fictif',
    fetch: async (url, init) => {
      appels.push({ url: String(url), init });
      const r = reponses(String(url), init, appels.length);
      if (r instanceof Error) throw r;
      await new Promise(res => setTimeout(res, 5));
      return { ok: r.status < 400, status: r.status, headers: { get: () => null },
        json: async () => r.corps, text: async () => JSON.stringify(r.corps) };
    }
  };
  ctx.window = ctx;
  vm.createContext(ctx);
  vm.runInContext(source, ctx);
  return { ctx, appels };
}

function etatFictif() {
  return { char: { name: 'Essai Fictif', reservationHotel: null, excommunie: null }, country: 'republic',
    pa: 3, hp: 80, moral: 70, currentCity: 'capitale', currentBuilding: 'bat-a', currentRoom: 'salle-a',
    estEmprisonne: null, ficheFusion: true, personnageChargeDepuisServeur: true };
}

async function controles(src) {
  const echecs = [];
  const t = (nom, ok) => { if (!ok) echecs.push(nom); };

  // 1. Base et valeurs envoyées calculées de la même façon ; base jointe seulement si le serveur la connaît.
  {
    const { ctx } = bac(src, () => ({ status: 200, corps: [] }));
    const s = etatFictif();
    s._ficheBase = ctx.sbFicheChampsFusion(s);
    const p = ctx.sbPayloadPersonnage(s);
    t('fiche_base jointe a la sauvegarde', p.fiche_base && p.fiche_base.pa === 3 && p.fiche_base.current_room === 'salle-a');
    t('valeur envoyee = meme calcul que la base', JSON.stringify(ctx.sbFicheChampsFusion(s)) === JSON.stringify(Object.fromEntries(Object.keys(ctx.sbFicheChampsFusion(s)).map(k => [k, p[k]]))));
    s.ficheFusion = false;
    t('aucune base envoyee tant que la migration n est pas appliquee', !('fiche_base' in ctx.sbPayloadPersonnage(s)) || ctx.sbPayloadPersonnage(s).fiche_base === undefined);
  }

  // 2. Recalage : le serveur a gardé ses PA (20) et sa prison ; l'écran les adopte et la base avance.
  {
    const { ctx } = bac(src, () => ({ status: 200, corps: [] }));
    const s = etatFictif();
    s._ficheBase = ctx.sbFicheChampsFusion(s);
    const envoye = ctx.sbPayloadPersonnage(s);
    const ligne = Object.assign({}, envoye, { pa: 20, est_emprisonne: { motif: 'essai' } });
    ctx.sbFicheRecaler(s, envoye, ligne);
    t('recalage PA sur la verite serveur', s.pa === 20);
    t('recalage prison sur la verite serveur', s.estEmprisonne && s.estEmprisonne.motif === 'essai');
    t('base = verite serveur apres ecriture', s._ficheBase.pa === 20);
    // Changement local survenu après l'envoi : jamais écrasé par le recalage.
    const s2 = etatFictif(); s2._ficheBase = ctx.sbFicheChampsFusion(s2);
    const env2 = ctx.sbPayloadPersonnage(s2); s2.pa = 1;
    ctx.sbFicheRecaler(s2, env2, Object.assign({}, env2, { pa: 20 }));
    t('changement local posterieur preserve', s2.pa === 1 && s2._ficheBase.pa === 20);
  }

  // 3. Valeur adoptée du serveur (paiement, rue) : la base avance.
  {
    const { ctx } = bac(src, () => ({ status: 200, corps: [] }));
    ctx.state = etatFictif(); ctx.state._ficheBase = ctx.sbFicheChampsFusion(ctx.state);
    ctx.sbFicheBaseAdopter({ pa: 8, current_building: null, inconnu: 1 });
    t('adoption serveur avance la base', ctx.state._ficheBase.pa === 8 && ctx.state._ficheBase.current_building === null && !('inconnu' in ctx.state._ficheBase));
  }

  // 4. Double clic : un seul envoi pour deux appels identiques simultanés.
  {
    const { ctx, appels } = bac(src, (u) => ({ status: 200, corps: { ok: true } }));
    const [a, b] = await Promise.all([ctx.sbRpcVerdict('objet_acheter', { p_modele: 'x' }), ctx.sbRpcVerdict('objet_acheter', { p_modele: 'x' })]);
    const rpc = appels.filter(c => c.url.includes('/rpc/objet_acheter')).length;
    t('double clic : un seul achat envoye', rpc === 1 && a.ok === true && b.ok === true);
    await ctx.sbRpcVerdict('objet_acheter', { p_modele: 'x' });
    t('appel suivant (apres reponse) bien envoye', appels.filter(c => c.url.includes('/rpc/objet_acheter')).length === 2);
  }

  // 5. Réponse perdue après envoi : relecture serveur programmée, aucune sauvegarde.
  {
    const { ctx, appels } = bac(src, (u, init) => u.includes('/rpc/') ? new Error('reseau coupe') : ({ status: 200, corps: [{ pa: 4, hp: 80, arg: 10, liquide: 10 }] }));
    ctx.state = etatFictif(); ctx.state._ficheBase = ctx.sbFicheChampsFusion(ctx.state); ctx.state.personnageChargeDepuisServeur = true;
    const v = await ctx.sbRpcVerdict('objet_acheter', { p_modele: 'y' });
    await new Promise(r => setTimeout(r, 1700));
    const relu = appels.some(c => c.url.includes('/rest/v1/personnages') && (!c.init || !c.init.method || c.init.method === 'GET'));
    const ecrit = appels.some(c => c.url.includes('/rest/v1/personnages') && c.init && c.init.method === 'PATCH');
    t('reponse perdue : verdict non reussi', v.ok === false);
    t('reponse perdue : relecture de la fiche serveur', relu && ctx.state.pa === 4 && ctx.state._ficheBase.pa === 4);
    t('reponse perdue : aucune sauvegarde declenchee', !ecrit);
  }
  // 6. File de sauvegarde réelle : le PATCH porte la base, la ligne renvoyée recale l'écran.
  {
    let corpsEnvoye = null;
    const { ctx } = bac(src, (u, init) => {
      if (init && init.method === 'PATCH') {
        corpsEnvoye = JSON.parse(init.body);
        return { status: 200, corps: [Object.assign({}, corpsEnvoye, { pa: 20, fiche_base: null, updated_at: '2026-10-30T12:00:00Z' })] };
      }
      return { status: 200, corps: [] };
    });
    const s = etatFictif(); s._ficheBase = ctx.sbFicheChampsFusion(s); ctx.state = s;
    await ctx.sbSavePersonnage(s);
    t('file : base envoyee au serveur', corpsEnvoye && corpsEnvoye.fiche_base && corpsEnvoye.fiche_base.pa === 3);
    t('file : ecran recale sur la ligne renvoyee', s.pa === 20 && s._ficheBase.pa === 20);
    const s2 = etatFictif(); s2.personnageChargeDepuisServeur = false; ctx.state = s2; corpsEnvoye = null;
    await ctx.sbSavePersonnage(s2);
    t('file : fiche non relue = aucune ecriture', corpsEnvoye === null);
  }
  return echecs;
}

function controlesStatiques(core, rue, mig) {
  const echecs = [];
  const t = (nom, ok) => { if (!ok) echecs.push(nom); };
  const debut = core.indexOf('function loadCharacter()');
  const load = core.slice(debut, core.indexOf('\nfunction ', debut + 25));
  t('lecture echouee : aucune autorite locale', /\.catch\(e => \{\s*rpDiagId\('reconciliation'[\s\S]{0,400}?personnageChargeDepuisServeur = false/.test(load));
  t('seule une fiche recue autorise', /state\.personnageChargeDepuisServeur = !!sbState;/.test(load));
  t('aucun repli autoritaire', !/personnageChargeDepuisServeur = true/.test(load));
  t('base de fusion posee au chargement', /state\._ficheBase = sbState && typeof sbFicheChampsFusion/.test(load));
  t('paiement serveur avance la base', /sbFicheBaseAdopter\(\{ pa: r\.pa \}\)/.test(core));
  t('rue : base avance', /sbFicheBaseAdopter\(\{current_building:null,current_room:null\}\)/.test(rue));
  t('serveur : conflit = serveur l emporte', /ELSE\s+r := r \|\| jsonb_build_object\(f, c\);\s+-- conflit/.test(mig) && !/round\(/.test(mig));
  t('serveur : base jamais stockee', /NEW\.fiche_base := NULL;/.test(mig));
  return echecs;
}

const MUTATIONS = [
  ['repli autoritaire apres panne', 'core', s => s.replace("state.personnageChargeDepuisServeur = false; // réponse serveur perdue", "state.personnageChargeDepuisServeur = true; // réponse serveur perdue")],
  ['base jamais envoyee', 'sb', s => s.replace('data.fiche_base = charState._ficheBase;', '')],
  ['recalage absent', 'sb', s => s.replace('    sbFicheRecaler(charState, data, ligne);\n', '')],
  ['recalage ecrase un changement local', 'sb', s => s.replace("    if (JSON.stringify(actuel) !== JSON.stringify(envoye[k] ?? null)) continue;\n", '')],
  ['double clic non bloque', 'sb', s => s.replace('if (cle && SB_RPC_EN_VOL.has(cle)) return SB_RPC_EN_VOL.get(cle);', '')],
  ['aucune relecture apres incertitude', 'sb', s => s.replace("(env.etat === 'reseau' || (Number(env.http) >= 500))) sbResynchroniserApresIncertitude();", "false) sbResynchroniserApresIncertitude();")],
  ['paiement sans base', 'core', s => s.replace('sbFicheBaseAdopter({ pa: r.pa });', '')],
  ['regle de variation dangereuse', 'mig', s => s + "\n-- round(\n"]
];

(async () => {
  let ko = 0;
  const base = (await controles(SB)).concat(controlesStatiques(CORE, RUE, MIG));
  if (base.length) { ko++; console.log('ECHEC sur le code livre : ' + base.join(' ; ')); }
  else console.log('ok    code livre : 23 controles');
  for (const [nom, cible, muter] of MUTATIONS) {
    const sb = cible === 'sb' ? muter(SB) : SB, core = cible === 'core' ? muter(CORE) : CORE, mig = cible === 'mig' ? muter(MIG) : MIG;
    if ((cible === 'sb' && sb === SB) || (cible === 'core' && core === CORE)) { ko++; console.log('ECHEC mutation inapplicable : ' + nom); continue; }
    const e = (await controles(sb)).concat(controlesStatiques(core, RUE, mig));
    if (e.length === 0) { ko++; console.log('ECHEC contre-epreuve non detectee : ' + nom); }
    else console.log('ok    contre-epreuve detectee : ' + nom + ' (' + e[0] + ')');
  }
  console.log(ko ? `\n${ko} echec(s)` : `\nbanc vert : code livre + ${MUTATIONS.length} contre-epreuves`);
  process.exit(ko ? 1 : 0);
})();
