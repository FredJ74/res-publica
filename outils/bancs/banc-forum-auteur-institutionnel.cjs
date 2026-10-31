// Banc de non-régression (31/10/2026, clôture Luthécia) : publications forum refusées par la base.
// La politique RLS de forum_topics/forum_posts n'accepte que author = personnage, ou
// author_real = personnage. Trois publications de l'écran échouaient en silence (403 relevés en
// production) :
//   1. le sondage commandé (plateau-divers.js) : texte passé comme auteur, nom comme pays ;
//   2. l'affaire transmise au tribunal (plateau-justice-economie.js), signée « Brigade Criminelle » ;
//   3. le retrait d'un projet (plateau-assemblee.js), signé « Secrétariat de l'Assemblée ».
// Le banc exécute le vrai publierSondage avec un forum simulé, puis vérifie que les deux
// publications institutionnelles portent author_real. Aucun accès réseau.
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

function extraireFonction(src, nom) {
  const debut = src.indexOf('async function ' + nom + '(');
  assert.ok(debut >= 0, nom + ' introuvable');
  let i = src.indexOf('{', debut), prof = 0;
  for (; i < src.length; i++) {
    if (src[i] === '{') prof++;
    else if (src[i] === '}' && --prof === 0) return src.slice(debut, i + 1);
  }
  throw new Error(nom + ' non terminée');
}

async function jouerSondage(ecritureReussie) {
  const appels = [], toasts = [];
  const ctx = {
    state: { char: { name: 'Angie Porcelana' }, country: 'republic', day: 3 },
    document: { getElementById: () => ({ classList: { remove() {} } }) },
    idForumLocal: () => 'local_capitale',
    formatDateHeureJeu: () => 'J3 10:00',
    sbCreateTopic: async (...a) => { appels.push(['topic', ...a]); return ecritureReussie ? 'topic-1' : null; },
    sbCreatePost: async (...a) => { appels.push(['post', ...a]); return 'post-1'; },
    showToast: (titre, msg, ok) => toasts.push([titre, ok]),
    addJournalEntry: () => {}
  };
  vm.createContext(ctx);
  vm.runInContext(extraireFonction(lire('plateau-divers.js'), 'publierSondage'), ctx);
  await vm.runInContext('publierSondage("Faut-il rouvrir le marché ?")', ctx);
  return { appels, toasts };
}

(async () => {
  await cas('sondage : le sujet porte l’auteur réel et le pays, le texte devient le message', async () => {
    const { appels, toasts } = await jouerSondage(true);
    const topic = appels.find(a => a[0] === 'topic');
    assert.ok(topic, 'aucun sujet créé');
    assert.equal(topic[3], 'Angie Porcelana', 'auteur du sujet');
    assert.equal(topic[4], 'republic', 'pays du sujet');
    const post = appels.find(a => a[0] === 'post');
    assert.ok(post && post[2] === 'Angie Porcelana' && post[3] === 'Faut-il rouvrir le marché ?', 'message du sondage');
    assert.deepEqual(toasts, [['Sondage publié !', true]]);
  });

  await cas('sondage refusé par la base : aucun succès annoncé', async () => {
    const { toasts } = await jouerSondage(false);
    assert.deepEqual(toasts, [['Publication impossible', false]]);
  });

  await cas('affaire transmise : sujet et message signés par l’agent (author_real)', async () => {
    const src = lire('plateau-justice-economie.js');
    assert.match(src, /sbCreateTopic\(forumKey, '⚖️ \[AFFAIRE\] ' \+ cible, auteur, state\.country, heure, true, false, agent,/);
    assert.match(src, /sbCreatePost\(topicId, auteur, textePost, heure, true, false, \[\], null, agent,/);
    assert.match(src, /const agent = state\.char\?\.name \|\| null;/);
  });

  await cas('retrait d’un projet : message du Secrétariat porté par son auteur', async () => {
    const src = lire('plateau-assemblee.js');
    assert.match(src, /'— — — PROJET RETIRÉ PAR SON AUTEUR — — —', time, true, false, \[\], null,\s*state\.char\?\.name \|\| null,/);
  });

  await cas('aucune autre publication forum signée d’un nom littéral sans author_real', async () => {
    const fautifs = [];
    for (const f of fs.readdirSync(racine).filter(f => /^plateau-.*\.js$/.test(f))) {
      for (const m of lire(f).matchAll(/sbCreate(Topic|Post)\(([^;]*?)\)\s*(?:\.|;)/gs)) {
        const args = m[2];
        // Un nom littéral en position d'auteur (2e argument du message, 3e du sujet)…
        const litteral = m[1] === 'Post' ? /^[^,]+,\s*'[^']+'/.test(args) : /^[^,]+,[^,]+,\s*'[^']+'/.test(args);
        if (litteral && !/,\s*true\s*,\s*(true|false)\s*,/.test(args)) fautifs.push(f + ' : ' + args.slice(0, 80));
      }
    }
    assert.deepEqual(fautifs, []);
  });

  console.log(echecs ? echecs + ' échec(s)' : 'Tous les cas passent.');
  process.exit(echecs ? 1 : 0);
})();
