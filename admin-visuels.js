// Moderation des visuels : acces reserve au compte admin authentifie.
async function admVisuelsAppel(body){
 if(!rpAdminJeton())await rpAdminRenouveler();
 const token=rpAdminJeton();
 if(!token)throw Error('Session administrateur expirée');
 const res=await fetch(RP_ADMIN_BASE+'/functions/v1/visuels-moderation',{
  method:'POST',headers:{'Content-Type':'application/json',apikey:RP_ADMIN_ANON,Authorization:'Bearer '+token},
  body:JSON.stringify(body)
 });
 const data=await res.json().catch(()=>({}));
 if(!res.ok||!data.ok)throw Error(data.error||'Action refusée');
 return data;
}
async function admVisuelsCharger(){
 const el=document.getElementById('adm-visuels');if(!el)return;
 el.textContent='Chargement des visuels...';
 try{
  const data=await admVisuelsAppel({action:'list'});
  el.textContent='';
  const items=[...(data.ads||[]).map(x=>({kind:'publicite',id:x.id,title:'Publicité de '+x.personnage,path:x.image_path,retired:x.retiree_le})),
   ...(data.shops||[]).map(x=>({kind:'commerce',id:x.fonds_id,title:'Commerce '+x.fonds_id,path:x.image_path,retired:x.retiree_le}))];
  if(!items.length){el.textContent='Aucun visuel publié.';return;}
  for(const item of items){
   const row=document.createElement('div');row.className='adm-dossier';
   const title=document.createElement('strong');title.textContent=item.title;row.append(title);
   const info=document.createElement('p');info.className='adm-detail';info.textContent=item.kind+' — '+item.id;row.append(info);
   const button=document.createElement('button');button.type='button';button.textContent='Retirer cette image';
   button.onclick=()=>admVisuelsRetirer(item.kind,item.id);
   row.append(button);el.append(row);
  }
 }catch(e){el.textContent='Erreur : '+e.message;}
}
async function admVisuelsRetirer(kind,id){
 const reason=window.prompt('Motif du retrait (obligatoire, conservé dans le journal administratif) :');
 if(!reason||reason.trim().length<8)return;
 if(!window.confirm('Confirmer le retrait public immédiat de cette image ?'))return;
 try{
  await admVisuelsAppel({action:'remove',kind,id,reason:reason.trim()});
  await admVisuelsCharger();
 }catch(e){alert('Retrait non confirmé : '+e.message);}
}
