# Parcours joueur automatisé — Luthécia

Cet outil pilote l'interface du jeu dans Chromium, au rythme d'un joueur. Il ne crée aucun compte, ne revendique aucun personnage, n'injecte pas d'état et n'appelle aucun moteur d'écriture directement. **Sans compte explicitement autorisé, il s'arrête avant de charger la page de connexion.** Arnie constitue une autorisation historique distincte : exclusivement `consultation_seule`, après prévol authentifié automatique de son compte existant. Les tests du pilote sur fixtures ne sont pas des tests authentifiés du jeu.

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


## Arnie : prévol automatique et première consultation

L'autorisation du propriétaire est limitée à Arnie. Le workflow manuel `consultation_seule` utilise exclusivement trois secrets de l'environnement `luthecia-e2e` : `HG_E2E_ARNIE_EMAIL`, `HG_E2E_ARNIE_PASSWORD`, `HG_E2E_ARNIE_UID`. Aucun repli vers un autre compte. L'origine de production est fixée à `https://res-publica.vercel.app` ; cette valeur est utilisée par défaut. Aucun secret `HG_E2E_ARNIE_AUTORISATION_JSON` ni déclaration `auditArnie` n'est nécessaire. Le mode est interdit au planning nocturne et exige `workflow_dispatch`.

Avant même de charger la page de connexion, `prevolAutomatique` utilise la clé **publique** déjà présente dans `supabase.js` et les identifiants protégés du job pour :

1. Se connecter normalement au service GoTrue, sans création ni conversion de compte.
2. Vérifier le même UID, l'adresse attendue, le caractère non anonyme et la confirmation, puis relire `/auth/v1/user`.
3. Appeler la RPC existante `mon_personnage` : la réponse doit être exactement Arnie.
4. Lire sous les droits RLS de cette session la fiche filtrée par UID, avec une limite de deux lignes : exactement une fiche visible Arnie, liée au même UID, en Républia à Luthécia est exigée.
5. Garder uniquement une empreinte du patrimoine/progression et la position dans le rapport. Aucun identifiant de compte, mot de passe ou jeton n'est exporté.

Les requêtes sont bornées, sans redirection ni rejeu automatique. Transport indisponible, statut HTTP et JSON invalide ont des codes distincts. Toute identité différente arrête avant la page du jeu. La lecture sous RLS ne certifie pas l'absence d'une fiche invisible ; elle est recoupée avec la sélection autoritaire de `mon_personnage`. Elle ne remplace pas une lecture des catalogues pour auditer des fonctions d'écriture.

La connexion par formulaire est ensuite conservée. La garde intercepte aussi ces réponses : UID, adresse et confirmation sont revérifiés avant livraison à la page, puis le personnage effectif. Les sauvegardes, réceptions automatiques, présence, dépenses, ordres, dialogues, transferts, API/cron, créations et modifications d'authentification sont bloqués avant envoi. Les WebSockets sont refusés et les Service Workers bloqués. Les lectures REST requièrent une identité vérifiée ; seules quatre RPC de lecture explicites sont admises. Aucun succès synthétique ne masque un refus.

**Les déplacements sont actuellement tous interdits**, côté pilote et réseau, y compris `rue_position_enregistrer`. Une déclaration historique `navigationSansEffetVerifiee: true` ne peut pas lever ce verrou. En effet, `enterRoom` déclenche `sbSavePersonnage` ; la sauvegarde peut écrire inventaire et fiche entière. Le déclencheur archivé de la vue peut réécrire des champs financiers même lors d'un PATCH partiel. Les effets du déplacement dans la rue ne sont pas certifiés par un catalogue vivant accessible à cette session. Aucun PATCH réduit ou second moteur de navigation n'est introduit.

La campagne consulte uniquement la scène **déjà occupée**, vérifie son affichage et sa position client/serveur, puis relit l'empreinte initiale du personnage. Un changement inattendu arrête le test, sans restauration de données réelles. Le résultat `CONSULTATION_INITIALE_AUTHENTIFIEE` désigne uniquement cette consultation. Les erreurs navigateur sont signalées séparément. Le code de sortie reste **2**, car le parcours mobile et les scénarios métier ne sont pas validés : le job peut être rouge même si la consultation initiale est confirmée. Les écritures automatiques bloquées restent visibles dans le rapport, sans être présentées comme des pannes réseau du jeu.

Le rapport privé Actions (rétention de trois jours) est produit même en cas d'échec. Les captures d'échec restent limitées à la scène, hors portrait et modales personnelles. Pas de trace, HAR, session exportée ou identifiants dans les journaux. Ne pas déclarer le testeur complet opérationnel à partir d'une consultation initiale.

### Tests hors production

`npm test --prefix outils/e2e` couvre le prévol sur réponses fictives, son transport Playwright sur HTTP local, et la garde Chromium avec vérification des requêtes réellement reçues par un serveur local. Les refus d'identité, anonymat, confirmation, personnage, ambiguïté, territoire, HTTP, JSON, réseau, déplacements et écritures sont exercés. Les tests de `rpAuthSecuriserCompte` restent des tests sur réponses fictives : le pilote ne modifie jamais l'authentification d'Arnie.

Le SQL en lecture seule `outils/bancs/prevol-arnie.sql` reste disponible pour l'opérateur disposant du catalogue vivant ; il n'est plus un formulaire d'autorisation obligatoire. `python3 outils/e2e/test-prevol-arnie-local.py --local-jetable` l'exerce uniquement sur PostgreSQL jetable. Aucun résultat local ne constitue une preuve de connexion ou de visite réelle d'Arnie.


## Recette immobilière #135 — 25 octobre 2026

`npm test --prefix outils/e2e` inclut maintenant `test-immobilier-135.cjs`. Il charge dans Chromium les véritables déclarations et fonctions de `data.js`, du routeur et des moteurs d'interface existants. Les scènes, personnages, lectures et autorisations sont des fixtures **locales**, sans compte Supabase : cela ne prouve aucune visite d'Arnie. Il vérifie les cinq superficies/prix distincts, les menus d'achat et de compromis, les clauses de prêt et de permis, la demande après un achat sans permis, les formulaires de construction et les tarifs matériaux 6/11/17 FR. Aucun bouton de signature, de paiement ou de lancement n'est cliqué. Le prêt travaux renvoie toujours au guichet national. La reproduction de l'ancien défaut et les refus de tiers, instruction, carence, occupation, chantier et bâtiment existants sont conservés.

L'analyseur Acorn utilisé par les tests est déclaré et verrouillé ici. Le pilote et son workflow n'ont plus besoin que les dépendances du constructeur Vercel soient installées ailleurs ; les tests d'identité existants sont conservés, sans modification d'`auth.js`.

**Attention pour une campagne avec Arnie :** `acheter_terrain` n'ouvre pas une simple fiche, il peut appeler immédiatement `finance135Acquerir(...,'depot',...)`. Il est donc interdit de le cliquer avec l'autorisation actuelle. Le verrou de navigation de `consultation_seule` reste fermé tant que les effets des déplacements ne sont pas attestés. La correction d'interface ne lève ni ce verrou, ni les restrictions d'écriture, ni les contrôles d'UID.

Les secrets `HG_E2E_ARNIE_*` restent dans l'environnement Actions `luthecia-e2e`. Ils ne peuvent pas être lus par le pilote local ni récupérés via l'API des secrets ; ils ne doivent jamais être exportés dans le chat ou le dépôt. Le rapport du 25 octobre distingue le lancement local bloqué avant authentification, les tests isolés et l'impossibilité de consulter/lancer les campagnes distantes à cause du refus réseau vers l'API GitHub.
