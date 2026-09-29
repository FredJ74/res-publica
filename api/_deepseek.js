// =====================
// FOURNISSEUR IA — UN SEUL ENDROIT QUI CONNAIT DEEPSEEK (29 septembre 2026)
// =====================
// Res Publica abandonne Anthropic comme fournisseur runtime. Plutot que de recopier
// l'URL, le modele et la lecture de la cle dans quatre fichiers, tout passe par ici.
// Le jour ou le fournisseur changera encore, il y aura UN fichier a toucher.
//
// LA CLE N'EST JAMAIS TRANSMISE AU NAVIGATEUR, jamais journalisee, jamais renvoyee
// dans une erreur. Les appelants ne recoivent qu'un verdict et un texte.
//
// CE MODULE NE DECIDE RIEN DU METIER : ni le prompt, ni les bornes, ni ce qu'on a le
// droit de demander. Ce sont ses appelants qui portent ces regles, chacun pour son
// domaine -- les profils PNJ pour la conversation, l'allowlist d'usages pour la
// redaction. Ici, on parle au fournisseur, et c'est tout.

const DEEPSEEK_URL     = 'https://api.deepseek.com/chat/completions';
const DEEPSEEK_MODELE  = 'deepseek-chat';

// FENETRE DE CONTEXTE. deepseek-chat accepte 64 000 tokens, la ou Claude en acceptait
// 200 000. C'est la seule difference de capacite qui compte pour nous, et elle est
// verifiee par les appelants qui envoient de gros paquets (le Journal). On la nomme
// ici pour qu'aucun appelant n'ait a la deviner.
const DEEPSEEK_FENETRE_TOKENS = 64000;

// Estimation volontairement prudente : 4 caracteres par token en francais, ce qui
// sous-estime le nombre de tokens plutot que l'inverse. Sert uniquement a refuser
// AVANT d'envoyer une requete dont on sait qu'elle sera rejetee.
const CARACTERES_PAR_TOKEN = 4;

function cleConfiguree() {
  return !!process.env.DEEPSEEK_API_KEY;
}

// Appel unique. `json: true` demande au fournisseur de ne produire qu'un objet JSON
// valide -- c'est le remplacant standard du prefill Anthropic (`{` en debut de reponse
// d'assistant), qui n'existe pas ici. Le fournisseur exige que le mot « json » figure
// dans le prompt : c'est a l'appelant de s'en assurer, et le Journal le fait deja.
async function appelDeepSeek({ systeme, messages, maxTokens, json, timeoutMs }) {
  if (!cleConfiguree()) return { ok: false, erreur: 'Fournisseur non configuré.' };

  const corps = {
    model: DEEPSEEK_MODELE,
    messages: [].concat(
      systeme ? [{ role: 'system', content: systeme }] : [],
      messages || []
    ),
    max_tokens: maxTokens,
    temperature: 0.7
  };
  if (json) corps.response_format = { type: 'json_object' };

  const controleur = new AbortController();
  const minuteur = timeoutMs ? setTimeout(() => controleur.abort(), timeoutMs) : null;
  try {
    const r = await fetch(DEEPSEEK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json',
                 'Authorization': 'Bearer ' + process.env.DEEPSEEK_API_KEY },
      body: JSON.stringify(corps),
      signal: controleur.signal
    });
    if (!r.ok) {
      // Le detail du fournisseur peut contenir des elements de configuration : il ne
      // sort jamais d'ici tel quel. Seul le code de statut est conserve, pour le
      // journal serveur.
      const detail = await r.text().catch(() => '');
      console.error('DeepSeek HTTP ' + r.status);
      return { ok: false, http: r.status,
               erreur: 'Fournisseur indisponible (HTTP ' + r.status + ')',
               detail: detail.slice(0, 300) };
    }
    const data = await r.json();
    const choix = data && data.choices && data.choices[0];
    const texte = choix && choix.message && choix.message.content;
    if (!texte || typeof texte !== 'string') {
      return { ok: false, erreur: 'Réponse vide du fournisseur.' };
    }
    // TRONCATURE REMONTEE. Le generateur d'evenements aleatoires ABANDONNE une
    // reponse coupee en plein milieu plutot que d'afficher une phrase amputee : il
    // lisait `stop_reason` chez l'ancien fournisseur. L'equivalent est
    // `finish_reason`, et il doit remonter jusqu'a lui, sinon ce filtre disparait
    // en silence a la migration.
    return { ok: true, texte: texte.trim(), tronque: choix.finish_reason === 'length' };
  } catch (e) {
    if (e && e.name === 'AbortError') {
      return { ok: false, erreur: 'Délai dépassé (' + timeoutMs + 'ms)' };
    }
    console.error('Erreur fournisseur IA');
    return { ok: false, erreur: 'Fournisseur indisponible.' };
  } finally {
    if (minuteur) clearTimeout(minuteur);
  }
}

// AUTHENTIFICATION REELLE, partagee par tous les endpoints IA. On ne croit pas le
// client sur parole : le jeton porte par l'en-tete Authorization est presente a
// Supabase, qui seul peut dire s'il est valide et a qui il appartient. Un jeton
// absent, expire ou forge echoue ici, AVANT le moindre appel paye.
async function joueurAuthentifie(req) {
  const brut = req.headers.authorization || req.headers.Authorization || '';
  const jeton = brut.startsWith('Bearer ') ? brut.slice(7).trim() : '';
  if (!jeton) return null;

  // Meme repli que tout le reste du dossier api/ : ces deux valeurs ne sont pas
  // configurees dans l'environnement Vercel, et n'ont rien de secret -- l'URL du
  // projet et la cle anon sont publiques et voyagent deja dans le bundle servi a
  // chaque navigateur.
  const url = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
  const anon = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';
  if (!url || !anon) return null;
  if (jeton === anon) return null;   // la cle anon n'est pas une identite de joueur

  try {
    const r = await fetch(url.replace(/\/$/, '') + '/auth/v1/user', {
      method: 'GET',
      headers: { 'apikey': anon, 'Authorization': 'Bearer ' + jeton }
    });
    if (!r.ok) return null;
    const u = await r.json();
    return (u && u.id) ? { id: u.id, jeton } : null;
  } catch (e) {
    return null;
  }
}

export {
  appelDeepSeek, joueurAuthentifie, cleConfiguree,
  DEEPSEEK_MODELE, DEEPSEEK_FENETRE_TOKENS, CARACTERES_PAR_TOKEN
};
