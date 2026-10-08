/* ===========================================================================
   RES PUBLICA — api/_supabase.js
   LA COUCHE D'ACCES SUPABASE DES FONCTIONS SERVERLESS
   Chantier 5, 9 octobre 2026
   ===========================================================================

   POURQUOI CE MODULE EXISTE. Neuf fonctions de api/ portaient chacune leur propre
   configuration Supabase -- l'URL du projet et la cle anon recopiees neuf fois, mot pour
   mot -- et trois d'entre elles reimplementaient en plus leur propre transport REST. Ce
   n'etait pas une redondance inoffensive : les trois implementations ne rendaient PAS la
   meme chose, sous les MEMES NOMS.

       fonction      cron-minuit.js        journal-interview.js   _journal-generation.js
       --------      --------------        --------------------   ----------------------
       sbGet echec   null + journalise     []                     []
       sbInsert KO   null + journalise     {ok:false,status,...}  {ok:false,status,...}
       sbInsert OK   le corps JSON         {ok:true, rows}        {ok:true}  (sans rows)

   Autrement dit : `sbGet` ne veut pas dire la meme chose selon le fichier ou on le lit, et
   dans deux fichiers sur trois, une PANNE DE LECTURE rend `[]` -- donc « il n'y a rien ».
   C'est exactement le defaut que le chantier 5 a corrige cote navigateur le 7 octobre 2026,
   apres que le forum ait affiche « Aucun sujet » pendant une indisponibilite de Supabase.

   UNE DIVERGENCE REELLE A ETE TROUVEE AU PASSAGE. api/cron-assemblee.js codait l'URL et la
   cle EN DUR, sans le repli `process.env.SUPABASE_URL ||` que portent les huit autres. Le
   jour ou le projet change d'URL, huit fichiers suivent la variable d'environnement et le
   neuvieme continue de parler a l'ancien.

   CE QUE CE MODULE FAIT, ET CE QU'IL NE FAIT PAS ENCORE. Il porte la configuration, les
   en-tetes, et un transport qui nomme les etats comme le navigateur les nomme. La migration
   des transports locaux se fait fichier par fichier, en commencant par ceux ou une
   confusion ne coute rien, JAMAIS en une fois : cron-minuit.js tourne chaque nuit sur de
   l'argent reel et ne se refactorise pas a l'aveugle.

   LE VOCABULAIRE DES ETATS EST CELUI DE supabase.js, deliberement. Il ne doit pas y avoir
   deux facons de nommer une panne selon qu'on est dans le navigateur ou dans une fonction
   serverless -- c'est la meme base, les memes modes de defaillance, et souvent le meme
   mecanisme de jeu de part et d'autre.

     'ok'             -> 2xx ; `donnees` porte le corps analyse. Un tableau VIDE est alors un
                         vide REEL, recu avec succes : c'est tout l'interet de l'etat.
     'session_perdue' -> 401 : identite refusee ou expiree.
     'http'           -> le serveur a repondu autre chose qu'un 2xx.
     'reseau'         -> `fetch` a rejete : DNS, TLS, coupure, requete bloquee.

   `envoyee` dit si la requete a quitte le processus. C'est la seule donnee qui permette
   d'affirmer qu'une ecriture n'a PAS pu partir -- jamais qu'elle a echoue sans effet.
   =========================================================================== */

// LA CONFIGURATION, UNE SEULE FOIS. Les replis litteraux sont ceux que portaient deja les
// huit fichiers conformes : l'URL du projet et la cle ANON, qui est publique par
// construction -- elle part dans chaque navigateur, elle n'a jamais ete un secret. La cle
// SERVICE_ROLE, elle, n'a AUCUN repli litteral et n'en aura jamais : absente, les chemins
// qui l'exigent doivent echouer bruyamment plutot que retomber sur une identite anonyme.
export const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jxpwoosmmhohoihxpbuc.supabase.co';
export const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4cHdvb3NtbWhvaG9paHhwYnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjYyMDgsImV4cCI6MjA5NjYwMjIwOH0._NQsIrCS0U7czXAOIoNxs6omqj7whAq9FB572c4qflw';
export const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || null;

