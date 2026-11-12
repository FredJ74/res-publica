// Université : toutes les écritures passent par les RPC serveur.
// Les textes visibles utilisent les neuf langues du socle ; jamais de second moteur.
(function(){'use strict';
let el;
const rpc=(name,args={})=>sbRpcVerdict(name,args);
const tr=(key,vars={})=>window.RPUniversityI18n?.text?.(key,vars)||key;
const date=(v)=>window.RPUniversityI18n?.date?.(v)||new Date(v).toLocaleString('fr-FR');
function add(tag,text,parent,key=null,params={}){
 const e=document.createElement(tag);
 e.textContent=key?tr(key,params):text;
 if(key){
  e.dataset.uI18n=key;
  e.dataset.uParams=JSON.stringify(params);
 }
 parent.appendChild(e);
 return e;
}
function message(tag,key,parent,params={}){
 return add(tag,'',parent,key,params);
}
function btn(key,fn,parent,params={}){
 const e=message('button',key,parent,params);
 e.type='button';
 e.style.cssText='margin:6px;padding:9px;background:#342914;color:#fff;border:1px solid #ac8b40;cursor:pointer';
 e.onclick=fn;
 return e;
}
function open(){
 if(el)el.remove();
 el=document.createElement('div');
 el.style.cssText='position:fixed;inset:0;z-index:99999;background:#111e;color:#eee;display:flex;align-items:center;justify-content:center';
 const d=add('div','',el);
 d.id='universite-interface';
 d.style.cssText='background:#191714;border:1px solid #b99a55;padding:20px;width:min(650px,94vw);max-height:90vh;overflow:auto';
 document.body.appendChild(el);
 btn('close',()=>{el.remove();el=null},d);
 return d;
}
function messageErreur(key,reason){
 const raw=reason?String(reason):'';
 const prefix=tr(key,{reason:raw});
 // Les raisons serveur non traduites restent affichées telles que reçues,
 // mais n'influencent jamais les conditions ni les validations.
 return raw&&key!=='validationRefused'?raw:prefix;
}
async function load(){
 const d=open();
 message('h2','title',d);
 const [s,n]=await Promise.all([rpc('universite_mon_etat'),rpc('universite_prochaine_etape')]);
 if(!s.ok){add('p',s.raison||tr('connection'),d);return;}
 message('p','intro',d);
 if(!s.cursus_actif){
  if(s.slot_consomme){message('p','already',d);return;}
  for(const c of s.cursus_disponibles||[]){
   add('p',c.libelle,d);
   btn('register',async()=>{
    const r=await rpc('universite_inscrire',{p_cursus:c.id});
    if(!r.ok)alert(r.raison||tr('registrationRefused'));
    await load();
   },d);
  }
  return;
 }
 const c=s.cursus_actif;
 message('p','progress',d,{name:c.cursus,done:c.jalons_accomplis,total:c.jalons_total});
 const e=n.ok?n.etape:null;
 if(e){
  add('h3',e.libelle,d);
  message('p','place',d,{city:e.ville,building:e.batiment,room:e.piece?' / '+e.piece:''});
  const dateLine=message('p','available',d,{date:date(e.ouvre_le)});
  dateLine.dataset.uDate=e.ouvre_le;
  if(e.ouvert)btn(e.genre==='universite'?'followCourse':'meetMentor',()=>dialogue(e),d);
 }else if(c.diplomable){
  btn('graduate',async()=>{
   const r=await rpc('universite_diplomer');
   if(!r.ok)alert(r.raison);
   await load();
  },d);
 }else message('p','completed',d);
}
function dialogue(e){
 const d=open();
 const campus=e.genre==='universite';
 message('h2',campus?'courseTitle':'internshipTitle',d);
 const fil=add('div','',d);
 fil.style.cssText='background:#28241c;padding:12px';
 message('p',campus?'teacherIntro':'mentorIntro',fil,{action:e.action||e.libelle});
 const input=add('textarea','',d);
 input.placeholder=tr('answerPlaceholder');
 input.dataset.uPlaceholder='answerPlaceholder';
 input.style.cssText='display:block;width:95%;background:#111;color:white;margin:10px 0';
 btn('reply',()=>{
  if(!input.value.trim())return;
  message('p','you',fil,{answer:input.value});
  message('p','teacherReply',fil);
  input.value='';
 },d);
 btn(campus?'endCourse':'perform',async()=>{
  const r=await rpc('universite_valider_etape',{p_jalon:e.id,p_action:e.genre==='terrain'?e.action:null});
  if(!r.ok)alert(tr('validationRefused',{reason:r.raison}));
  await load();
 },d,{action:e.action});
 btn('back',load,d);
}
// La langue change dans le contenu déjà ouvert sans détruire la saisie ni
// rappeler les RPC (une nouvelle requête pourrait écraser le dialogue local).
(window.RP_I18N_CHANGE_CALLBACKS=window.RP_I18N_CHANGE_CALLBACKS||[]).push(function(){
 if(!el||!document.getElementById('universite-interface'))return;
 el.querySelectorAll('[data-u-i18n]').forEach(node=>{
  const key=node.dataset.uI18n;
  let vars={};try{vars=JSON.parse(node.dataset.uParams||'{}');}catch(_){}
  if(node.dataset.uDate)vars.date=date(node.dataset.uDate);
  node.textContent=tr(key,vars);
 });
 el.querySelectorAll('[data-u-placeholder]').forEach(node=>{
  node.placeholder=tr(node.dataset.uPlaceholder);
 });
});
window.ouvrirUniversiteFormation=load;
})();
