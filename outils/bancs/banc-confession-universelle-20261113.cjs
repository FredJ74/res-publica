const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');

const data=fs.readFileSync('data.js','utf8');
const divers=fs.readFileSync('plateau-divers.js','utf8');
const pnj=fs.readFileSync('plateau-pnj.js','utf8');
const politique=fs.readFileSync('plateau-politique.js','utf8');
const i18n=fs.readFileSync('i18n/sovarka-infobulles-resources.js','utf8');
const sql=fs.readFileSync('migrations/20261113214000_confession_universelle.sql','utf8');
const desc='2 PA. Si le jet réussit (DUP, piété et sécurité de la ville), une trace d’acte illégal est effacée au hasard. Aucun choix de l’acte.';

test('les JS du lot restent syntaxiquement valides',()=>{
 for(const [file,content] of [['data.js',data],['plateau-divers.js',divers],['plateau-pnj.js',pnj],['plateau-politique.js',politique],['catalogue',i18n]])new vm.Script(content,{filename:file});
});
test('description uniforme dans trois temples, ni automatique ni morale',()=>{
 assert.equal(data.split(desc).length-1,3);
 assert.equal((data.match(/fn:'se_confesser'[^\n]*successRate:null/g)||[]).length,3);
 assert.ok(!divers.includes('const secrets = ['));
 assert.ok(!divers.includes("sbDelete('actions_tracables'"));
 assert.match(divers,/return doSeConfeser\(2, 0\)/);
 assert.match(pnj,/EGLISES_CONFESSION_PAR_PAYS/);
 for(const v of ['tabernacle-impots','notre-dame-mer','eglise-montrouge','laboratoire-priere','kolkhoze-spirituel','patisserie-sacree'])assert.ok(pnj.includes(v));
});
test('l affichage ne revendique aucun taux fixe pour confession',()=>{
 assert.match(politique,/o.fn === 'se_confesser' \? null/);
 assert.match(i18n,/if\(p.s!==null&&p.s!==undefined\)/);
 assert.ok(i18n.includes(desc));
});
test('une seule RPC autorisée : sélection aléatoire, débit sécurisé, aucune trace vide payée',()=>{
 assert.match(sql,/CREATE OR REPLACE FUNCTION public.confession_tenter\(\)/);
 assert.match(sql,/FROM public.actions_tracables/);
 assert.match(sql,/FROM jsonb_array_elements/);
 assert.match(sql,/ORDER BY random\(\) LIMIT 1/);
 assert.ok(sql.indexOf("raison','aucune_trace_eligible")<sql.indexOf("payer_ordre_interne(v_acteur,'se_confesser',2,0)"));
 assert.match(sql,/FOR UPDATE/);
 assert.match(sql,/v_jet<=v_taux/);
 assert.match(sql,/DELETE FROM public.actions_tracables/);
 assert.match(sql,/SET historique_crimes=/);
 assert.match(sql,/v_trace.ord/);
 assert.match(sql,/GRANT EXECUTE ON FUNCTION public.confession_tenter\(\) TO authenticated/);
 assert.match(sql,/REVOKE ALL ON FUNCTION public.confession_tenter\(\) FROM PUBLIC,anon/);
 assert.ok(!/p_trace|p_acte|p_id/.test(sql.slice(sql.indexOf('confession_tenter()'),sql.indexOf('RETURNS jsonb'))));
});
test('la formule DUP, piété et sécurité est bornée et réactive',()=>{
 const chance=(dup,ip,isn)=>Math.max(10,Math.min(90,Math.round(50+4*(dup-8)+.4*(ip-isn))));
 assert.equal(chance(8,50,50),50);
 assert.equal(chance(8,30,70),34);
 assert.equal(chance(8,70,30),66);
 assert.equal(chance(8,90,20),78);
 assert.equal(chance(20,100,0),90);
 assert.equal(chance(1,0,100),10);
 assert.match(sql,/round\(50\+4\*\(v_dub-8\)\+0\.4\*\(v_ip-v_isn\)\)/);
});
test('deux échecs ne deviennent pas un succès fictif dans le client',async()=>{
 const a=divers.indexOf('let confessionEnCours = false;');
 const b=divers.indexOf('// Correctif (lot "refonte religion Republia"',a);
 assert.ok(a>=0&&b>a);
 const source=divers.slice(a,b);
 let rpc=0;const toasts=[], journals=[], payments=[];
 const ctx={sbRpc:async()=>{rpc++;return {ok:true,reussi:false,taux:42,jet:51,pa:8};},
  showToast:(...args)=>toasts.push(args), addJournalEntry:(...args)=>journals.push(args),
  appliquerPaiementServeur:v=>payments.push(v),updateUI(){}};
 vm.createContext(ctx);vm.runInContext(source,ctx);
 await vm.runInContext('doSeConfeser(2,0)',ctx);
 assert.equal(rpc,1);assert.equal(payments.length,1);
 assert.match(toasts[0][0],/refusée/);
 assert.match(journals[0][0],/sans absolution/);
});