// TROIS IDENTITES, ET IL NE FAUT PAS LES CONFONDRE.
//
//   anon    : ce que voit un visiteur. Les policies RLS s'appliquent. C'est le defaut, et
//             c'est voulu -- une tache serveur qui n'a pas besoin de privileges n'en prend pas.
//   jeton   : L'IDENTITE DU JOUEUR, via `options.jeton`. `apikey` reste la cle anon, qui
//             identifie le PROJET et que Supabase exige sur chaque appel ; c'est
//             `Authorization` qui porte le jeton de session, et c'est lui qui alimente
//             auth.uid() cote Postgres -- donc toutes les policies RLS. Une fonction qui
//             agit POUR un joueur doit parler avec SON identite, jamais avec la cle anon
//             partagee ni avec la cle serveur : sinon la RLS ne protege plus personne.
//   service : contourne la RLS. Reservee aux taches qui AGISSENT au nom du monde (le cron de
//             minuit, les attestations). `est_appel_serveur()` la reconnait cote SQL.
//
// SI LA CLE SERVICE EST ABSENTE, `sbEnTetes({ service: true })` LEVE. Elle ne retombe pas sur
// anon : un cron qui croirait tourner en identite serveur alors qu'il parle en visiteur
// verrait ses ecritures refusees par la RLS une par une, en silence, et conclurait que le
// monde est vide. Mieux vaut une exception au premier appel.
//
// ET `service` ET `jeton` ENSEMBLE EST UNE ERREUR, pas une preference a arbitrer : ce serait
// demander a la fois de contourner la RLS et d'etre soumis a celle d'un joueur precis. On leve.
export function sbEnTetes(options) {
  const o = options || {};
  const service = !!o.service;
  if (service && o.jeton) {
    throw new Error('sbEnTetes : service et jeton sont exclusifs -- choisir une seule identite');
  }
  if (service && !SUPABASE_SERVICE_ROLE) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY absente : identite serveur impossible');
  }
  if (o.jeton) {
    return { 'Content-Type': 'application/json', 'apikey': SUPABASE_ANON,
             'Authorization': 'Bearer ' + o.jeton };
  }
  const cle = service ? SUPABASE_SERVICE_ROLE : SUPABASE_ANON;
  return { 'Content-Type': 'application/json', 'apikey': cle, 'Authorization': 'Bearer ' + cle };
}

// La cle service est-elle disponible ? A demander AVANT d'entamer une tache qui l'exige,
// pour pouvoir renoncer proprement plutot que lever au milieu d'un traitement.
export function identiteServeurDisponible() {
  return !!SUPABASE_SERVICE_ROLE;
}

// ---------------------------------------------------------------------------
// LE TRANSPORT
// ---------------------------------------------------------------------------

function analyserCode(texte) {
  try { return (JSON.parse(texte) || {}).code || null; } catch (e) { return null; }
}

async function envoyer(url, init, quoi) {
  let res;
  try {
    res = await fetch(url, init);
  } catch (e) {
    // `fetch` a rejete : la requete est peut-etre partie sans reponse exploitable. On ne peut
    // PAS affirmer qu'elle n'a rien fait -- d'ou envoyee: true.
    return { etat: 'reseau', raison: 'reseau_indisponible', http: null, code: null,
             message: (e && e.message) || null, envoyee: true, donnees: null, quoi };
  }
  if (!res.ok) {
    const texte = await res.text().catch(() => '');
    const code = analyserCode(texte);
    if (res.status === 401) {
      return { etat: 'session_perdue', raison: 'session_perdue', http: 401, code,
               message: texte, envoyee: true, donnees: null, quoi };
    }
    return { etat: 'http', raison: 'transport_indisponible', http: res.status, code,
             message: texte, envoyee: true, donnees: null, quoi };
  }
  if (res.status === 204) {
    return { etat: 'ok', donnees: true, http: res.status, code: null, envoyee: true, quoi };
  }
  let donnees = null;
  try { donnees = await res.json(); } catch (e) { donnees = true; }
  return { etat: 'ok', donnees, http: res.status, code: null, envoyee: true, quoi };
}

// ACCES REST. `options.service` choisit l'identite ; `options.prefer` complete l'en-tete
// Prefer (par exemple 'resolution=merge-duplicates' pour un upsert).
export async function sbTransport(methode, table, filtres, corps, options) {
  const o = options || {};
  const url = `${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/${table}` + (filtres ? `?${filtres}` : '');
  const prefer = o.prefer ? `return=representation,${o.prefer}` : 'return=representation';
  const init = { method: methode, headers: { ...sbEnTetes(o), 'Prefer': prefer } };
  if (corps !== undefined) init.body = JSON.stringify(corps);
  return envoyer(url, init, methode + ' ' + table);
}

// APPEL DE RPC. C'est la porte des operations transactionnelles : une RPC decide et ecrit
// dans la MEME transaction, la ou une suite de PATCH laisserait une fenetre.
export async function sbTransportRpc(fn, params, options) {
  const o = options || {};
  const url = `${SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/${fn}`;
  const init = {
    method: 'POST',
    headers: { ...sbEnTetes(o), 'Prefer': 'return=representation' },
    body: JSON.stringify(params || {})
  };
  return envoyer(url, init, 'rpc ' + fn);
}

