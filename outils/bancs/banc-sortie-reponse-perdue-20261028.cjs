// Contrat de sortie serveur : ne pas rejouer une mutation après réponse perdue.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync(require('node:path').join(__dirname,'../../plateau-navigation.js'),'utf8');
const a=source.indexOf('async function confirmerSortieBatimentServeur(');
const b=source.indexOf('\nasync function sortirBatiment()',a);
assert(a>=0&&b>a,'contrat navigation introuvable');
async function cas(label, replies, expected, count) {
  const calls=[];
  const contexte={pays:'republic',ville:'capitale',batiment:'immeuble-test',piece:'accueil'};
  const sandbox={
    state:{estEmprisonne:false},
    contexteNavigationRueValide:()=>true,
    interceptionJudiciaireBloqueDeplacement:()=>false,
    RUE_CENTRALE_NOEUDS:{republic:{'sortie-test':{}}},
    sbRpcVerdict:async(name,args)=>{calls.push(name);const next=replies.shift();assert(next, 'réponse RPC simulée manquante');return next;},
  };
  vm.createContext(sandbox);
  vm.runInContext(source.slice(a,b)+'\nthis.confirmer=confirmerSortieBatimentServeur;',sandbox);
  const out=await sandbox.confirmer(contexte);
  assert.equal(out.ok,expected,label);
  assert.deepEqual(calls,count,label);
  return out;
}
(async()=>{
  const sortie={ok:true,noeud:'sortie-test'};
  const position={ok:true,country:'republic',city:'capitale',building:null,street:'sortie-test'};
  await cas('confirmation directe',[sortie,{ok:true}],true,['rue_sortie_batiment_lire','rue_position_enregistrer']);
  await cas('réponse perdue relue',[sortie,{ok:false,transport:{etat:'reseau'}},position],true,['rue_sortie_batiment_lire','rue_position_enregistrer','rue_position_lire']);
  await cas('déjà sorti, sans nouvelle mutation',[{ok:false,raison:'pas_dans_un_batiment'},position],true,['rue_sortie_batiment_lire','rue_position_lire']);
  await cas('sortie inconnue sans mouvement',[{ok:false,raison:'sortie_non_referencee'}],false,['rue_sortie_batiment_lire']);
  const incertain=await cas('réponse perdue et lecture impossible',[sortie,{ok:false,transport:{etat:'reseau'}},{ok:false,transport:{etat:'reseau'}}],false,['rue_sortie_batiment_lire','rue_position_enregistrer','rue_position_lire']);
  assert.equal(incertain.incertaine,true);
  console.log('OK : 5 contrats de sortie serveur, aucune relance de mouvement');
})().catch(e=>{console.error(e);process.exitCode=1;});
