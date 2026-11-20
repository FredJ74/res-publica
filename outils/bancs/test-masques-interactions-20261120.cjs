'use strict';
// Banc de discrétion : interagir avec un personnage masqué sans jamais révéler son vrai nom (Fred, 20/11/2026).
// Essai annulé en base le 20/11 (Arnie masqué, Tom Tom présent) : demande au vrai nom → pas_co_presents ; rejoindre
// par le jeton → groupe vu par Tom Tom : chef et membre « Individu masqué n°1 » ; le masqué ne peut pas signer de son
// vrai nom (refus RLS) ; il lit les deux messages ; aucune ligne de la conversation ne contient « Arnie » ;
// le masqué se voit sous son nom dans son propre groupe.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const racine = path.join(__dirname, '../..');
const lire = (f) => fs.readFileSync(path.join(racine, f), 'utf8');
const multi = lire('plateau-multijoueur.js');
function extraire(src, nom) {
  const debut = src.search(new RegExp('(async )?function ' + nom + '\\('));
  assert.ok(debut >= 0, nom);
  let i = src.indexOf('{', debut), n = 0;
  for (; i < src.length; i++) { if (src[i] === '{') n++; else if (src[i] === '}' && --n === 0) break; }
  return src.slice(debut, i + 1);
}

test('Serveur : identifiant anonyme, signature imposée, rejoindre par jeton, noms masqués', () => {
  const sql = lire('migrations/20261120260000_masques_interactions.sql');
  assert.match(sql, /SELECT 'masque:' \|\| j\.jeton::text FROM public\.crim_jetons_masque j WHERE j\.personnage = p_nom;/);
  assert.match(sql, /WITH CHECK \(auteur = public\.chat_auteur_attendu_interne\(conversation_id, salon\) AND public\.chat_participe\(conversation_id, salon\)\)/);
  assert.match(sql, /AND NOT \(public\.crim_mode_action_interne\(p_chef\) = 'masque'\s+AND coalesce\(current_setting\('rp\.groupe_par_jeton', true\), ''\) = 'on'\)/);
  assert.match(sql, /IF v_chef IS NULL THEN RETURN jsonb_build_object\('ok', false, 'raison', 'pas_co_presents'\);/);
  assert.match(sql, /'chef',public\.crim_nom_pour_interne\(chef_courant,moi\),'membres'/);
  assert.match(sql, /jsonb_build_object\('membre',public\.crim_nom_pour_interne\(nom,moi\)\)/);
  assert.match(sql, /jsonb_agg\(jsonb_build_object\('name',public\.crim_nom_pour_interne\(name,moi\),/);
});

test('Fiche : Parler et Rejoindre par le jeton, jamais de courrier pour un masqué', () => {
  const pnj = lire('plateau-pnj.js');
  const bloc = pnj.slice(pnj.indexOf("if (isPJ && pnj.masque === true && pnj.jeton) {"), pnj.indexOf("if (isPJ && pnj.masque !== true) {"));
  assert.match(bloc, /ouvrirConversationAvec\(\\'' \+ libelleSur \+ '\\',\\'' \+ jetonSur \+ '\\'\)/);
  assert.match(bloc, /rejoindreMasque\(\\'' \+ jetonSur \+ '\\'\)/);
  assert.doesNotMatch(bloc, /composerMailPour/);
  assert.doesNotMatch(bloc, /rejoindrePJ/);
  assert.match(multi, /sbRpc\('groupe_pj_rejoindre_masque', \{p_jeton: String\(jeton\)\}, options\)/);
});

test('Chat : la conversation et l\'auteur sont l\'identifiant anonyme, jamais le vrai nom', async () => {
  const ctx = { state: { char: { name: 'Arnie' } }, window: { _vraisJoueursPresents: [{ name: 'Individu masqué n°2', masque: true, jeton: 'abc' }] },
    getConversationId: (a, b) => [a, b].sort().join('__'), afficherVueConversation() {}, document: { getElementById: () => null },
    sbRpc: async () => ({ ok: true, masque: true, alias: 'masque:moi' }) };
  ctx.String = String;
  vm.runInNewContext('let _chatAliasMoi = null, _chatMasqueMoi = false, _conversationActuelle = null;'
    + ['chatRafraichirAlias', 'chatMoiPour', 'chatLibelleParticipant', 'ouvrirConversationAvec'].map(n => extraire(multi, n)).join('\n')
    + ';this.ouvrir=ouvrirConversationAvec;this.moiPour=chatMoiPour;this.lib=chatLibelleParticipant;this.conv=()=>_conversationActuelle;', ctx);
  await ctx.ouvrir('Individu masqué n°2', 'abc');
  const c = ctx.conv();
  assert.equal(c.id, 'masque:abc__masque:moi');           // masqué des deux côtés : aucun vrai nom
  assert.doesNotMatch(c.id, /Arnie/);
  assert.equal(ctx.moiPour(c.id), 'masque:moi');
  assert.equal(c.label, 'Individu masqué n°2');
  assert.equal(ctx.lib('masque:abc'), 'Individu masqué n°2');
  assert.equal(ctx.lib('masque:inconnu'), 'Individu masqué');
  assert.equal(ctx.moiPour('Arnie__Bob'), 'Arnie');
  assert.match(multi, /chatLibelleParticipant\(m\.auteur\)/);
  assert.match(multi, /: chatMoiPour\(_conversationActuelle\.id\), texte,/);
  assert.match(lire('supabase.js'), /\(alias && cid\.split\('__'\)\.includes\(alias\)\)/);
});

test('Docs : règle notée dans GAME-DESIGN-CRIMINALITE.md', () => {
  const gd = lire('GAME-DESIGN-CRIMINALITE.md');
  assert.match(gd, /Interagir avec un masqué, sous son anonymat/);
  assert.match(gd, /répond toujours comme s'il était absent/);
});
