// SOURCES: aucune -- vrais adaptateurs de production ; atomicite/archives eprouvees en PostgreSQL.
var src=readFile(typeof CHEMIN_SOURCE==='string'&&(typeof CHEMIN_FICHIER!=='string'||CHEMIN_FICHIER==='plateau-pnj.js')?CHEMIN_SOURCE:'/Users/fredericjasseron/ResPublica/plateau-pnj.js');
var pont=readFile(typeof CHEMIN_FICHIER==='string'&&CHEMIN_FICHIER==='plateau-terrain-banque.js'?CHEMIN_SOURCE:'/Users/fredericjasseron/ResPublica/plateau-terrain-banque.js');
function bloc(nom){var i=src.indexOf('async function '+nom+'('),j=src.indexOf('{',i),p=0,k=j;for(;k<src.length;k++){if(src[k]==='{')p++;if(src[k]==='}'&&!--p)break;}return src.slice(i,k+1);}
var state,VERDICT,GELE,RPC,TOASTS,JOURNAL,CACHE,ANCIENNES,stock=new Map();
var sessionStorage={getItem:k=>stock.get(k)||null,setItem:(k,v)=>stock.set(k,v),removeItem:k=>stock.delete(k)},crypto={randomUUID:()=> 'fixture-uuid'};
function contexteNavigationRue(){return {uid:'fixture',nom:state.char.name,char:state.char};}function contexteNavigationRueValide(c){return c.char===state.char;}
function refuserSiGele(){return Promise.resolve(GELE);}function updateUI(){}function constructionFenetre(){}function constructionBouton(){}
function getTerrainState(){return CACHE[CACHE.length-1]||{};}
function showToast(t,m,ok){TOASTS.push({titre:t,message:m,ok:!!ok});}function addJournalEntry(m,c){JOURNAL.push({texte:m,classe:c});}
function sbRpcVerdict(nom,args){RPC.push({nom:nom,args:args});return VERDICT==='rejet'?Promise.reject(Error('transport')):Promise.resolve(Array.isArray(VERDICT)?VERDICT[0]:VERDICT);}
function sbGetTerrainState(){var v=Array.isArray(VERDICT)?VERDICT[0]:VERDICT;return Promise.resolve(v&&v.ok?v.etat:null);}
function rafraichirRuntimeHelvetia(){return Promise.resolve({pa:7});}function remplacerTerrainState(id,e){CACHE.push(e);}
var document={getElementById:()=>({classList:{remove(){}}})};
function sbSetTerrainState(){ANCIENNES.push('ancien_blob');}function sbEnregistrerVenteTerrain(){ANCIENNES.push('ancienne_archive');}
eval(pont);eval(bloc('finaliserAchatTerrain'));
function neuf(v,gele){stock.clear();state={char:{name:'Ben'},country:'republic',currentCity:'capitale',arg:5000};VERDICT=v===undefined?{ok:true,etat:{proprietaire:'Ben',surface:800,valeur_totale:9000,city:'ville_a',permis:{statut:'valide'},zzTemoinServeur:4242}}:v;GELE=!!gele;RPC=[];TOASTS=[];JOURNAL=[];CACHE=[];ANCIENNES=[];}
function sync(p){var fini=false,v;Promise.resolve(p).then(x=>{v=x;fini=true;},e=>{v=e;fini=true;});for(var i=0;i<500&&!fini;i++)drainMicrotasks();if(!fini)throw Error('promesse non resolue');return v;}
var ko=0,n=0;function att(t,v){n++;if(v)print('  ok '+t);else{ko++;print('  *** '+t);}}
neuf();att('mutation via une commande complete',sync(finaliserAchatTerrain('zz-parcelle',1,2,true,'compromis',{}))===true);
att('une seule porte',RPC.length===1&&RPC[0].nom==='terrain_acquisition_commande');att('titre compromis',RPC[0].args.p_action==='acte_compromis');att('identifiant du terrain',RPC[0].args.p_terrain==='zz-parcelle');
att('UUID present',typeof RPC[0].args.p_requete==='string'&&RPC[0].args.p_requete.length>0);att('aucune ancienne primitive',ANCIENNES.length===0);
att('prix non dicte par le client',!('prix' in RPC[0].args)&&!('prix' in RPC[0].args.p_parametres));att('surface non dictee',!('surface' in RPC[0].args));att('ville non dictee',!('city' in RPC[0].args));att('purge serveur non fournie par le client',!('p_patch' in RPC[0].args));att('purge etat exclusivement serveur dans les parametres',Object.keys(RPC[0].args.p_parametres).length===0);att('aucun blob de cache',!('_fusionne' in RPC[0].args));
att('cache actuel du serveur',CACHE.length===1&&CACHE[0].zzTemoinServeur===4242&&CACHE[0].permis.statut==='valide');att('achat annonce apres relecture',TOASTS.some(t=>t.ok));
neuf();att('achat direct meme adaptateur',sync(finaliserAchatTerrain('zz-parcelle',7000,600,false,'achat_direct',{}))===true);att('titre achat direct',RPC[0].args.p_action==='acte_direct');att('purge toujours serveur',!('p_patch' in RPC[0].args));att('autorisation de permis non dictee',!('constructionAutorisee' in RPC[0].args));att('aucune ancienne primitive',ANCIENNES.length===0);
for(var c of [null,[],'rejet',{ok:false,raison:'pas_mon_compromis'},{ok:false,raison:'terrain_gele'}]){
 neuf(c);att('refus sans fausse propriete',sync(finaliserAchatTerrain('zz-parcelle',9000,800,true,'compromis',{}))===false);att('aucun achat annonce',!TOASTS.some(t=>t.ok));att('motif nomme au joueur',TOASTS.length===1&&!TOASTS[0].ok);att('aucun cache de titre adopte',CACHE.length===0);att('aucun paiement ou archive locale',state.arg===5000&&ANCIENNES.length===0);
}
neuf(undefined,true);att('gel avant la commande',sync(finaliserAchatTerrain('zz-parcelle',0,0,false,'compromis',{}))===false&&RPC.length===0);
att('aucune ecriture de terrain directe',bloc('finaliserAchatTerrain').indexOf('sbSetTerrainState')<0);att('aucune archive separee',bloc('finaliserAchatTerrain').indexOf('sbEnregistrerVenteTerrain')<0);att('titre conserve dans le contrat',bloc('finaliserAchatTerrain').indexOf("titre==='achat_direct'")>=0);
print(ko?'ECHEC : '+ko+' epreuve(s) sur '+n:'LES '+n+' EPREUVES SONT VERTES.');
