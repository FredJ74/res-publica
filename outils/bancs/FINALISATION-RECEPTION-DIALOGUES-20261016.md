# Réception atomique et dialogues PNJ — 16 octobre 2026

**CHANTIER NON TERMINÉ EN PRODUCTION.** Travail effectué depuis
`6b3705e6e26ca797efb3cda74201891a6ca09880`, sans accès Supabase/Vercel ni compte
joueur de test. Aucun changement de données réelles, aucune migration appliquée.
Correction serveur et banc : `99dc7cfa5012efe8e4f66143951cd90364f8447c`.

## Phase 1 — réception atomique

Lecture du workflow, du rapport de préparation, de la migration et de ses
préconditions. Cartographie des écrivains recalculée : **29 fonctions et
33 affectations d'inventaire dans les sources archivées**. Elle ne prouve pas
l'état du serveur vivant.

La migration reste exactement celle examinée précédemment :
`migrations/20261016131932_reception_objets_atomique.sql`, SHA-256
`188aa2dbaf27b1255d04e3c328ad0a57bfeff28b93b6e9b521847d44261686c2`.
Le baseline et la migration d'achat n'ont pas été modifiés ou rejoués.

**31 groupes de scénarios PostgreSQL jetables réussis à nouveau** : transaction,
rejeu, double réception concurrente, réutilisation d'identifiant, attente,
propriété, droits, sauvegarde périmée, rollback, formats JSON, dons de tracts,
documents, empilement et conservation des métadonnées. Les 20 tests client de
réception passent également dans la suite complète. Les helpers SQL archivés
sont exécutés ; `auth.uid()` et certains services restent des fixtures.
Cela ne constitue pas un parcours d'achat/don authentifié en production.

La compatibilité avec les fonctions, triggers, RLS, ACL, GUC PostgREST et tous les
écrivains **réellement déployés** reste à établir. La lecture prévue dans
`banc-reception-contrat-lecture.sql` n'a pas pu être exécutée. Aucun contournement
par SQL direct ou réactivation du DELETE client n'a été introduit.

**Risque opérationnel déjà documenté :** si le client de `main` est déployé avant
la migration, les livraisons restent en file et la réception est indisponible.
Ce comportement protège les objets, mais ne rend pas le service opérationnel.
L'état et le contenu actuels des inventaires/files distants n'ont pas été lus ;
leur conservation réelle avant/après migration n'est donc pas certifiée.

## Phase 2 — circuit de dialogue et diagnostic

1. `plateau-pnj.js` résout le profil, assure la session, prend le JWT et appelle
   `/api/chat` via `reponsePnjServeur`. Le message, la langue et six entrées
   d'historique bornées sont transmis ; aucun prompt client n'est accepté.
2. `api/chat.js` valide le payload et la liste des profils, puis
   `joueurAuthentifie` vérifie le JWT auprès de Supabase `/auth/v1/user`.
   Aucun fournisseur payant n'est appelé avant cette vérification.
3. Lectures parallèles sous ce JWT : relations, pédagogie, contexte public et
   mémoires spécialisées. Seuls maire/adjoint de Luthécia lisent les registres
   municipaux. Une panne de registre reste une fonction non vérifiée.
4. `_pnj-profils.js` assemble les personnalités, connaissances, limites et
   mémoires. `_deepseek.js` transmet le prompt et l'historique à
   `https://api.deepseek.com/chat/completions`, modèle `deepseek-chat`.
5. Succès : `{reponse}` affichée par le client. Échec serveur/réseau : message
   temporaire existant. Le client traite uniquement HTTP 400 comme refus durable.
   Les branches scénarisées du musée et des autres quêtes restent inchangées.

Comparaison du code récent : le dernier changement du handler avant cette mission
est `04317d6b` (15 octobre 22:16 UTC / 16 octobre 00:16 Paris), ajoutant la continuité
municipale. Ses lectures spécifiques ne sont émises que pour deux profils.
Les imports du handler chargé réellement par Node réussissent. Les profils du
centre artisanal et de Gérard Poinçon aboutissent au fournisseur dans les tests.
Ces constats locaux ne permettent pas d'exclure une panne de bundle Vercel ou de
service distant, ni d'attribuer la panne générale à ce commit.

### Défauts confirmés et correction ciblée

- Le fournisseur disposait de **30 secondes après des lectures sans borne**, alors
  que `vercel.json` borne **toute la requête à 30 secondes**. Authentification
  désormais bornée à 4 s ; lectures facultatives à 3 s ; toutes les lectures
  municipales partagent leur même borne de 3 s. Le délai IA est le reste d'un
  budget de 27 s commencé avant l'authentification. Marge pour rendre la réponse.