// ---------------------------------------------------------------------------
// LES VERDICTS : LA FORME QUE DOIT PRENDRE TOUT CHEMIN SENSIBLE
// ---------------------------------------------------------------------------
// Meme forme que sbVerdictRest / sbRpcVerdict cote navigateur : { ok: true, donnees } sur
// un succes, { ok: false, raison, transport } sinon. Un appelant qui lit `r.ok` ne peut plus
// confondre une panne avec un vide, ni declarer reussie une ecriture qui n'est jamais partie.
export function sbVerdict(env) {
  if (env.etat === 'ok') return { ok: true, donnees: env.donnees };
  return {
    ok: false, raison: env.raison,
    transport: { etat: env.etat, http: env.http || null, code: env.code || null,
                 envoyee: !!env.envoyee, quoi: env.quoi || null }
  };
}

export async function sbGetVerdict(table, filtres, options) {
  return sbVerdict(await sbTransport('GET', table, filtres || '', undefined, options));
}
export async function sbInsertVerdict(table, data, options) {
  return sbVerdict(await sbTransport('POST', table, '', data, options));
}
export async function sbUpdateVerdict(table, filtres, data, options) {
  return sbVerdict(await sbTransport('PATCH', table, filtres, data, options));
}
export async function sbDeleteVerdict(table, filtres, options) {
  return sbVerdict(await sbTransport('DELETE', table, filtres, undefined, options));
}
export async function sbRpcVerdict(fn, params, options) {
  return sbVerdict(await sbTransportRpc(fn, params, options));
}

// ECRITURE IDEMPOTENTE D'UNE LIGNE ENTIERE. Meme doctrine que sbUpsert cote navigateur :
// PostgREST sait faire ON CONFLICT DO UPDATE via `resolution=merge-duplicates`, a condition
// que la cle primaire figure dans le corps. C'est ce qui supprime le motif « lire pour savoir
// s'il faut INSERT ou UPDATE » -- dont la lecture, en echouant, faisait prendre la branche
// INSERT sur une ligne existante.
export async function sbUpsertVerdict(table, ligne, options) {
  const o = { ...(options || {}) };
  o.prefer = o.prefer ? o.prefer + ',resolution=merge-duplicates' : 'resolution=merge-duplicates';
  return sbVerdict(await sbTransport('POST', table, '', ligne, o));
}

// ---------------------------------------------------------------------------
// ADAPTATEURS LEGACY, ET UN SEUL CONTRAT
// ---------------------------------------------------------------------------
// LE CONTRAT HISTORIQUE DU NAVIGATEUR, et lui seul : 2xx -> corps analyse, toute erreur ->
// `null`. Il est fourni pour que la migration d'un fichier serverless se fasse sans toucher
// a ses appelants, PAS pour etre le contrat d'arrivee. Les trois contrats divergents de api/
// ne sont volontairement PAS reproduits ici : les reproduire aurait fige la divergence qu'on
// vient de constater, et c'est l'inverse du but.
//
// `onEchec` preserve ce que cron-minuit.js fait deja de mieux que les autres : journaliser
// l'echec AVANT de l'aplatir. Un echec aplati sans trace est un echec perdu.
export async function sbGet(table, filtres, options) {
  const env = await sbTransport('GET', table, filtres || '', undefined, options);
  if (env.etat !== 'ok' && options && options.onEchec) options.onEchec(env);
  return env.etat === 'ok' ? env.donnees : null;
}
export async function sbInsert(table, data, options) {
  const env = await sbTransport('POST', table, '', data, options);
  if (env.etat !== 'ok' && options && options.onEchec) options.onEchec(env);
  return env.etat === 'ok' ? env.donnees : null;
}
export async function sbUpdate(table, filtres, data, options) {
  const env = await sbTransport('PATCH', table, filtres, data, options);
  if (env.etat !== 'ok' && options && options.onEchec) options.onEchec(env);
  return env.etat === 'ok' ? env.donnees : null;
}
export async function sbDelete(table, filtres, options) {
  const env = await sbTransport('DELETE', table, filtres, undefined, options);
  if (env.etat !== 'ok' && options && options.onEchec) options.onEchec(env);
  return env.etat === 'ok' ? true : null;
}
export async function sbRpc(fn, params, options) {
  const env = await sbTransportRpc(fn, params, options);
  if (env.etat !== 'ok' && options && options.onEchec) options.onEchec(env);
  return env.etat === 'ok' ? env.donnees : null;
}
