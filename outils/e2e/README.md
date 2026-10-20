# Parcours joueur automatisé — Luthécia

Cet outil pilote l'interface du jeu dans Chromium, au rythme d'un joueur. Il ne crée aucun compte, ne revendique aucun personnage, n'injecte pas d'état et n'appelle aucun moteur d'écriture directement. **Sans compte explicitement autorisé, il s'arrête avant de charger la page de connexion.** Arnie constitue une autorisation historique distincte : exclusivement `consultation_seule`, après audit réel de son compte existant. Les tests du pilote sur fixtures ne sont pas des tests authentifiés du jeu.

## Exécution et limites

```bash
npm ci --prefix outils/e2e --ignore-scripts --no-audit --no-fund
npm test --prefix outils/e2e
npm run prevol --prefix outils/e2e
npm run campagne --prefix outils/e2e
```

Node 24 et Chromium système sont requis ; `HG_CHROMIUM` permet de préciser le binaire. Le pilote Playwright est verrouillé dans `package-lock.json`, sans téléchargement d'un second navigateur. Le lancement et le nettoyage réutilisent `outils/bancs/fixtures/chromium-cdp.cjs`. Les tests n'ignorent pas un Chromium absent.

Le prévol vérifie la présence des autorisations, identités et secrets attendus ainsi que l'accès HTTPS ; il ne valide pas les mots de passe, les ressources, les migrations ni le déploiement. Une campagne partielle, bloquée, interrompue ou avec anomalies rend un code non nul. `PARCOURS_AUTHENTIFIE_REUSSI` exige que tous les cas requis aient des preuves dans le rapport. Ne jamais traiter l'absence d'un scénario comme sa réussite.

Le parcours livré vise l'office notarial (accueil, successions, contrats, archives), les quatre consultations d'ordres sans engagement, un dialogue PNJ via `/api/chat`, la sortie, puis l'hôtel (accueil, bar, restaurant), les cartes et fiches, le rechargement et la sortie. Il emprunte les flèches, zones et onglets affichés, sans appeler les fonctions de déplacement depuis l'automate. Le graphe existant est seulement lu pour choisir un chemin à Luthécia ; aucune autre ville n'est visitée ou réinterprétée.

Après chaque déplacement, le pilote attend la pièce et sa confirmation dans l'état serveur du personnage, au maximum 30 secondes. Les images `<img>` doivent être chargées ; les images CSS et le cadrage ne sont pas intégralement validés par ce contrôle. Les lectures de contrôle emploient `sbGet` existant sur la vue `personnages` avec identité exacte et sur les seules entreprises de test explicitement autorisées. Les déplacements dans la rue et sorties sont confirmés via la RPC de lecture existante `rue_position_lire` (pays, ville, bâtiment nul et nœud exact), sans supposer que le bâtiment de la vue legacy vaut `rue-centrale`. Ces lectures ne remplacent pas les actions par des RPC d’écriture. Une divergence de liquide/PA/Santé/Moral interrompt le parcours.

Les prix des cartes sont lus par article, notamment champagne/cocktail 25 FR et repas gastronomiques 125 FR. Les stocks et l'état du bouton de production sont relevés ; **voir un bouton grisé ne prouve pas les permissions serveur**. L'achat, la fabrication, les invitations/réponses, les effets, la réception et les refus sensibles nécessitent des scénarios autorisés supplémentaires ; ils ne sont pas exécutés par défaut.

## Configuration réservée à un opérateur technique autorisé

Aucune valeur secrète ne doit être placée dans le dépôt, les arguments CLI ou le chat. Les comptes personnels sont interdits en `tests_isoles`. Seul Arnie bénéficie de l'autorisation explicite de consultation décrite ci-dessous ; aucune autre identité du propriétaire ou de sa famille n'en hérite. Le game designer n'a pas à exécuter ces commandes ni à provisionner des ressources par SQL.

