// Premier onglet Aide : conversation universelle hors-roleplay.
// Réutilise le fournisseur et l'authentification de /api/chat ; aucune lecture/écriture métier.
import { appelDeepSeek, joueurAuthentifie, classerEchecFournisseur } from './_deepseek.js';
import { construirePromptAide, langueAide } from './_aide-hrp.js';

const ORIGINE='https://res-publica.vercel.app';
export function validerAide(body) {
  if(!body || typeof body!=='object' || Array.isArray(body)) return 'Requête invalide.';
  if(Object.keys(body).some(k=>!['message','historique','lang'].includes(k))) return 'Champ interdit.';
  if(typeof body.message!=='string' || !body.message.trim() || body.message.length>1000) return 'Question invalide (1 à 1000 caractères).';
  if(body.lang!==undefined && (typeof body.lang!=='string' || body.lang.length>8)) return 'Langue invalide.';
  if(body.historique!==undefined) {
    if(!Array.isArray(body.historique) || body.historique.length>6) return 'Historique invalide.';
    for(const h of body.historique) {
      if(!h || typeof h!=='object'||Array.isArray(h)||
         Object.keys(h).some(k=>!['role','content'].includes(k)) ||
         !['assistant','user'].includes(h.role) ||
         typeof h.content!=='string'||!h.content.trim()||h.content.length>1500)
        return 'Historique invalide.';
    }
  }
  return null;
}

export default async function handler(req,res) {
  if(req.headers?.origin===ORIGINE) res.setHeader('Access-Control-Allow-Origin',ORIGINE);
  res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers','Content-Type, Authorization');
  res.setHeader('Cache-Control','no-store');
  if(req.method==='OPTIONS')return res.status(200).end();
  if(req.method!=='POST')return res.status(405).json({error:'Méthode non autorisée.'});
  const err=validerAide(req.body);
  if(err)return res.status(400).json({error:err});
  const joueur=await joueurAuthentifie(req,{signal:AbortSignal.timeout(4000)});
  if(!joueur)return res.status(401).json({error:'Connexion requise pour poser une question.'});
  const messages=(req.body.historique||[]).map(m=>({role:m.role,content:m.content}));
  messages.push({role:'user',content:req.body.message.trim()});
  const reponse=await appelDeepSeek({
    systeme:construirePromptAide(langueAide(req.body.lang)),
    messages,
    maxTokens:600,
    timeoutMs:22000
  });
  if(!reponse?.ok) {
    const cause=classerEchecFournisseur(reponse);
    console.error('[aide-hrp]',{cause:cause?.cause||'inconnue'});
    return res.status(503).json({error:'L’aide est momentanément indisponible. Les rubriques écrites restent accessibles.'});
  }
  if(reponse.tronque || !reponse.texte?.trim())return res.status(503).json({error:'Réponse incomplète. Essaie une question plus courte.'});
  return res.status(200).json({reponse:reponse.texte.trim()});
}
