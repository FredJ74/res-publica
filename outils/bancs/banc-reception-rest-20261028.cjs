// Banc isolé : charge la fonction réelle de transport REST dans une VM sans accès réseau.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../supabase.js'), 'utf8');
const start = source.indexOf('async function sbTransportRest(');
const end = source.indexOf('// VERDICT STRUCTURE POUR REST.', start);
assert.ok(start >= 0 && end > start, 'la fonction REST doit être présente');
const code = source.slice(start, end);
async function cas(label, response, expected, method = 'GET') {
  let calls = 0;
  const sandbox = {
    SUPABASE_URL: 'https://example.invalid',
    sbEnTetes: () => ({}),
    rpAuthJeton: () => 'token-test',
    rpAuthAssurerSession: async () => true,
    sbInvaliderLecturesRecentes: () => {},
    fetch: async () => { calls++; if (response instanceof Error) throw response; return response; },
    console: { error: () => {} }
  };
  vm.createContext(sandbox);
  vm.runInContext(code + '\nthis._run = sbTransportRest;', sandbox);
  const res = await sandbox._run(method, 'test', '', method === 'GET' ? undefined : { a: 1 });
  assert.equal(res.etat, expected, label);
  assert.equal(calls, 1, label + ': pas de relance aveugle');
  return res;
}
(async () => {
  await cas('JSON correct', { ok:true,status:200,json:async()=>({ok:true}) }, 'ok');
  const invalid = await cas('HTTP 200 JSON corrompu',
    {ok:true,status:200,json:async()=>{ throw new SyntaxError('JSON'); }}, 'reponse_invalide','PATCH');
  assert.equal(invalid.envoyee,true);
  assert.equal(invalid.donnees,null);
  const empty = await cas('HTTP 204 vide', {ok:true,status:204}, 'ok','PATCH');
  assert.equal(empty.donnees,true);
  await cas('HTTP 403', {ok:false,status:403,text:async()=>''}, 'http');
  await cas('Réseau indisponible', new Error('offline'), 'reseau');
  console.log('OK : 5 scénarios de transport REST, aucune relance de mutation');
})().catch(err=>{console.error(err);process.exitCode=1;});
