// Banc de création : une réponse perdue n'autorise jamais le rejeu de l'INSERT.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync(require('node:path').join(__dirname,'../../supabase.js'),'utf8');
const a=source.indexOf('async function sbCreerPersonnageUnique(');
const b=source.indexOf('// Le nom est-il deja porte ?',a);
assert(a>=0&&b>a,'fonction de création introuvable');
async function cas(label,response,expected){
  let calls=0;
  const sandbox={
    SUPABASE_URL:'https://example.invalid',
    sbEnTetes:()=>({}),
    fetch:async()=>{calls++;if(response instanceof Error)throw response;return response;},
    console:{error:()=>{}}
  };
  vm.createContext(sandbox);
  vm.runInContext(source.slice(a,b)+'\nthis.creer=sbCreerPersonnageUnique;',sandbox);
  const result=await sandbox.creer({name:'PJ-test'});
  assert.equal(result.ok,expected.ok,label);
  if(expected.raison)assert.equal(result.raison,expected.raison,label);
  assert.equal(calls,1,label+': aucune relance aveugle');
}
(async()=>{
  await cas('201 retour minimal',{ok:true,status:201,json:async()=>{throw new SyntaxError('vide');}},{ok:true});
  await cas('réseau perdu',new Error('offline'),{ok:false,raison:'creation_incertaine'});
  await cas('conflit de nom',{ok:false,status:409,text:async()=>JSON.stringify({code:'23505',message:'personnages_name_key'})},{ok:false,raison:'nom_deja_pris'});
  await cas('conflit du compte',{ok:false,status:409,text:async()=>JSON.stringify({code:'23505',message:'personnages_user_id_unique'})},{ok:false,raison:'compte_a_deja_un_personnage'});
  console.log('OK : 4 scénarios création personnage, une seule tentative réseau');
})().catch(e=>{console.error(e);process.exitCode=1;});
