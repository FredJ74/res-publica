// Accessoire de club personnalisé (mission du soir du 27/11/2026, étape 7, décision de Fred) : génération de l'image par IA,
// sur le modèle de publicite-premium (gpt-image, modération du fournisseur, deux retouches au plus), puis livraison dans
// l'inventaire par accessoire_personnalise_livrer_service. Toutes les actions exigent un paiement CONFIRMÉ
// (accessoires_personnalises.paiement_confirme_le, posé par le webhook du prestataire) : tant que le prestataire n'est pas
// choisi, aucune commande n'est payée et cette fonction ne peut rien produire. NON DÉPLOYÉE : à déployer avec le paiement.
// Actions : generate, retouch, finalize.
import {createClient} from "npm:@supabase/supabase-js@2.57.0";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,apikey,content-type","Access-Control-Allow-Methods":"POST,OPTIONS"};
const out=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
const LIBELLES={maillot:"football jersey",casquette:"baseball cap",echarpe:"knitted supporter scarf"};
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
 if(!/^[0-9a-f-]{36}$/i.test(id)||!["generate","retouch","finalize"].includes(action))return out({error:"Invalid parameters"},400);
 const {data:acc,error:readError}=await db.from("accessoires_personnalises").select("*").eq("id",id).eq("acheteur_user_id",user.id).maybeSingle();
 if(readError||!acc)return out({error:"Not found"},404);
 if(!acc.paiement_confirme_le)return out({error:"Payment required"},402);
 if(!["commande","apercu"].includes(acc.etat))return out({error:"Not editable"},409);
 if(action==="finalize"){
  if(acc.etat!=="apercu"||!acc.apercu_path)return out({error:"No preview"},400);
  const {data:livre,error}=await db.rpc("accessoire_personnalise_livrer_service",{p_id:id});
  return error||!livre?.ok?out({error:livre?.raison||"Delivery failed"},409):out({ok:true,objet:livre.objet});
 }
 if(action==="retouch"&&(acc.etat!=="apercu"||!acc.apercu_path||acc.retouches>=2))return out({error:"Retouch limit"},400);
 if(action==="generate"&&acc.etat!=="commande")return out({error:"Already generated"},409);
 const notes=String(body.prompt||"").trim().slice(0,600);
 if(action==="retouch"&&notes.length<5)return out({error:"Describe retouch"},400);
 const key=Deno.env.get("OPENAI_API_KEY");if(!key)return out({error:"AI unavailable"},503);
 const prompt=action==="generate"
  ?"Product photo of a "+(LIBELLES[acc.type_accessoire]||"supporter accessory")+" of the football club \""+acc.club+"\", personalised as requested by the buyer: "+acc.demande+". Plain light background, no real brand logos, no real people."
  :"Adjust this supporter accessory image: "+notes+". Keep the club \""+acc.club+"\" and the personalisation \""+acc.demande+"\".";
 let ai;
 if(action==="retouch"){
  const {data,error}=await db.storage.from("accessoires-personnalises").download(acc.apercu_path);
  if(error||!data)return out({error:"Preview missing"},404);
  const form=new FormData();form.append("model","gpt-image-1.5");form.append("size","1024x1024");form.append("quality","medium");form.append("prompt",prompt);
  form.append("image",new File([await data.arrayBuffer()],"accessoire.png",{type:"image/png"}));
  ai=await fetch("https://api.openai.com/v1/images/edits",{method:"POST",headers:{Authorization:"Bearer "+key},body:form});
 }else{
  ai=await fetch("https://api.openai.com/v1/images/generations",{method:"POST",headers:{Authorization:"Bearer "+key,"Content-Type":"application/json"},body:JSON.stringify({model:"gpt-image-1.5",size:"1024x1024",quality:"medium",prompt})});
 }
 const result=await ai.json().catch(()=>({}));
 // La modération du fournisseur refuse les demandes contraires à ses règles : l'erreur est rendue telle quelle.
 if(!ai.ok)return out({error:String(result.error?.message||ai.status).slice(0,180)},502);
 const encoded=result.data?.[0]?.b64_json;if(!encoded)return out({error:"No image"},502);
 const bytes=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
 const path=id+"/"+crypto.randomUUID()+".png";
 const {error:uploadError}=await db.storage.from("accessoires-personnalises").upload(path,bytes,{contentType:"image/png",upsert:false});
 if(uploadError)return out({error:"Upload failed"},503);
 const retouches=action==="retouch"?acc.retouches+1:0;
 const {data:updated,error:saveError}=await db.from("accessoires_personnalises").update({apercu_path:path,etat:"apercu",retouches}).eq("id",id).eq("etat",acc.etat).eq("retouches",acc.retouches).select("id").maybeSingle();
 if(saveError||!updated)return out({error:"Save failed"},409);
 await db.from("visuels_versions").insert({type_visuel:"accessoire",objet_id:id,image_path:path,auteur_user_id:user.id,action});
 return out({ok:true,path,retouches});
});
