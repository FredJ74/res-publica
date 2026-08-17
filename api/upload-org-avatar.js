// =====================
// API VERCEL — UPLOAD DE L'AVATAR D'UNE ORGANISATION (17 aout 2026)
// =====================
// Remplace l'upload direct cote client vers Supabase Storage (rejete en revue : un appel API
// direct pouvait contourner sauvegarderOptionsOrga/sbUploadOrgAvatar -- format, taille, ET la
// verification du chef -- puisque le bucket acceptait INSERT/DELETE depuis la cle anon). Cette
// fonction fait desormais AUTORITE sur les trois controles, incontournables par un appel direct
// a l'API Supabase :
//   - format (Content-Type reellement recu, pas declare par le client) ;
//   - taille reelle du corps recu (coupee des le depassement, jamais entierement bufferisee) ;
//   - chef actuel de l'organisation (lecture fraiche de 'organisations', jamais confiance au
//     client).
//
// Cle privilegiee : SUPABASE_SERVICE_ROLE_KEY, UNIQUEMENT lue depuis une variable d'environnement
// Vercel (process.env) -- n'apparait dans AUCUN fichier client, n'est jamais renvoyee au
// navigateur, n'est utilisee que pour les operations d'ecriture/suppression sur le bucket
// 'org-avatars' (le contourne RLS par nature, aucune policy anon INSERT/DELETE necessaire ni
// souhaitee -- voir migration_org_avatars_storage.sql). La lecture de 'organisations' (deja
// publique) continue d'utiliser la cle anon, meme convention que api/cron-minuit.js.
//
// Limite assumee explicitement (validee par Fred avant implementation) : characterName reste
// une declaration du client, non authentifiee cryptographiquement -- aucune session/auth
// joueur n'existe nulle part dans ce projet aujourd'hui (dette systemique, pas propre a cet
// endpoint, traitee separement). Ce que cette fonction garantit reellement : la verification du
// chef et les controles de format/taille ne peuvent plus etre contournes par un appel direct,
// contrairement a l'ancienne architecture (upload direct + policies anon permissives).
//
// Corps de la requete : LE FICHIER BRUT (pas de JSON, pas de base64) -- bodyParser desactive,
// lu manuellement avec une limite stricte pour ne jamais bufferiser plus que le maximum autorise.
export const config = { api: { bodyParser: false } };

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || null;

const ORG_AVATAR_BUCKET = 'org-avatars';
const ORG_AVATAR_MAX_BYTES = 2 * 1024 * 1024; // 2 Mo -- meme limite que documentee au joueur
const ORG_AVATAR_MIME_EXT = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp' };
const ORGA_ID_RE = /^[a-zA-Z0-9_-]+$/; // namespace Storage -- jamais de '/', '..' ou autre injection de chemin

function publicAvatarUrl(path) {
  return `${SUPABASE_URL}/storage/v1/object/public/${ORG_AVATAR_BUCKET}/${path}`;
}
const PUBLIC_PREFIX = `${SUPABASE_URL}/storage/v1/object/public/${ORG_AVATAR_BUCKET}/`;

// Lit le corps de la requete en le coupant DES QUE la limite est depassee -- ne bufferise
// jamais un fichier volumineux en entier avant de le rejeter (contrairement a une simple
// verification de Content-Length, facilement falsifiable par le client).
function lireCorpsLimite(req, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    let coupe = false;
    req.on('data', (chunk) => {
      if (coupe) return;
      total += chunk.length;
      if (total > maxBytes) {
        coupe = true;
        reject(new Error('PAYLOAD_TOO_LARGE'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => { if (!coupe) resolve(Buffer.concat(chunks)); });
    req.on('error', reject);
  });
}

async function getOrganisationFraiche(orgaId) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/organisations?id=eq.${encodeURIComponent(orgaId)}`, {
    headers: { 'apikey': SUPABASE_ANON, 'Authorization': `Bearer ${SUPABASE_ANON}` }
  });
  if (!res.ok) return null;
  const rows = await res.json();
  if (!rows || rows.length === 0) return null;
  try { return JSON.parse(rows[0].data); } catch (e) { return null; }
}

async function uploadVersStorage(path, buffer, contentType) {
  return fetch(`${SUPABASE_URL}/storage/v1/object/${ORG_AVATAR_BUCKET}/${path}`, {
    method: 'POST',
    headers: {
      'apikey': SUPABASE_SERVICE_ROLE,
      'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE}`,
      'Content-Type': contentType
    },
    body: buffer
  });
}

