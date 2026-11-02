'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const source=fs.readFileSync(path.resolve(__dirname,'../../.github/workflows/coherence-client.yml'),'utf8');
function verifier(s){
 const tests=s.indexOf('run: node --test outils/bancs/test-*.mjs');assert.ok(tests>=0,'tests transversaux conservés');
 for(const dep of ['outils/vercel','outils/e2e']){
  const index=s.indexOf('run: npm ci --prefix '+dep);assert.ok(index>=0&&index<tests,dep+' doit être installé avant les tests transversaux');
 }
 assert.match(s,/if: github.event_name == 'push'\s+run: node --test outils\/bancs\/test-\*\.mjs/,'contrôle main conservé');
}
test('les dépendances des contrôles main sont installées avant leur exécution',()=>verifier(source));
test('contre-épreuve : remettre le calendrier avant npm ci est refusé',()=>{
 const bloc=source.match(/      - name: Calendrier sur main[^\n]*\n        if:[^\n]*\n        run:[^\n]*\n/);assert.ok(bloc);
 const ancien=source.replace(bloc[0],'').replace('      - name: Constructeur Vercel',bloc[0]+'      - name: Constructeur Vercel');
 assert.throws(()=>verifier(ancien),/doit être installé/);
});
