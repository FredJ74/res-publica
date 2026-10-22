import { createClient } from "npm:@supabase/supabase-js@2.57.0";
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,apikey,content-type","Access-Control-Allow-Methods":"POST,OPTIONS"};
const reply=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response(null,{headers:cors});
 if(req.method!=="POST")return reply({error:"Methode interdite"},405);
 const token=(req.headers.get("authorization")||"").replace(/^Bearer\s+/i,"");
 if(!token)return reply({error:"Session requise"},401);
 const url=Deno.env.get("SUPABASE_URL")!, anon=Deno.env.get("SUPABASE_ANON_KEY")!, service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 const auth=createClient(url,anon,{global:{headers:{Authorization:"Bearer "+token}}});
 const {data:{user},error:ue}=await auth.auth.getUser(token);
 if(ue||!user)return reply({error:"Session invalide"},401);
 const db=createClient(url,service);
 let body;try{body=await req.json()}catch{return reply({error:"Requete invalide"},400)}
 const fondsId=String(body.fondsId||"").slice(0,150), action=String(body.action||"");
 if(!fondsId||!["start","retouch","finalize","upload_source","consent","versions","restart"].includes(action))return reply({error:"Parametres invalides"},400);
 const {data:perso}=await db.from("personnages").select("name").eq("user_id",user.id).limit(100);
 const noms=new Set((perso||[]).map(p=>p.name));
 const {data:fonds}=await db.from("entreprises").select("data").eq("id",fondsId).maybeSingle();
 const owner=String(fonds?.data?.proprietaire||"").replace(/^pj:/,"");
 if(!owner||!noms.has(owner)||fonds?.data?.statut==="inactif")return reply({error:"Vous ne possedez pas ce commerce"},403);
 const {data:existing}=await db.from("commerce_decors").select("*").eq("fonds_id",fondsId).maybeSingle();
 if(existing?.retiree_le)return reply({error:"Visuel retire par moderation"},403);
 // Beta only: no real-money charge is made here. Stripe entitlement will
 // replace this beta gate before commercial release.
 if(action==="restart"){
  if(!existing)return reply({error:"Aucun projet a recommencer"},400);
  if(!existing.preview_path && !existing.image_path)return reply({error:"Aucune decoration existante"},409);
  const {data:reset,error:resetError}=await db.from("commerce_decors")
    .update({preview_path:null,retouches:0,updated_at:new Date().toISOString()})
    .eq("fonds_id",fondsId).eq("owner_user_id",user.id)
    .is("retiree_le",null).select("fonds_id").maybeSingle();
  return resetError||!reset?reply({error:"Reinitialisation impossible"},409):reply({ok:true});
 }
 if(action==="versions"){
  const {data:versions}=await db.from("visuels_versions").select("image_path,cree_le").eq("type_visuel","commerce").eq("objet_id",fondsId).order("cree_le",{ascending:false}).limit(50);
  return reply({ok:true,versions:versions||[]});
 }
 if(action==="consent"){
  const {error}=existing?await db.from("commerce_decors").update({consentement_sources_le:new Date().toISOString()}).eq("fonds_id",fondsId):await db.from("commerce_decors").insert({fonds_id:fondsId,owner_user_id:user.id,consentement_sources_le:new Date().toISOString()});
  return error?reply({error:"Consentement impossible"},500):reply({ok:true});
 }
 if(action==="upload_source"){
  const {count}=await db.from("commerce_decors_sources").select("id",{count:"exact",head:true}).eq("fonds_id",fondsId).eq("proprietaire_user_id",user.id);
  if((count||0)>=5)return reply({error:"Cinq images maximum"},409);
  const mime=String(body.mime||""),encoded=String(body.base64||"");
  if(!["image/png","image/jpeg","image/webp"].includes(mime)||encoded.length>7200000)return reply({error:"Format ou taille incorrecte"},400);
  let raw;try{raw=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0))}catch{return reply({error:"Image invalide"},400)}
  if(raw.length>5242880||raw.length<100)return reply({error:"5 Mo maximum"},400);
  const sig=mime==="image/png"?raw[0]===137&&raw[1]===80:mime==="image/jpeg"?raw[0]===255&&raw[1]===216:String.fromCharCode(...raw.slice(0,4))==="RIFF";
  if(!sig)return reply({error:"Format invalide"},400);
  const ext=mime==="image/png"?"png":mime==="image/jpeg"?"jpg":"webp";
  const path=user.id+"/"+fondsId.replace(/[^a-zA-Z0-9_-]/g,"")+"/"+crypto.randomUUID()+"."+ext;
  const {error:up}=await db.storage.from("publicites-premium-sources").upload(path,raw,{contentType:mime});
  if(up)return reply({error:"Stockage impossible"},500);
  const hash=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",raw))).map(x=>x.toString(16).padStart(2,"0")).join("");
  const {error:save}=await db.from("commerce_decors_sources").insert({fonds_id:fondsId,proprietaire_user_id:user.id,chemin:path,nom_original:String(body.filename||"image").slice(0,180),type_mime:mime,taille_octets:raw.length,empreinte_sha256:hash});
  return save?reply({error:"Traçabilité impossible"},500):reply({ok:true});
 }
 if(action==="finalize"){
  if(!existing?.preview_path)return reply({error:"Aucun apercu a valider"},400);
  const {data:saved,error}=await db.from("commerce_decors").update({image_path:existing.preview_path,preview_path:null,updated_at:new Date().toISOString()}).eq("fonds_id",fondsId).eq("preview_path",existing.preview_path).is("retiree_le",null).select("fonds_id").maybeSingle();
  return error||!saved?reply({error:"Apercu deja modifie ou retire"},409):reply({ok:true,path:existing.preview_path});
 }
 if(action==="start"&&existing?.preview_path)return reply({error:"Terminez ou recommencez votre projet actuel"},409);
 if(action==="retouch"&&(!existing?.preview_path||existing.retouches>=2))return reply({error:"Deux retouches maximum"},400);
 const prompt=String(body.prompt||"").trim().slice(0,1500);
 if(prompt.length<10)return reply({error:"Decrivez votre decoration plus precisement"},400);
 const key=Deno.env.get("OPENAI_API_KEY");if(!key)return reply({error:"Cle OpenAI absente du serveur"},503);
 let bytes:Uint8Array;
 if(action==="retouch"){
  const {data,error}=await db.storage.from("commerce-decors").download(existing.preview_path);
  if(error||!data)return reply({error:"Apercu introuvable"},404);
  bytes=new Uint8Array(await data.arrayBuffer());
 }else{
  const base=String(body.baseImage||"");
  if(!/^data:image\/(png|jpeg|webp);base64,/.test(base)||base.length>9500000)return reply({error:"Image originale invalide"},400);
  try{bytes=Uint8Array.from(atob(base.split(",")[1]),c=>c.charCodeAt(0))}catch{return reply({error:"Image invalide"},400)}
 }
 if(bytes.length>7000000)return reply({error:"Image trop volumineuse"},413);
 const {data:sources}=await db.from("commerce_decors_sources").select("chemin,type_mime").eq("fonds_id",fondsId).eq("proprietaire_user_id",user.id).order("cree_le",{ascending:true}).limit(5);
 if(sources?.length&&!existing?.consentement_sources_le)return reply({error:"Acceptez les conditions des images"},409);
 const form=new FormData();
 form.append("model","gpt-image-1.5");
 form.append("size","1536x1024");
 form.append("quality","medium");
 form.append("output_format","webp");
 form.append("output_compression","85");
 form.append("prompt","Edit the provided photograph of a shop interior. PRESERVE EXACTLY the original architectural geometry, walls, windows, doors, openings, room dimensions and camera angle. Change only the interior furnishing, decoration, lighting, shop signage and display fixtures. Photorealistic professional game environment, no people. User wishes (in French): "+prompt);
 const photoWebp=bytes.length>=12&&String.fromCharCode(...bytes.slice(0,4))==="RIFF"&&String.fromCharCode(...bytes.slice(8,12))==="WEBP";
 const photoPng=bytes.length>=8&&bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71;
 const photoJpeg=bytes.length>=3&&bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
 if(!photoWebp&&!photoPng&&!photoJpeg)return reply({error:"Format du decor source invalide"},400);
 const photoMime=photoWebp?"image/webp":photoPng?"image/png":"image/jpeg";
 const photoExt=photoWebp?"webp":photoPng?"png":"jpg";
 form.append("image",new File([bytes],"interieur."+photoExt,{type:photoMime}));
 for(const source of sources||[]){
  const {data:file,error}=await db.storage.from("publicites-premium-sources").download(source.chemin);
  if(error||!file)return reply({error:"Image de référence manquante"},409);
  form.append("image",new File([await file.arrayBuffer()],"reference."+ (source.type_mime==="image/jpeg"?"jpg":source.type_mime==="image/webp"?"webp":"png"),{type:source.type_mime}));
 }

 const response=await fetch("https://api.openai.com/v1/images/edits",{method:"POST",headers:{Authorization:"Bearer "+key},body:form});
 const result=await response.json().catch(()=>({}));
 if(!response.ok)return reply({error:"OpenAI: "+String(result.error?.message||response.status).slice(0,250)},502);
 const encoded=result.data?.[0]?.b64_json;
 if(!encoded)return reply({error:"Aucune image recue"},502);
 const webp=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
 if(webp.length<12||String.fromCharCode(...webp.slice(0,4))!=="RIFF"||String.fromCharCode(...webp.slice(8,12))!=="WEBP")
   return reply({error:"Format WebP invalide retourne par le generateur"},502);
 const path=fondsId.replace(/[^a-zA-Z0-9_-]/g,"")+"-"+crypto.randomUUID()+".webp";
 const {error:uploadError}=await db.storage.from("commerce-decors").upload(path,webp,{contentType:"image/webp",upsert:false});
 if(uploadError)return reply({error:"Sauvegarde image impossible"},500);
 const payload={fonds_id:fondsId,owner_user_id:user.id,image_path:existing?.image_path||null,preview_path:path,retouches:action==="retouch"?(existing?.retouches||0)+1:0,generations:(existing?.generations||0)+1,consentement_sources_le:existing?.consentement_sources_le||null,updated_at:new Date().toISOString()};
 const resultSave=action==="retouch"?await db.from("commerce_decors").update(payload).eq("fonds_id",fondsId).eq("preview_path",existing.preview_path).eq("retouches",existing.retouches).is("retiree_le",null).select("fonds_id").maybeSingle():await db.from("commerce_decors").upsert(payload).select("fonds_id").maybeSingle();
 const saveError=resultSave.error||!resultSave.data;
 if(saveError)return reply({error:"Enregistrement impossible"},500);
 await db.from("visuels_versions").insert({type_visuel:"commerce",objet_id:fondsId,image_path:path,auteur_user_id:user.id,action});
 return reply({ok:true,path,retouches:action==="retouch"?(existing?.retouches||0)+1:0});
});