- Le handler renvoyait la même erreur publique pour clé absente, refus de clé,
  crédits épuisés, limitation, panne, timeout ou réponse vide. Il réutilise
  désormais `classerEchecFournisseur` pour un journal serveur structuré
  `[chat] {etape,cause,http}`. L'étape auth et les lectures sont également tracées.
  Aucun corps de réponse, clé, JWT, identité, question, souvenir ou prompt n'est
  journalisé par ces nouveaux diagnostics ni transmis dans l'erreur publique.
- `_deepseek.js` accepte des options facultatives pour l'authentification ; ses
  autres appelants conservent leur contrat. `_supabase.js` transmet le signal
  optionnel des seules lectures municipales concernées. Aucun droit modifié.

**La cause de la panne générale de production n'est pas identifiée.** Le défaut
de budget existait avant les modifications municipales ; sa correction ne prouve
pas qu'il explique la panne du 16 octobre. Aucun crédit épuisé, secret absent ou
incident fournisseur n'est affirmé sans observation distante. Aucun remplacement
par des conversations génériques, changement de personnalité ou retrait de
protection n'a été effectué.

## Accès réellement disponibles

- Git lecture/écriture vers le dépôt : disponible.
- Outils Supabase, application de migration enregistrée et journaux Vercel :
  absents de la liste des outils exposés.
- Configuration cloud lue : aucun secret déclaré, politique réseau limitée aux
  destinations prédéfinies de développement ; aucun accès aux secrets Vercel.
  Variables Supabase/DeepSeek/Vercel recherchées par nom seulement : aucune.
- Tentatives HTTP inoffensives vers le site, la santé Auth Supabase et la liste des
  modèles DeepSeek : **refus CONNECT 403 du proxy `envoy`**, avant les services.
  Ce n'est ni un HTTP 403 Supabase ni un HTTP 403 DeepSeek.

Aucun journal réel, registre de migrations, définition vivante ou réponse IA
réelle reçu. Aucun test authentifié Supabase, déploiement Vercel, résultat distant
GitHub Actions ou conversation réelle certifié.

## Vérifications de cette intervention

- **69/69 bancs JavaScript réussis**, dont 286 tests Node et les bancs historiques.
  Le nouveau `banc-chat-disponibilite.mjs` apporte **25 tests**, avec transport
  simulé : Sabri Coledur, Céd' Labone, Henrico Stot, Gérard Poinçon, Jérémy,
  vrais prompts inchangés, historique, erreurs IA/auth, confidentialité des traces,
  bornes et budget, dégradation des lectures facultatives et registre municipal.
- **31 groupes PostgreSQL locaux réussis**, uniquement sur serveur jetable.
- **90/90 contre-épreuves réussies**.
- Syntaxe Node : **85/85 fichiers racine/API** ; chargement ESM de `/api/chat`
  réussi ; `git diff --check` conforme ; garde Vercel 313,1 Mo / plafond 330 Mo.
- Le script de syntaxe JavaScriptCore n'est pas exécutable fidèlement dans cette
  machine Linux : JSC absent et adaptateur externe sans `arguments` global.
  Ce contrôle n'est pas annoncé vert ; la syntaxe est contrôlée avec Node natif.
- Workflow global : **9/12 verts, 3 rouges préexistants à cette intervention** :
  autorité (trois RPC de réception absentes du baseline car migration en attente,
  plus `tracts_electoraux_distribuer_collectif`), référentiels (rendus divergents,
  générateur 17/18 ressources) et fonctions (109 divergences de prix / 103 déclarées).
  Aucun résultat, empreinte ou seuil modifié pour les masquer. Le vert du contrôle
  de baseline prouve la cohérence de son export archivé, pas celle de la base vive.

## Suite nécessaire par les agents disposant des accès

1. Supabase : lire le catalogue et les droits avec la requête préparée, vérifier
   l'ordre des verrous et les GUC sur environnement authentifié isolé. Si compatible,
   empreintes métier avant/après, application MCP enregistrée, contrôle du registre
   et des données, réextraction réglementaire du baseline et seeds. Si un corps a
   changé, arrêter l'application et adapter la migration dans le dépôt.
2. Vercel : consulter le déploiement réellement servi et les journaux de `/api/chat`,
   contrôler la présence et validité de la configuration IA et Auth. Les nouveaux
   diagnostics distingueront les étapes après leur déploiement ; les anciens
   journaux peuvent déjà contenir le statut HTTP DeepSeek.
3. Effectuer les réceptions et conversations authentifiées avec comptes/fixtures
   autorisés, plusieurs PNJ, rechargement et deux onglets, sans joueurs réels.

Aucune manipulation SQL, de secrets ou de Git n'est confiée au game designer.
Les deux phases restent ouvertes jusqu'à ces preuves de production.
