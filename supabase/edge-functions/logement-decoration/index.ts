// Décors par IA des appartements populaires premium (décisions de Fred du 12/11/2026,
// GAME-DESIGN-APPARTEMENTS.md) : même atelier que le Commerce Premium (commerce-decoration),
// une génération et deux retouches par pièce. Le droit de décorer une pièce est décidé par le
// serveur (logement_decor_droit_interne) : titulaire seul = tout ; en colocation, le colocataire
// sa chambre, le titulaire sa chambre et le salon ; époux = toutes les pièces.
// Bêta : aucun paiement ; la nouvelle génération sera facturée 0,99 € lors de la session premium.
import { createClient } from "npm:@supabase/supabase-js@2.57.0";
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,apikey,content-type","Access-Control-Allow-Methods":"POST,OPTIONS"};
const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
const propre=(v:unknown,n=80)=>String(v||"").replace(/[^A-Za-z0-9_-]/g,"").slice(0,n);
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
 let body:any;try{body=await req.json()}catch{return reply({error:"Requete invalide"},400)}
 const pays=propre(body.pays,20), ville=propre(body.ville,40), batiment=propre(body.batiment), piece=propre(body.piece), action=String(body.action||"");
 if(!pays||!ville||!batiment||!piece||!["start","retouch","finalize","versions","restart"].includes(action))return reply({error:"Parametres invalides"},400);
 const cle=pays+"|"+ville+"|"+batiment+"|"+piece;
 // Droit de décorer : décidé par le serveur pour l'un des personnages de ce compte.
 const {data:perso}=await db.from("personnages").select("name").eq("user_id",user.id).limit(100);
 let autorise=false;
 for(const p of perso||[]){
  const {data:ok}=await db.rpc("logement_decor_droit_interne",{p_nom:p.name,p_pays:pays,p_ville:ville,p_batiment:batiment,p_piece:piece});
  if(ok===true){autorise=true;break;}
 }
 if(!autorise)return reply({error:"Vous ne pouvez pas décorer cette pièce"},403);
 const {data:existing}=await db.from("logements_decors").select("*").eq("cle",cle).maybeSingle();
 if(existing?.retiree_le)return reply({error:"Visuel retire par moderation"},403);
 if(action==="restart"){
  if(!existing||(!existing.preview_path&&!existing.image_path))return reply({error:"Aucune decoration existante"},409);
  const {data:reset,error}=await db.from("logements_decors").update({preview_path:null,retouches:0,updated_at:new Date().toISOString()})
    .eq("cle",cle).is("retiree_le",null).select("cle").maybeSingle();
  return error||!reset?reply({error:"Reinitialisation impossible"},409):reply({ok:true});
 }
 if(action==="versions"){
  const {data:versions}=await db.from("visuels_versions").select("image_path,cree_le").eq("type_visuel","logement").eq("objet_id",cle).order("cree_le",{ascending:false}).limit(50);
  return reply({ok:true,versions:versions||[]});
 }
 if(action==="finalize"){
  if(!existing?.preview_path)return reply({error:"Aucun apercu a valider"},400);
  const {data:saved,error}=await db.from("logements_decors").update({image_path:existing.preview_path,preview_path:null,updated_at:new Date().toISOString()})
    .eq("cle",cle).eq("preview_path",existing.preview_path).is("retiree_le",null).select("cle").maybeSingle();
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
 const webpIn=bytes.length>=12&&String.fromCharCode(...bytes.slice(0,4))==="RIFF"&&String.fromCharCode(...bytes.slice(8,12))==="WEBP";
 const pngIn=bytes.length>=8&&bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71;
 const jpegIn=bytes.length>=3&&bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
 if(!webpIn&&!pngIn&&!jpegIn)return reply({error:"Format du decor source invalide"},400);
 const form=new FormData();
 form.append("model","gpt-image-1.5");
 form.append("size","1536x1024");
 form.append("quality","medium");
 form.append("output_format","webp");
 form.append("output_compression","85");
 form.append("prompt","Edit the provided photograph of a modest apartment room interior. PRESERVE EXACTLY the original architectural geometry, walls, windows, doors, openings, room dimensions and camera angle. Change only the furniture, decoration, textiles, wall colours and lighting. Photorealistic game environment, no people. User wishes (in French): "+prompt);
 form.append("image",new File([bytes],"piece."+(webpIn?"webp":pngIn?"png":"jpg"),{type:webpIn?"image/webp":pngIn?"image/png":"image/jpeg"}));
 const response=await fetch("https://api.openai.com/v1/images/edits",{method:"POST",headers:{Authorization:"Bearer "+key},body:form});
 const result=await response.json().catch(()=>({}));
 if(!response.ok)return reply({error:"OpenAI: "+String(result.error?.message||response.status).slice(0,250)},502);
 const encoded=result.data?.[0]?.b64_json;
 if(!encoded)return reply({error:"Aucune image recue"},502);
 const webp=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
 if(webp.length<12||String.fromCharCode(...webp.slice(0,4))!=="RIFF"||String.fromCharCode(...webp.slice(8,12))!=="WEBP")
   return reply({error:"Format WebP invalide retourne par le generateur"},502);
 const path="logement-"+propre(pays+"-"+ville+"-"+batiment+"-"+piece,200)+"-"+crypto.randomUUID()+".webp";
 const {error:uploadError}=await db.storage.from("commerce-decors").upload(path,webp,{contentType:"image/webp",upsert:false});
 if(uploadError)return reply({error:"Sauvegarde image impossible"},500);
 const retouches=action==="retouch"?(existing?.retouches||0)+1:0;
 const payload={cle,pays,ville,batiment,piece,owner_user_id:user.id,image_path:existing?.image_path||null,preview_path:path,retouches,generations:(existing?.generations||0)+1,updated_at:new Date().toISOString()};
 const save=action==="retouch"
   ?await db.from("logements_decors").update(payload).eq("cle",cle).eq("preview_path",existing.preview_path).eq("retouches",existing.retouches).is("retiree_le",null).select("cle").maybeSingle()
   :await db.from("logements_decors").upsert(payload).select("cle").maybeSingle();
 if(save.error||!save.data)return reply({error:"Enregistrement impossible"},500);
 await db.from("visuels_versions").insert({type_visuel:"logement",objet_id:cle,image_path:path,auteur_user_id:user.id,action});
 return reply({ok:true,path,retouches});
});
