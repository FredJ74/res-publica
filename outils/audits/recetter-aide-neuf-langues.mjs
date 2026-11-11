// Recette de consultation seulement, à utiliser par l'intégrateur avec un compte
// isolé déjà autorisé. Aucun mot de passe, clé IA ou RPC métier. Réponses privées hors Git.
import {readFile,open} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
const URL_AIDE='https://res-publica.vercel.app/api/aide';
const PATH_RESULTAT='/tmp/hg-aide-recette-reelle.json';
export function verifierIdentite(jeton,uid){
 if(!jeton||!uid)throw Error('acces_isole_manquant');
 let sub;try{sub=JSON.parse(Buffer.from(jeton.split('.')[1],'base64url')).sub}catch{throw Error('jeton_invalide')}
 if(sub!==uid)throw Error('identite_inattendue');
 // Ce décodage n'authentifie pas le jeton : seul joueurAuthentifie côté serveur le fait.
}
export function planRecette(principales,corpus){
 return Object.keys(principales).map(lang=>({lang,questions:[principales[lang].pa,principales[lang].but,corpus[lang].commerce,corpus[lang].suivi]}));
}
export async function recetter({jeton,uid,plan,fetchImpl=globalThis.fetch}){
 verifierIdentite(jeton,uid);
 if(plan.length!==9||plan.some(x=>x.questions.length!==4))throw Error('plan_incomplet');
 const resultat={endpoint:URL_AIDE,validation_linguistique:false,cas:[]};
 for(const serie of plan){const historique=[];
  for(const message of serie.questions){
   let r,body;
   try{r=await fetchImpl(URL_AIDE,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json',Authorization:'Bearer '+jeton},body:JSON.stringify({lang:serie.lang,message,historique:historique.slice(-6).map(m=>({...m,content:m.content.slice(0,1500)}))}),signal:AbortSignal.timeout(29000)});if(r.ok)body=await r.json()}
   catch{resultat.cas.push({lang:serie.lang,message,statut:'transport_indetermine'});return resultat}
   const ok=r.ok&&typeof body?.reponse==='string'&&!!body.reponse.trim();
   resultat.cas.push({lang:serie.lang,message,http:r.status,statut:ok?'reponse_recue':'refus_ou_reponse_invalide',...(ok?{reponse:body.reponse.slice(0,6000)}:{})});
   if(!ok)return resultat; // pas de répétition automatique ni de consommation supplémentaire
   historique.push({role:'user',content:message},{role:'assistant',content:body.reponse});
  }
 }
 return resultat;
}
async function main(){
 const jeton=process.env.HG_AIDE_LIVE_TOKEN,uid=process.env.HG_AIDE_COMPTE_TEST_UID;
 if(!jeton||!uid){process.stdout.write(JSON.stringify({etat:'non_execute',raison:'acces_compte_isole_absent',appels:0})+'\n');process.exitCode=2;return}
 let resultat,archive;
 try{
  verifierIdentite(jeton,uid);
  archive=await open(PATH_RESULTAT,'wx',0o600);
  const base=new URL('../bancs/fixtures/',import.meta.url);
  const q=JSON.parse(await readFile(new URL('aide-questions-neuf-langues.json',base),'utf8'));
  const c=JSON.parse(await readFile(new URL('aide-corpus-neuf-langues.json',base),'utf8'));
  resultat=await recetter({jeton,uid,plan:planRecette(q,c)});
  await archive.writeFile(JSON.stringify(resultat,null,2)+'\n');
 }catch{process.stdout.write(JSON.stringify({etat:'non_certifie',raison:'identite_transport_ou_archive_indisponible'})+'\n');process.exitCode=1;return}finally{if(archive)await archive.close()}
 process.stdout.write(JSON.stringify({etat:'a_relire',appels:resultat.cas.length,recus:resultat.cas.filter(x=>x.statut==='reponse_recue').length,validation_linguistique:false,archive_privee:PATH_RESULTAT})+'\n');
 if(resultat.cas.length!==36||resultat.cas.some(x=>x.statut!=='reponse_recue'))process.exitCode=1;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)await main();