| Variable | Usage |
| --- | --- |
| `HG_E2E_MODE` | `tests_isoles` pour les comptes réservés, ou `consultation_seule` exclusivement pour Arnie |
| `HG_E2E_BASE_URL` | Origine HTTPS exacte du déploiement autorisé, par exemple `https://res-publica.vercel.app/` |
| `HG_E2E_EMAIL`, `HG_E2E_PASSWORD` | Compte réservé aux tests, authentification normale par formulaire |
| `HG_E2E_PERSONNAGE`, `HG_E2E_UID` | Identité autorisée attendue, confrontée à la session et à la lecture serveur |
| `HG_E2E_INVITE_EMAIL`, `HG_E2E_INVITE_PASSWORD`, `HG_E2E_INVITE_PERSONNAGE`, `HG_E2E_INVITE_UID` | Second compte distinct, si le scénario exige un invité PJ |
| `HG_E2E_AUTORISATION_JSON` | Autorisation explicite ci-dessous, indépendante de la simple présence d'un mot de passe |
| `HG_E2E_PLAN_JSON` | Scénarios sensibles déterministes examinés et autorisés ; absent = aucune transaction de test |
| `HG_E2E_MAX_MINUTES` | 1 à 40 minutes ; 30 par défaut |
| `HG_E2E_RAPPORT` | Répertoire local privé des résultats, hors dépôt |
| `HG_E2E_REPRISE_DOSSIER` | Ancien rapport pour reprise prudente : un plan sensible est refusé si des actes antérieurs existent ou sont incertains |

Structure d'autorisation, à compléter uniquement à partir de comptes et de ressources réellement réservés aux tests :

```json
{
  "autoriseParResponsable": true,
  "comptesReservesAuxTests": true,
  "origine": "https://res-publica.vercel.app",
  "backend": "https://jxpwoosmmhohoihxpbuc.supabase.co",
  "comptes": [{"personnage": "IDENTITE_TEST_VERIFIEE", "uid": "UID_TEST_VERIFIE"}],
  "economieIsolee": false,
  "entreprises": [],
  "scenarios": []
}
```

Ces déclarations ne sont pas une preuve de réservation des comptes : l'opérateur doit la vérifier avant configuration. Le pilote contrôle la correspondance des identités, l'origine et le backend réel. Il ne peut pas créer ni certifier tout seul un environnement économique isolé. Sans réservation démontrée des stocks, caisse, fiscalité et contreparties des tests, ne pas autoriser les transactions, même avec un personnage « test ».

### Plans sensibles : raccordement prévu, aucun scénario réel préautorisé

Le plan contient des étapes `saisie`, `clic` ou `recharger`, chacune liée à un scénario parmi `achat`, `production`, `offrir-a-boire`, `diner`, `reception`. Chaque clic exige aussi un texte UI de résultat nouveau, attendu avant et après sa réponse ; aucun ancien toast ne suffit. Chaque étape précise `acteur` (`principal` ou `invite`) et `attendu.delta`, au minimum les variations de liquide et PA pertinentes. Les assertions possibles sont `stocks` (deltas par entreprise et recette), `inventaireChange`, `uiTexte` et `rpc` (verdict explicite, par exemple `ok`, `rejeu`, `raison`, `total`, `repas`, `champagnes`). Un clic normal exige son opération `rpc`, le verdict attendu et l'empreinte du handler DOM exact. Cette empreinte est SHA-256 de `JSON.stringify(attributOnclick)`, pas d'un extrait réinventé.

Exemple de forme, **non exécutable tel quel** :

```json
[{
  "type":"clic", "acteur":"principal", "scenario":"achat", "cas":"achat/succes",
  "selecteur":"SELECTEUR_UNIQUE_OBSERVE_DANS_LA_CARTE",
  "handlerSHA256":"EMPREINTE_DU_HANDLER_OBSERVE",
  "rpc":"acheter_produit_commerce",
  "attendu":{"delta":{"liquide":-25,"pa":0},"rpc":{"ok":true},"inventaireChange":true,"uiTexte":"MESSAGE_REEL_ATTENDU"}
}]
```

