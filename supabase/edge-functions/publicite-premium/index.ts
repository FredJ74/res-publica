// Atelier de publicité premium dans la presse (L'Autruche Entravée). Copie versionnée de la fonction déployée (version 10,
// relue en production le 25/11/2026), avec un seul changement (mission de fin de soirée du 25/11/2026, point 2.4) :
// la campagne paraît pendant nb_parutions jours (durée réglée par le MJ, fixée à la création par la migration
// 20261125810000) ; repli pour une campagne ancienne sans durée : 5 ou 10 parutions selon sa formule.
// Déployable avant ou après la migration 20261125810000 : sans durée en base, le repli garde 5 / 10 parutions.
import {createClient} from "npm:@supabase/supabase-js@2.57.0";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,apikey,content-type","Access-Control-Allow-Methods":"POST,OPTIONS"};
const out=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response(null,{headers:cors});
 if(req.method!=="POST")return out({error:"Method not allowed"},405);
 const token=(req.headers.get("authorization")||"").replace(/^Bearer\s+/i,"");
 const url=Deno.env.get("SUPABASE_URL"),anon=Deno.env.get("SUPABASE_ANON_KEY"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!token||!url||!anon||!service)return out({error:"Unauthorized"},401);
 const auth=createClient(url,anon,{global:{headers:{Authorization:"Bearer "+token}}});
 const {data:{user},error:authError}=await auth.auth.getUser(token);
 if(authError||!user)return out({error:"Invalid session"},401);
 const db=createClient(url,service);
 let body;try{body=await req.json()}catch{return out({error:"Invalid JSON"},400)}
 const id=String(body.id||""),action=String(body.action||"");
 if(!/^[0-9a-f-]{36}$/i.test(id)||!["generate","retouch","finalize","upload_source","consent","import_final","versions"].includes(action))return out({error:"Invalid parameters"},400);
 const {data:ad,error:readError}=await db.from("publicites_premium_presse").select("*").eq("id",id).eq("acheteur_user_id",user.id).maybeSingle();
 if(readError||!ad)return out({error:"Not found"},404);

 if(action==="versions"){
  const {data:versions,error:versionsError}=await db.from("visuels_versions").select("image_path,cree_le").eq("type_visuel","publicite").eq("objet_id",id).order("cree_le",{ascending:false}).limit(50);
  return versionsError?out({error:"Historique indisponible"},500):out({ok:true,versions:versions||[]});
 }
 if(["upload_source","consent","import_final"].includes(action)){
 if(!ad.mode_beta_gratuit&&!ad.paiement_confirme_le)return out({error:"Payment required"},402);
  if(!["brouillon","apercu"].includes(ad.etat))return out({error:"Already published"},409);
  if(action==="consent"){
   const {error}=await db.from("publicites_premium_presse").update({consentement_sources_le:new Date().toISOString()}).eq("id",id).eq("acheteur_user_id",user.id);
   return error?out({error:"Consent failed"},500):out({ok:true});
  }
  const base64=String(body.base64||"");
  const mime=String(body.mime||"");
  if(!["image/png","image/jpeg","image/webp"].includes(mime)||base64.length>7200000||!base64.length)return out({error:"Format ou taille incorrecte (5 Mo maximum)"},400);
  let bytes;try{bytes=Uint8Array.from(atob(base64),c=>c.charCodeAt(0))}catch{return out({error:"Invalid image encoding"},400)}
  if(bytes.length>5242880||bytes.length<100)return out({error:"Image trop volumineuse ou vide"},400);
  const signature=mime==="image/png"?bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71:mime==="image/jpeg"?bytes[0]===255&&bytes[1]===216:mime==="image/webp"?String.fromCharCode(...bytes.slice(0,4))==="RIFF":false;
  if(!signature)return out({error:"Image invalide"},400);
  const ext=mime==="image/png"?"png":mime==="image/jpeg"?"jpg":"webp";
  const hash=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",bytes))).map(x=>x.toString(16).padStart(2,"0")).join("");
  if(action==="upload_source"){
   const {count}=await db.from("publicites_premium_sources").select("id",{count:"exact",head:true}).eq("publicite_id",id);
   if((count||0)>=5)return out({error:"Cinq images maximum"},409);
   const path=user.id+"/"+id+"/"+crypto.randomUUID()+"."+ext;
   const {error:uploadError}=await db.storage.from("publicites-premium-sources").upload(path,bytes,{contentType:mime});
   if(uploadError)return out({error:"Stockage source impossible"},500);
   const {error:recordError}=await db.from("publicites_premium_sources").insert({publicite_id:id,proprietaire_user_id:user.id,chemin:path,nom_original:String(body.filename||"image").slice(0,180),type_mime:mime,taille_octets:bytes.length,empreinte_sha256:hash});
   return recordError?out({error:"Traçabilité impossible"},500):out({ok:true});
  }
  if(!ad.consentement_sources_le)return out({error:"Acceptez les conditions avant importation"},409);
  const original=user.id+"/"+id+"/"+crypto.randomUUID()+"."+ext;
  const {error:sourceUploadError}=await db.storage.from("publicites-premium-sources").upload(original,bytes,{contentType:mime});
  if(sourceUploadError)return out({error:"Archivage de l'original impossible"},500);
  const {error:sourceInsertError}=await db.from("publicites_premium_sources").insert({publicite_id:id,proprietaire_user_id:user.id,chemin:original,nom_original:String(body.filename||"affiche").slice(0,180),type_mime:mime,taille_octets:bytes.length,empreinte_sha256:hash});
  if(sourceInsertError)return out({error:"Traçabilité de l'affiche impossible"},500);
  const path=id+"/"+crypto.randomUUID()+"."+ext;
  const {error:upErr}=await db.storage.from("publicites-premium").upload(path,bytes,{contentType:mime});
  if(upErr)return out({error:"Import impossible"},500);
  const {error:saveErr}=await db.from("publicites_premium_presse").update({apercu_path:path,etat:"apercu",origine_image:"import",modifie_le:new Date().toISOString()}).eq("id",id).eq("acheteur_user_id",user.id);
  if(!saveErr)await db.from("visuels_versions").insert({type_visuel:"publicite",objet_id:id,image_path:path,auteur_user_id:user.id,action:"import"});
  return saveErr?out({error:"Enregistrement impossible"},500):out({ok:true,path,retouches:ad.retouches||0});
 }
 if(!ad.mode_beta_gratuit&&!ad.paiement_confirme_le)return out({error:"Payment required"},402);
 if(!["brouillon","apercu"].includes(ad.etat))return out({error:"Not editable"},409);
 if(action==="finalize"){
  if(ad.etat!=="apercu"||!ad.apercu_path)return out({error:"No preview"},400);
  const paris=new Intl.DateTimeFormat("en-CA",{timeZone:"Europe/Paris",year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date());
  const [y,m,d]=paris.split("-").map(Number);
  // Point 2.4 : durée de la campagne fixée à sa création (nb_parutions, réglage MJ) ; repli : 5 / 10 selon l'ancienne formule.
  const parutions=Number.isInteger(ad.nb_parutions)&&ad.nb_parutions>=1&&ad.nb_parutions<=60?ad.nb_parutions:(ad.formule==="dix"?10:5);
  const start=new Date(Date.UTC(y,m-1,d+1)).toISOString().slice(0,10);
  const end=new Date(Date.UTC(y,m-1,d+parutions)).toISOString().slice(0,10);
  const {data:updated,error}=await db.from("publicites_premium_presse").update({image_path:ad.apercu_path,apercu_path:null,etat:"programmee",premiere_parution:start,derniere_parution:end,modifie_le:new Date().toISOString()}).eq("id",id).eq("etat","apercu").select("id").maybeSingle();
  return error||!updated?out({error:"Scheduling failed"},409):out({ok:true,premiere_parution:start,derniere_parution:end,parutions});
 }
 if(action==="retouch"&&(ad.etat!=="apercu"||!ad.apercu_path||ad.retouches>=2))return out({error:"Retouch limit"},400);
 if(action==="generate"&&ad.etat!=="brouillon")return out({error:"Already generated"},409);
 if(action==="generate"){
  const {data:sources,error:sourcesError}=await db.from("publicites_premium_sources").select("chemin").eq("publicite_id",id).limit(5);
  if(sourcesError)return out({error:"Sources unavailable"},500);
  if(sources?.length&&!ad.consentement_sources_le)return out({error:"Acceptation des droits des images requise"},409);
 }
 const notes=String(body.prompt||"").trim().slice(0,1200);
 if(action==="retouch"&&notes.length<10)return out({error:"Describe retouch"},400);
 const key=Deno.env.get("OPENAI_API_KEY");if(!key)return out({error:"AI unavailable"},503);
 const prompt=action==="generate"?"Design a professional French newspaper advertisement as a full portrait page, clear readable typography. User brief: "+ad.instructions+". "+(ad.assistance_ia?"Propose a compelling design without inventing facts.":"Follow the brief closely without adding claims."):"Edit this advertisement, preserving everything except the requested changes: "+notes;
 const form=new FormData();form.append("model","gpt-image-1.5");form.append("size","1024x1536");form.append("quality","medium");form.append("prompt",prompt);
 let endpoint="https://api.openai.com/v1/images/generations";
 if(action==="retouch"){
  endpoint="https://api.openai.com/v1/images/edits";
  const {data,error}=await db.storage.from("publicites-premium").download(ad.apercu_path);
  if(error||!data)return out({error:"Preview missing"},404);
  form.append("image",new File([await data.arrayBuffer()],"ad.png",{type:"image/png"}));
 }
 let hasReferenceImages=false;
 if(action==="generate"){
  const {data:sources}=await db.from("publicites_premium_sources").select("chemin,type_mime").eq("publicite_id",id).order("cree_le",{ascending:true}).limit(5);
  for(const source of sources||[]){
   const {data:file,error}=await db.storage.from("publicites-premium-sources").download(source.chemin);
   if(error||!file)return out({error:"Une image source est indisponible"},409);
   form.append("image",new File([await file.arrayBuffer()],"reference."+ (source.type_mime==="image/png"?"png":source.type_mime==="image/jpeg"?"jpg":"webp"),{type:source.type_mime}));
   hasReferenceImages=true;
  }
  if(hasReferenceImages)endpoint="https://api.openai.com/v1/images/edits";
 }
 const jsonRequest=action==="generate"&&!hasReferenceImages;
 const ai=await fetch(endpoint,{method:"POST",headers:jsonRequest?{Authorization:"Bearer "+key,"Content-Type":"application/json"}:{Authorization:"Bearer "+key},body:jsonRequest?JSON.stringify({model:"gpt-image-1.5",size:"1024x1536",quality:"medium",prompt}):form});
 const result=await ai.json().catch(()=>({}));
 if(!ai.ok)return out({error:String(result.error?.message||ai.status).slice(0,180)},502);
 const encoded=result.data?.[0]?.b64_json;if(!encoded)return out({error:"No image"},502);
 const bytes=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
 const path=id+"/"+crypto.randomUUID()+".png";
 const {error:uploadError}=await db.storage.from("publicites-premium").upload(path,bytes,{contentType:"image/png",upsert:false});
 if(uploadError)return out({error:"Upload failed"},503);
 const {data:updated,error:saveError}=await db.from("publicites_premium_presse").update({apercu_path:path,etat:"apercu",retouches:action==="retouch"?ad.retouches+1:0,modifie_le:new Date().toISOString()}).eq("id",id).eq("etat",ad.etat).eq("retouches",ad.retouches).eq("apercu_path",ad.apercu_path).select("id").maybeSingle();
 if(saveError||!updated)return out({error:"Save failed"},409);
 await db.from("visuels_versions").insert({type_visuel:"publicite",objet_id:id,image_path:path,auteur_user_id:user.id,action});
 return out({ok:true,path,retouches:action==="retouch"?ad.retouches+1:0});
});