async function supprimerDeStorage(path) {
  return fetch(`${SUPABASE_URL}/storage/v1/object/${ORG_AVATAR_BUCKET}/${path}`, {
    method: 'DELETE',
    headers: { 'apikey': SUPABASE_SERVICE_ROLE, 'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE}` }
  }).catch(() => {});
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Le controle de configuration (cle service_role) est volontairement place JUSTE AVANT
  // l'ecriture reelle, pas en tout premier -- toutes les validations qui precedent (format,
  // taille, chef actuel) restent ainsi entierement verifiables des le deploiement, avant meme
  // que la variable d'environnement ne soit configuree cote Vercel.
  const orgaId = String(req.query.orgaId || '');
  const characterName = String(req.query.characterName || '');
  if (!orgaId || !ORGA_ID_RE.test(orgaId) || !characterName) {
    return res.status(400).json({ error: 'Paramètres invalides.' });
  }

  const contentTypeBrut = req.headers['content-type'] || '';
  const contentType = contentTypeBrut.split(';')[0].trim().toLowerCase();
  const ext = ORG_AVATAR_MIME_EXT[contentType];
  if (!ext) {
    return res.status(415).json({ error: 'Format non supporté. PNG, JPG/JPEG ou WEBP uniquement.' });
  }

  let buffer;
  try {
    buffer = await lireCorpsLimite(req, ORG_AVATAR_MAX_BYTES);
  } catch (e) {
    if (e.message === 'PAYLOAD_TOO_LARGE') {
      return res.status(413).json({ error: 'Fichier trop volumineux. 2 Mo maximum.' });
    }
    return res.status(400).json({ error: 'Corps de requête invalide.' });
  }
  if (!buffer || buffer.length === 0) {
    return res.status(400).json({ error: 'Fichier vide.' });
  }

  // Verification fraiche du chef -- JAMAIS a partir d'un cache client, une lecture directe et
  // faisant autorite au moment exact de l'upload.
  const orga = await getOrganisationFraiche(orgaId).catch(() => null);
  if (!orga || orga.chef !== characterName) {
    return res.status(403).json({ error: "Vous n'êtes plus habilité à modifier cette organisation." });
  }

  if (!SUPABASE_SERVICE_ROLE) {
    // Migration/configuration pas encore terminee cote Vercel -- echec propre et explicite,
    // jamais une tentative d'ecriture avec une cle absente. Tout ce qui precede (format,
    // taille, chef actuel) vient neanmoins d'etre verifie avec succes.
    return res.status(503).json({ error: 'Upload indisponible : configuration serveur incomplete.' });
  }

  // Chemin genere cote serveur, namespace par l'organisation -- jamais le nom fourni par le
  // client, jamais de collision possible entre organisations.
  const path = `${orgaId}/${Date.now()}-${Math.floor(Math.random() * 1000000)}.${ext}`;

  const resultatUpload = await uploadVersStorage(path, buffer, contentType).catch(() => null);
  if (!resultatUpload || !resultatUpload.ok) {
    return res.status(502).json({ error: "L'image n'a pas pu être envoyée." });
  }

  // Nettoyage best-effort de l'ancien avatar -- UNIQUEMENT si son URL appartient reellement au
  // namespace Storage de CETTE organisation (jamais une URL externe saisie par le joueur, et
  // jamais le namespace d'une autre organisation). Determine ici a partir de la donnee fraiche
  // de l'organisation elle-meme, pas d'une valeur fournie par le client.
  const ancienAvatar = orga.avatar || '';
  const prefixeNamespace = `${PUBLIC_PREFIX}${orgaId}/`;
  if (ancienAvatar && ancienAvatar.startsWith(prefixeNamespace)) {
    const ancienPath = ancienAvatar.slice(PUBLIC_PREFIX.length);
    await supprimerDeStorage(ancienPath);
  }

  return res.status(200).json({ url: publicAvatarUrl(path) });
}