Il faut vérifier les contrats réellement installés et adapter les oracles : un achat avec livraison différée ne doit pas être déclaré réussi à tort parce que l'inventaire a changé. Le générateur de plans, les ressources des deux convives et les reçus installés restent à vérifier sur l'environnement autorisé. Aucun tarif ou effet du jeu n'est déduit de cet exemple.

`doubleClic: true` exerce deux événements de clic rapprochés sur le bouton. `panne: "perdre-reponse"` ou `"retarder-reponse"` intercepte uniquement l'opération RPC explicitement ciblée, sur le backend autorisé : **une seule exécution serveur**, puis perte ou délai de huit secondes. Aucune écriture n'est rejouée automatiquement. Après réponse perdue, la variation serveur et le message UI attendu doivent être contrôlés ; la reprise doit relire le reçu existant, pas fabriquer un nouvel acte. Le pilote ne recharge pas spontanément une session pour « réparer » un refus.

Les cas requis sont déclarés dans `CAS_REQUIS` : achat réussi/rupture/fonds insuffisants/rechargement, production permise/refusée, tournée acceptée/refusée/gains non cumulables/double réponse, dîner 2+2/refus/stock insuffisant/rejeu, réception simple/double/réponse perdue et réponse tardive de session. **Cette liste constitue une couverture attendue, pas des scénarios tous préimplémentés et vérifiés en production.** Un plan doit être construit à partir de l'interface et des ressources de test réellement disponibles. Tant qu'il manque des preuves, le résultat reste partiel.

## Rythme, persistance et arrêt

Chaque action attend deux à cinq secondes ; chaque déplacement deux à quatre secondes. Les attentes de chargement et de confirmation s'ajoutent à ces pauses. Une action suivante exige encore l'identité autorisée. Les deux comptes utilisent des contextes indépendants.

Le workflow `.github/workflows/beta-testeur-luthecia.yml` utilise l'environnement GitHub `luthecia-e2e`, les secrets ci-dessus et les variables de dépôt/environnement adaptées. Il peut être lancé manuellement sur `main`. Le planning est **inactif par défaut** ; seul `HG_E2E_NIGHTLY=true` autorise les passages planifiés. Une campagne ne peut pas annuler une autre campagne utilisant les mêmes comptes ; la concurrence est sérialisée. Limites : 35 minutes de pilote, 45 minutes de job, artefacts conservés trois jours. Ce workflow n'exécute ni migration ni déploiement.

Configurer l'environnement et ses protections reste une opération d'administration qui nécessite un accès approprié. La présence du fichier YAML dans Git ne prouve ni la disponibilité des secrets, ni un lancement, ni un hébergement actif après la session Codex. GitHub peut également retarder une exécution planifiée.

Les actions sensibles sont journalisées comme en cours **avant** le clic. Après interruption, conserver le rapport et réconcilier les reçus avant toute reprise sensible. Le parcours de consultation peut repartir depuis la position confirmée ; les actes incertains ne sont pas rejoués automatiquement. Une reprise sur un nouveau runner doit récupérer le rapport précédent ; ce mécanisme ne remplace pas l'idempotence des moteurs métier existants.

Les signaux d'arrêt, délais et erreurs ferment les contextes puis Chromium et suppriment le profil temporaire. Aucun stockage de session, HAR, vidéo ou trace Playwright n'est exporté : ils pourraient contenir des secrets. Les journaux conservent opérations, statuts HTTP, catégories et empreintes d'erreurs, jamais les en-têtes, corps de requêtes, mots de passe, jetons ou dialogues intégraux. Les captures n'interviennent qu'après vérification d'identité, sur échec. Les artefacts doivent rester dans le dépôt privé et l'environnement de test autorisé.


