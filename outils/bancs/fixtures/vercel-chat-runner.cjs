// Execute exclusivement les fichiers produits par @vercel/node dans un autre processus.
const assert = require('node:assert/strict');
// Toute tentative de reseau non explicitement simulee echoue.
globalThis.fetch = async () => {throw Error('Reseau reel interdit dans le banc');};
const charge = require(process.argv[2]);
const handler = charge.default || charge;
assert.equal(typeof handler, 'function');
if (process.argv[3] !== 'dialogues') process.exit(0);
process.env.DEEPSEEK_API_KEY = 'cle-de-fixture-non-secrete';
const reponse = v => new Response(JSON.stringify(v));
const res = () => ({setHeader() {}, status(n) {this.code = n; return this;},
  json(v) {this.body = v; return this;}, end() {return this;}});
(async () => {
  const method = res(); await handler({method: 'GET', headers: {}}, method);
  assert.equal(method.code, 405);
  const anonym = res();
  await handler({method: 'POST', headers: {}, body: {profil: 'sabri_coledur', message: 'Bonjour'}}, anonym);
  assert.equal(anonym.code, 401);
  const comptes = [];
  for (const profil of ['sabri_coledur', 'ced_labone', 'henrico_stot', 'gerard_poincon',
    'le_maire_de_luthecia', 'le_maire_adjoint_de_luthecia']) {
    const municipal = profil.startsWith('le_maire');
    for (const etat of municipal ? ['pnj', 'pj', 'vacant'] : ['pnj']) {
      let prompt, demandesIA = 0;
      globalThis.fetch = async (url, init = {}) => {
        const u = new URL(url);
        if (u.pathname === '/auth/v1/user') return reponse({id: 'uid-fixture'});
        if (u.hostname === 'api.deepseek.com') {
          demandesIA++; prompt = JSON.parse(init.body).messages[0].content;
          assert.ok(JSON.parse(init.body).messages.some(m => m.content === 'Souvenir de fixture'));
          return reponse({choices: [{message: {content: 'Conversation IA simulee'}, finish_reason: 'stop'}]});
        }
        assert.equal(u.hostname, 'jxpwoosmmhohoihxpbuc.supabase.co');
        assert.equal(init.headers.Authorization, 'Bearer jwt-fixture');
        if (u.pathname.includes('/rpc/')) return reponse({ok: false});
        assert.equal(init.method, 'GET');
        if (u.pathname.endsWith('/cycles_electoraux')) return reponse(etat === 'vacant' ? []
          : [{data: {eluId: etat === 'pj' ? 'Alice-fixture' : 'Le Maire de Luthecia'}}]);
        if (u.pathname.endsWith('/postes_attribues')) return reponse(etat === 'pj'
          ? [{titulaire: 'Alice-fixture', depuis: '2026-10-01T00:00:00Z'}] : []);
        if (u.pathname.endsWith('/personnages')) return reponse(etat === 'pj' ? [{name: 'Alice-fixture'}] : []);
        if (u.pathname.endsWith('/titulaires_pnj')) return reponse(etat === 'pnj' ? [{nom_pnj: 'Le Maire Adjoint de Luthecia'}] : []);
        assert.fail('Lecture non attendue');
      };
      const r = res();
      await handler({method: 'POST', headers: {authorization: 'Bearer jwt-fixture'},
        body: {profil, lang: 'fr', message: 'Bonjour', historique: [{role: 'assistant', content: 'Souvenir de fixture'}]}}, r);
      assert.equal(r.code, 200, `${profil}/${etat}`); assert.equal(demandesIA, 1);
      assert.equal(r.body.reponse, 'Conversation IA simulee');
      if (municipal) {
        assert.ok(prompt.includes('FONCTION MUNICIPALE ACTUELLE'));
        if (etat === 'pj') {
          assert.ok(prompt.includes(profil === 'le_maire_de_luthecia' ? 'Secrétaire général de la mairie' : 'Secrétaire du maire adjoint'));
          assert.ok(prompt.includes('Tu n’exerces aucun pouvoir du poste'));
        } else assert.ok(prompt.includes(profil === 'le_maire_de_luthecia' ? 'Maire de Luthécia' : 'Maire adjoint de Luthécia'));
      }
      comptes.push(`${profil}/${etat}`);
    }
  }
  console.log(JSON.stringify({dialogues: comptes, methode: 405, anonyme: 401}));
})().catch(e => {console.error(e); process.exitCode = 1;});
