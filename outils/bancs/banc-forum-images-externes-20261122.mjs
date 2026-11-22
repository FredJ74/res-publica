// Forum, images extérieures (Fred, 22/11/2026, point 7) : recopie dans le stockage et remplacement des liens seulement.
// Réseau simulé (aucun appel réel) ; message témoin construit comme celui de Peter Kropotkine (lien gstatic avec « & »).
import test from 'node:test';
import assert from 'node:assert/strict';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'cle-de-test';
const M = await import('../../api/_forum-images-externes.js');
const S = 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const EXT = 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ABC&s=10';
const POSTS = [
  { id: 'post-k', content: '<p>Texte de Kropotkine, à ne pas toucher.</p><img src="' + EXT.replace('&', '&amp;') + '">', content_blocks: [{ type: 'image', url: EXT }], content_layout: { elements: [{ type: 'image', src: EXT }] } },
  { id: 'post-deja', content: '<img src="' + S + '/storage/v1/object/public/forum-images/u/x.png">', content_blocks: null, content_layout: null },
  { id: 'post-texte', content: '<p>Un lien <a href="https://exemple.org">vers ailleurs</a>.</p>', content_blocks: null, content_layout: null },
  { id: 'post-pdf', content: '<img src="https://exemple.org/doc.pdf">', content_blocks: null, content_layout: null }
];
function reseau() {
  const appels = [];
  const f = async (url, init = {}) => {
    appels.push({ url, methode: init.method || 'GET', corps: init.body });
    const rep = (ok, statut, type, corps) => ({ ok, status: statut, headers: { get: () => type }, json: async () => corps, arrayBuffer: async () => new Uint8Array([1, 2, 3]).buffer });
    if (url.includes('/rest/v1/forum_posts?select')) return rep(true, 200, 'application/json', JSON.parse(JSON.stringify(POSTS)));
    if (url === EXT) return rep(true, 200, 'image/jpeg');
    if (url === 'https://exemple.org/doc.pdf') return rep(true, 200, 'application/pdf');
    if (url.includes('/storage/v1/object/forum-images/')) return rep(true, 200, 'application/json', {});
    if (url.includes('/rest/v1/forum_posts?id=eq.')) return rep(true, 204, '');
    return rep(false, 404, '');
  };
  return { f, appels };
}

test('repère les images extérieures du texte, des blocs et de la mise en page ; ignore le stockage et les simples liens', () => {
  assert.deepEqual(M.imagesExterieures(POSTS[0]), [EXT]);
  assert.deepEqual(M.imagesExterieures(POSTS[1]), []);
  assert.deepEqual(M.imagesExterieures(POSTS[2]), []);
});

test('recopie une fois, remplace seulement le lien (texte intact), refuse ce qui n’est pas une image', async () => {
  const { f, appels } = reseau();
  const r = await M.recopierImagesForumExterieures({ fetchImpl: f });
  assert.equal(r.ok, true); assert.equal(r.images, 1); assert.equal(r.messages, 1);
  assert.deepEqual(r.echecs.map(e => e.raison), ['pas_une_image']);
  const envoi = appels.filter(a => a.url.includes('/storage/v1/object/forum-images/externes/'));
  assert.equal(envoi.length, 1);
  const patch = appels.find(a => a.methode === 'PATCH');
  assert.match(patch.url, /id=eq\.post-k$/);
  const maj = JSON.parse(patch.corps);
  assert.match(maj.content, /^<p>Texte de Kropotkine, à ne pas toucher\.<\/p><img src="https:\/\/jxpwoosmmhohoihxpbuc\.supabase\.co\/storage\/v1\/object\/public\/forum-images\/externes\/[0-9a-f]{40}\.jpg">$/);
  assert.match(maj.content_blocks[0].url, /forum-images\/externes\//);
  assert.match(maj.content_layout.elements[0].src, /forum-images\/externes\//);
  assert.equal(appels.filter(a => a.methode === 'PATCH').length, 1, 'les autres messages ne sont pas réécrits');
});

test('sans clé de service : rien n’est tenté', async () => {
  delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  // Le module a lu la clé au chargement ; on vérifie seulement que la garde existe dans le code.
  const src = (await import('node:fs')).readFileSync(new URL('../../api/_forum-images-externes.js', import.meta.url), 'utf8');
  assert.match(src, /if \(!SUPABASE_SERVICE_ROLE\) return \{ ok: false, raison: 'cle_service_absente' \}/);
  assert.match(src, /budgetMs = 20000/);
});

test('éditeur : messages clairs pour un fichier refusé (format, poids) ; 5 Mo acceptés', async () => {
  const fs = await import('node:fs'), vm = await import('node:vm');
  // Seules les fonctions utiles sont chargées (le fichier entier attend un vrai navigateur).
  const src = fs.readFileSync(new URL('../../forum-canvas.js', import.meta.url), 'utf8');
  const bloc = (debut, fin) => src.slice(src.indexOf(debut), src.indexOf(fin, src.indexOf(debut)));
  const code = bloc('const RP_FORUM_IMAGES', 'function rpForumToast') + bloc('function rpForumUid', 'async function rpForumEnvoyerImage');
  const ctx = { atob: s => Buffer.from(s, 'base64').toString('binary') };
  vm.createContext(ctx); vm.runInContext(code, ctx);
  const refus = f => vm.runInContext('rpForumRefusImage', ctx)(f);
  assert.match(refus({ type: 'application/pdf', size: 10 }), /n’est pas une image acceptée.*PNG, JPEG, WebP ou GIF/);
  assert.match(refus({ type: 'image/png', size: 6 * 1048576 }), /Image trop lourde : 6,0 Mo\. Le maximum est de 5 Mo/);
  assert.equal(refus({ type: 'image/jpeg', size: 5 * 1048576 }), null);
  const jeton = 'x.' + Buffer.from(JSON.stringify({ sub: 'uid-123' })).toString('base64url') + '.y';
  assert.equal(vm.runInContext('rpForumUid', ctx)(jeton), 'uid-123', 'dossier à l’identifiant du joueur');
});