## Arnie : consultation seule du personnage historique

L'autorisation porte uniquement sur **Arnie**, avec son UID **lu et vérifié dans Supabase**, jamais un UID inventé ou celui d'un autre compte. L'absence de saisie de mot de passe à l'ouverture du jeu ne démontre pas que le compte soit anonyme : une session classique peut aussi être conservée et renouvelée.

Le prévol `outils/bancs/prevol-arnie.sql` est une transaction de **lecture seule**, destinée à un canal technique autorisé qui peut lire `auth.users`. Il recherche exactement `name='Arnie'`, refuse ambiguïté/UID nul/compte absent, rejoint `auth.users` par cet UID et indique : anonymat, adresse présente/confirmée/en attente, mot de passe présent (booléen seulement), fournisseurs d'identité, nombre de personnages du compte, position et empreinte protégée de la fiche. Il ne sort aucun jeton, hash de mot de passe ou adresse brute. Il extrait aussi les vrais déclencheurs et fonctions à examiner avant toute conversion ou navigation. Une lecture de catalogue n'est pas à elle seule une preuve d'absence d'effets.

### Accès indépendant et sécurisation

`auth.js` prévoit déjà `rpAuthSecuriserCompte` : `PUT /auth/v1/user` pour le compte actuellement connecté, avec e-mail et mot de passe, sans paramètre d'UID ni transfert. La réponse est contrôlée par rapport à l'UID précédent. `rpAuthEtatCompte` lit l'état GoTrue pour distinguer attente et confirmation. Les tests de ce dépôt couvrent ces fonctions réelles sur réponses **fictives**, pas sur le compte d'Arnie.

Si l'audit vivant révèle un compte anonyme, le pilote ne peut pas le transférer et ne doit pas récupérer les jetons du navigateur personnel. Après vérification technique du même compte et des déclencheurs, l'éventuelle action personnelle minimale est l'interface existante **Mon personnage → Identité → Sécurité du compte → Sécuriser mon personnage**, puis le lien de confirmation si demandé. Aucune consigne de sécurisation effective n'est donnée tant que le type réel du compte est inconnu. Ne pas réinitialiser le compte, en créer un autre ou appeler `rattacher_personnage` pour contourner le problème.

Une fois un accès indépendant classique confirmé, le pilote garde la connexion normale par formulaire. Il ne change jamais l'authentification. La réponse GoTrue doit être celle du même UID confirmé, puis `mon_personnage` doit répondre exactement Arnie ; sinon la réponse est refusée avant exposition à l'application. Il n'existe aucun personnage de remplacement par défaut.

### Secrets distincts, aucune campagne récurrente

Le lancement manuel du workflow propose par défaut `consultation_seule`, y compris en l'absence d'un choix explicite. Le nom est alors fixé à `Arnie` et le job utilise exclusivement ces secrets de l'environnement protégé `luthecia-e2e` :

- `HG_E2E_ARNIE_EMAIL`
- `HG_E2E_ARNIE_PASSWORD`
- `HG_E2E_ARNIE_UID`
- `HG_E2E_ARNIE_AUTORISATION_JSON`

Un secret manquant ne retombe jamais sur les valeurs d'un compte de test. Ces secrets restent séparés des comptes isolés et du planning antérieur. Le mode consultation interdit le déclenchement `schedule` ; le mode isolé refuse Arnie. **La présente autorisation ne permet pas d'activer une campagne nocturne récurrente sur Arnie.**

L'autorisation privée doit avoir `mode: "consultation_seule"`, `personnageHistoriqueAutorise: "Arnie"`, `autoriseParResponsable: true`, l'origine/backend exacts et `comptes` contenant seulement la paire nom/UID auditée. Elle porte aussi `auditArnie` avec :

