# Aide HRP multilingue — 11 novembre 2026

## Verdict

**Correctifs codés et poussés, validation locale partielle, livraison bloquée.**
Ne pas annoncer « conseiller multilingue validé ». Aucune réponse réelle DeepSeek,
recette connectée, fusion, CI distante ou Vercel READY certifiée.

Branche : `codex/aide-hrp-neuf-langues-20261111`. Main de départ et dernier main
observé : `6b9f5d30`. PR712 (`48682eb7`), correctif716 (`782eacd6`) et mobile717
conservés. Commits de code : `2f1027f9`, puis `90f01b38` (IME et tests complétés).
API GitHub refusant les lectures, l'état antérieur est vérifié dans Git et RELAIS.
Aucun chantier parallèle Aide signalé dans les références accessibles.

## Défauts et corrections

| Défaut constaté | Correction ciblée |
|---|---|
| Frontières ASCII `\b` empêchant de reconnaître des questions PA ko/ar/zh-TW sans sigle latin ; autres thèmes inégalement couverts | Racines de mots dans les neuf langues, normalisation NFKC pour la recherche seulement, même corpus canonique |
| Trois thèmes issus d'une ancienne réponse peuvent évincer la question actuelle | Question courante prioritaire, puis deux anciens messages utilisateur ; ne pas dépister les réponses du modèle ; limite trois inchangée |
| Consigne « langue du joueur si possible », long exemple français | Langue nommée et codée dans la consigne serveur obligatoire, sélecteur seul autoritaire malgré langue de question/historique/corpus ; chinois traditionnel Taïwan explicite |
| Double envoi possible avant retour d'authentification | Verrou avant toute attente, partagé par clic, suggestion et Entrée ; langue figée au déclenchement |
| Réponse affichée4000 retransmise à un serveur limité1500 | Contexte sortant six messages,1500 caractères chacun, affichage historique intact ; aucune limite serveur affaiblie |
| Erreur perdant un message au changement de langue ou écrasant un nouveau brouillon | Conservation des messages déjà affichés ; restauration seulement dans une saisie vide ; statut retraduit à chaud |
| Auth bloquée ou réponse tardive | Budget client30s, annulation et libération du verrou ; retour d'auth tardif ne lance pas de requête |
| Entrée de composition du clavier chinois/coréen soumettant prématurément | Garde isComposing/code229 dans le handler existant ; Entrée normale conservée |

PA et but libre : conserver le sens décidé par Fred, sans inventer de barème,
quête principale ou confidentialité technique absolue. Les noms des langues
ne sont pas des traductions générées ; les faits pédagogiques restent communs.
Aucune tentative de traduire un dialogue PNJ ou de modifier une action de jeu.

## Fichiers modifiés

- `api/_aide.js` : langue imposée, réponse blanche refusée.
- `api/_aide-themes.js` : dépistage et priorité du contexte.
- `plateau-aide.js` : envoi, statut, brouillon, historique transporté, direction
  automatique des bulles et clavier IME ; aucun calcul métier.
- `plateau.html` : version de cache du seul script Aide.
- Deux bancs neufs, neuf jeux de questions et deux témoins gzip du main6b9f5d30.
- `GAME-DESIGN-AIDE.md` : historique de fusion rectifié et comportement linguistique
  documenté ; `RELAIS.md`, ce rapport et preuves.

Aucun changement de `api/chat.js`, `_deepseek.js`, `vercel.json`, CSS, architecture
mobile, données Sovarka ou PNJ, règles, PA, argent, permissions ou inventaires.
Aucune migration. Toujours **12 fonctions Vercel** : `/api/aide` passe par
`/api/chat?mode=aide` puis `_aide.js`, jamais par une treizième fonction.

## Tests réellement exécutés

- **27/27 cas serveur** : neuf langues, neuf thèmes chacune, PA et but libre,
  question anglaise contredisant le sélecteur, historique français, auth avant IA,
  aucun accès au personnage, limites, fournisseur vide/blanc/tronqué/503/JSON
  invalide/AbortError et contre-épreuve de l'ancien dépistage.
- **13/13 premiers cas Chromium** dans une campagne complète : interface360/390
  dans neuf langues, Unicode et RTL, fr→en→ko→fr en cours d'auth/réponse,
  brouillons/messages conservés, contexte1500 sans tronquer l'affichage,
  erreurs, délai, PNG français1440 strictement identique.
- Trois compléments ont passé **séparément** : ancien double envoi reproduit puis
  empêché ; circuit complet UI→rewrite réel→chat→auth→DeepSeek sur18 questions
  (36 appels simulés, auth puis IA) ; clavier IME ko/zh-TW.
- Après ajout des erreurs/attentes aux neuf langues, campagne ciblée groupée :
  **51/52 cas réussis**, dernier cas IME en échec au lancement Chromium
  (`pthread_create: Resource temporarily unavailable`), alors qu'il avait passé
  isolément. Aucun résultat transformé en réussite.
- Rejeu séquentiel final tenté : **34 cas réussis, deux fichiers navigateur en
  échec de démarrage** ; même saturation de threads, jusque dans Node et le
  lancement sandbox de commandes. Il ne certifie pas les seize cas navigateur
  du code final. Journaux conservés.

