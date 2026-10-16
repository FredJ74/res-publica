# Dialogues PNJ : correction du chargement Vercel, 16 octobre 2026

**Cause confirmée par les journaux fournis et reproduite dans un vrai bundle.**
Départ : `6c632e51215d61adfa7cafbfa5c34e038a32b59a`.
Aucune clé, donnée Supabase, migration ou donnée d'inventaire modifiée.

## Cause et correction

Le dépôt n'a pas de `package.json` racine déclarant `type: module`.
Le constructeur `@vercel/node` compile ses modules `.js` ESM en CommonJS mais
exclut les `.mjs` de cette transformation. L'import statique ajouté dans
`api/chat.js` devenait donc `require('../continuite-municipale.mjs')`, tandis que
la cible restait ESM. Le runtime de production refusait ce `require()` avant
l'entrée dans le handler : tous les profils partageant `/api/chat` échouaient,
pas seulement les deux profils municipaux. Les délais et diagnostics du chantier
précédent ne pouvaient pas intercepter une erreur antérieure au chargement.

- `continuite-municipale.js` reçoit **sans changement d'octets** l'implémentation
  municipale auparavant dans le `.mjs` (SHA-256 des deux sources identiques :
  `8dd5960b7199c4f69c9ef6b2c7d987fe1cf3caf93dc63dadbbd8431f073734ad`).
- `api/chat.js` importe maintenant ce `.js`, compilable comme ses autres dépendances.
- `continuite-municipale.mjs` conserve son URL et ses trois exports nommés pour
  les navigateurs et les imports existants, en réexportant le même `.js`.
  Pas de logique dupliquée, de changement des lectures sous JWT, des titulaires,
  personnalités, souvenirs ou restrictions de pouvoir.
- Aucun changement global de système de modules, de configuration de fonction ou
  de contrôles de sécurité. Les fonctions municipales restent disponibles.

## Tests du conditionnement réel

`outils/bancs/banc-vercel-bundle.cjs` utilise le constructeur `@vercel/node@5.3.25`
avec verrou npm dans `outils/vercel/`, exclu du payload. Les fichiers produits sont
chargés dans un processus distinct avec les extensions `require(ESM)` et détection
ESM automatique désactivées ; un import natif sous Node 24 seul aurait masqué la panne.
La version du constructeur/runtime réellement déployée n'a pas été lue à distance.

**12/12 tests réussis :**

1. Ancien import reconstruit : compilation réelle puis refus **ERR_REQUIRE_ESM**,
   même mécanisme et même dépendance que dans les journaux Vercel.
2. Import corrigé : module municipal réellement compilé CommonJS, aucune dépendance
   `.mjs` dans la Lambda, chargement et dix conversations simulées : trois PNJ du
   centre artisanal, Gérard Poinçon, maire et adjoint chacun PNJ → PJ → vacance.
   Historique conservé, rôles de secrétaire et absence de pouvoirs vérifiés ;
   méthode GET refusée 405 et requête anonyme refusée 401 avant appel IA.
3. Les dix autres entrées API : graphes réellement compilés et chargés CommonJS,
   aucune autre dépendance `.mjs` native susceptible du même refus.

La CI installe ces dépendances par `npm ci` avant tous les bancs JavaScript.
Installation avec verrou rejouée localement. Les appels Auth, Supabase et DeepSeek
restent simulés et toute requête non prévue est refusée dans le processus de test.

## Non-régression

- **70/70 bancs JavaScript réussis**, dont disponibilité des dialogues,
  continuité municipale, rechargement, quêtes et nouveau conditionnement Vercel.
- **90/90 contre-épreuves réussies**.
- Syntaxe Node : **86/86 fichiers** ; `git diff --check` conforme ; payload
  Vercel **313,1 Mo / 330 Mo**, outillage npm exclu.
- Workflow global : **9/12 verts** ; les trois rouges restent ceux constatés avant
  cette correction : autorité (RPC de réception en attente et tractage collectif),
  référentiels divergents et prix Journal 109 cas contre 103 déclarés. Aucun seuil
  ni résultat modifié pour les masquer. Aucun chantier de baseline rouvert.
- Le chemin navigateur `.mjs` est exécuté dans les bancs de continuité via les
  modules ESM. Une tentative Chromium HTTP locale n'a pas fourni de DOM exploitable
  dans ce conteneur : elle n'est pas présentée comme un parcours navigateur réussi.

Les fichiers de tests, fixtures, manifeste/verrou et README sont dans `outils/` ;
la CI est dans `.github/workflows/coherence-client.yml`. Aucun fichier technique
ajouté au runtime hormis le `.js` municipal canonique.

## Limite de la vérification de production

Le push sur `main` déclenche le circuit habituel de déploiement ; il ne prouve pas
que Vercel a fini ou sert ce commit. Aucun connecteur Vercel/journaux ni compte de
test authentifié n'est disponible dans cette session. Le proxy réseau refuse
l'accès HTTP au site. Le chargement distant et les conversations IA réelles après
déploiement restent donc à observer par l'agent disposant de ces accès.
Aucune réponse générique n'a été ajoutée pour masquer l'erreur.