- `personnage: "Arnie"`, `uid` exact et `nombrePersonnagesDuCompte: 1` ; un compte partagé entre plusieurs personnages exige un audit supplémentaire, jamais une sélection automatique.
- `authUsersVerifie` et `memePersonnageVerifie` établis par la lecture réelle.
- `anonyme: false`, `emailConfirme: true`, après constat effectif.
- `adresseSHA256` correspondant au SHA-256 de l'adresse confirmée, normalisée en minuscules sans espaces externes. Cela empêche d'essayer accidentellement les identifiants d'un membre de la famille. L'adresse et son empreinte ne doivent pas figurer dans les rapports publics.
- `verifieLe`, horodatage du constat vivant, datant de moins de 24 heures.
- `navigationSansEffetVerifiee`, uniquement après inspection des fonctions et déclencheurs réellement déployés. Ne jamais cocher ce champ pour contourner un catalogue inaccessible.

Ce schéma n'est pas un audit rempli ni une invitation à inventer des valeurs. **Aucun de ces faits n'a été constaté pour Arnie lors de la préparation de ce mode.** Les UID présents dans les tests sont des UUID fictifs de bases jetables.

### Garde réseau et limites du parcours

`consultation.cjs` installe la garde avant de charger la page, sur tout le contexte Chromium, avec Service Workers bloqués et WebSockets refusés. Elle interdit notamment : création anonyme, conversion/rattachement/admin d'authentification, sauvegardes générales et urgentes, écritures d'inventaire, réceptions automatiques, dons, achats, production, invitations/réponses, progression, présence et API métier/cron, même appelées au chargement ou à la fermeture. Aucun succès synthétique n'est renvoyé pour remplacer un refus.

Seuls sont admis la connexion indépendante normale, le renouvellement/contrôle du même UID, les lectures REST, quatre RPC de lecture explicitement énumérées et `rue_position_enregistrer` avec un nœud de Luthécia, après validation du personnage. Les droits serveur, interceptions, détention et restrictions restent applicables. Les RPC inconnues sont refusées, même si leur nom finit par « lire ».

Les ordres métier et dialogues sont aussi refusés dans les handlers du pilote, même appelés directement. Le parcours ne tente pas de transformer un refus en réussite par rechargement. Il contrôle avant/après les déplacements l'identité et la fiche exposée du personnage, avec empreinte de tous les champs hormis position et date de modification. Les valeurs privées ne sont pas exportées dans les preuves du rapport. Toute différence inattendue arrête la campagne ; aucune restauration de données réelles n'est tentée.

**Limite bloquante identifiée dans le code actuel :** `enterRoom` persiste la pièce via `sbSavePersonnage`, qui peut écrire l'inventaire révisé puis une fiche générale. Le déclencheur archivé `personnages_vue_modifier` réécrit de nombreux champs, même à partir d'un PATCH partiel de la vue. La garde ne laisse donc pas passer cette sauvegarde et ne la réécrit pas en un second moteur de navigation. Une pièce non confirmée côté serveur fait échouer le parcours. Le catalogue vivant doit permettre d'identifier un chemin de position déjà sûr, ou une correction distincte couverte doit être préparée, avant de pouvoir certifier toutes les pièces. Aucun déploiement SQL n'est entrepris dans ce chantier pour contourner cette limite.

### Tests hors production

```bash
npm test --prefix outils/e2e
python3 outils/e2e/test-prevol-arnie-local.py --local-jetable
```

Le premier comprend des réponses d'authentification fictives et une garde testée dans Chromium local. Le second exécute le vrai SQL de prévol sur PostgreSQL jetable (Arnie fictif anonyme/classique, homonymes, UID nul et compte absent), sans accès Supabase. Ils ne démontrent ni l'identité réelle ni le raccordement d'Arnie.

Les captures d'échec du mode Arnie sont limitées à l'image de la scène (pièce ou rue), hors portrait, soldes, formulaires et modales personnelles. Aucune capture d'Arnie n'a été produite lors de cette session bloquée.