Le code serveur, le routeur, le wrapper DeepSeek et le composant navigateur sont
réels dans les tests ; seuls les services auth/IA sont simulés. Aucune fixture ne
prouve la langue ou la pertinence d'une sortie réelle du modèle.

| Langue | Thèmes, PA/but et langue du prompt | UI360/390, Unicode | Réponse DeepSeek réelle |
|---|---|---|---|
| fr | testé | testé | non exécutée |
| en | testé | testé | non exécutée |
| es | testé | testé | non exécutée |
| zh-TW | testé, consigne traditionnel | testé | non exécutée |
| ru | testé | testé | non exécutée |
| ko | testé | testé | non exécutée |
| ar | testé | testé, RTL | non exécutée |
| pt-BR | testé | testé | non exécutée |
| de | testé | testé | non exécutée |

Contre-épreuves : les témoins publics sont identifiés par SHA256 dans les bancs.
Le script ancien rate les questions PA ko/ar/zh-TW ; le script actuel les détecte.
L'ancien client déclenche deux requêtes pendant auth ; l'actuel une seule.
Aucune assertion supprimée ou référence historique retouchée. Comparaison PNG
stricte par hash, animations de capture terminées pour comparer le rendu statique,
sans seuil de différence admis. Essais sur téléphones physiques non effectués.

## Contrôleur complet et anomalies hors lot

Première campagne exploratoire terminée pendant développement : **281/284 bancs**.
Échecs : nouveau banc Aide en cours de stabilisation, `banc-mobile-coque.cjs` et
`banc-pnj-localisation-psm.mjs`. Les deux derniers sont reproduits sur main intact
6b9f5d30 : comparaisons bureau historiques coque/forum ; scène PNJ générée en
écart. Pas de correction hors périmètre ni de falsification de témoins.

Le dernier rejeu du code stabilisé a été **interrompu à165/284,16 échecs**, dans
un environnement saturé : fork/pthread_create impossibles, Chromium bloqué.
Seuls les groupes des essais de cette mission ont été arrêtés pour libérer les
ressources. Ce résultat est conservé comme interrompu, jamais annoncé vert.
L'environnement reste incapable de lancer les bancs navigateur après arrêt,
même séquentiellement ; il faut les rejouer dans un runner disponible.

**Globaux :10/12**, sortie branche identique à main intact avec mêmes dépendances.
Workflow/Authority conformes. Baseline et Referential restent rouges : définitions
et seeds/observations anciens, empreintes ordres_couts/pa_bonus_differes/miroirs.
Détails bruts conservés, aucune empreinte ou observation modifiée.

## Livraison et blocages

Branche poussée ; création REST unique de PR brouillon **403 Forbidden**. Pas de
numéro de PR inventé. Titre prêt : **Aide HRP : langue imposée, thèmes multilingues
et conversation fiable**. Description : correctif ciblé neuf langues, corpus
canonique, verrou avant auth, contexte1500/6, conservation des brouillons et IME,
mêmes douze fonctions ; preuves locales, saturation finale et recette réelle
restante explicitement documentées ; aucune mutation PJ.

HEAD production11/11 : **CONNECT tunnel failed,403 envoy**. Restriction de
proxy, pas une preuve d'échec Vercel. Aucun déploiement déclenché. Lecture CI,
création PR et contrôle READY indisponibles ; pas de fusion tentée à l'aveugle.

Aucune clé DeepSeek ni session E2E autorisée présentes (vérification de présence
seulement, aucune valeur exposée). Pas de demande de mot de passe ou clé dans le
chat. Recette IA réelle et compte isolé à réaliser par l'intégration autorisée.
Les validations manquantes restent des conditions de livraison, pas des succès.

## Suite pour l'intégrateur

Créer la PR depuis la branche poussée, rejouer les commandes sur un runner sain,
réconcilier main si nécessaire, observer les CI, traiter les échecs hérités avant
promotion, puis seulement fusionner et vérifier Vercel READY sur le SHA fusionné.
Aucune intervention SQL, configuration de secrets ou transaction demandée à Fred.

Recette isolée restante dans chaque langue : les deux questions de la fixture ;
réponse effectivement dans la langue sélectionnée, PA/sommeil sans chiffres
inventés, but social ouvert et invitation finale naturelle. Question anglaise
avec sélecteur ko/ar/de : conserver la langue sélectionnée. Vérifier traditionnel
zh-TW, RTL arabe et qualité linguistique humaine. Fr→en→ko→fr avec brouillon et
réponse en cours : messages historiques inchangés, aucune requête doublée.
Tester aussi sur iPhone Safari et Android Chrome, clavier IME compris.

```sh
node --test --test-concurrency=1 outils/bancs/banc-aide-hrp.mjs outils/bancs/banc-aide-interface.cjs outils/bancs/banc-aide-multilingue.mjs outils/bancs/banc-aide-neuf-langues-navigateur.cjs outils/bancs/banc-vercel-douze-fonctions-20261111.cjs
python outils/bancs/controler-client.py --rapport /tmp/hg-aide-clients
python outils/baseline/controler-tout.py
```

Dépendances habituelles, Chromium et parseur SQL requis ; aucun service externe
ou secret nécessaire pour les bancs locaux. Les résultats exacts sont joints
sous `aide-hrp-neuf-langues-20261111/` avec manifeste SHA256.
