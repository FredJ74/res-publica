# Suite mobile du 6 novembre — code local, recette distante à réaliser

Base réconciliée : main `b41d387e`, incluant L0–L3 et L6 intégrés par Claude.
Aucune des cinq branches initiales n'a été modifiée. Sovarka, ses images, ses
migrations et ses versions de scripts ont été conservés. Aucune migration mobile,
connexion de joueur, écriture Supabase, fusion ou commande Vercel effectuée.

## Lots et périmètre

| Lot | Branche | Modifications et vérifications locales |
|---|---|---|
| L5 | `codex/mobile-l5-transactions-20261106` | Fiche en colonne, inventaire lisible, tableaux défilants et quantités tactiles ; aucun montant ni objet fabriqué. Helvetia réutilise le verrou commun pour empêcher deux callbacks de retirer deux fois les PA. Trois tests : double dépôt, double retrait, changement de personnage. |
| L8 | `codex/mobile-l8-reprise-20261106` | Réutilise le chargeur et l'authentification existants au retour ; premier ordre suspendu, jamais rejoué. Réponses tardives et restauration à 300 ms protégées par identité et contexte. Aucun polling ajouté ni calendrier serveur changé. |
| L4 | `codex/mobile-l4-creation-20261106` | Connexion et étapes de création adaptées ; six langues fr/en/es/zh-TW/ru/ko ; descriptions « En jeu » conservées, règles de création intactes. |
| L7 | `codex/mobile-l7-institutions-20261106` | Grilles, cases et rapports adaptés ; classes ciblées dans les écrans existants. Fixture du vrai rendu combat : consultation sans droit, trois décisions avec droit, aucune décision après repli. Aucune décision exécutée. |
| L9 | `codex/mobile-l9-chargement-20261106` | Chargement natif différé uniquement des miniatures d'inventaire et portraits ; scènes inchangées. Vingt portraits du vrai rendu : aucune requête d'image lorsque le panneau est fermé, requêtes à son ouverture. Pas de découpage des scripts globaux. |
| L10 | `codex/mobile-l10-recette-20261106` | Recette consolidée, contre-épreuves et garde des rendus différés. Ce lot ne vaut pas certification sur téléphone ou compte réel. |

Ordre des dépendances : **L5 → L8 → L4 → L7 → L9 → L10**. Les branches successives
transportent les dépendances pour ne pas bloquer le développement. Avant chaque
fusion vers main, intégrer le précédent, réconcilier et contrôler le SHA final.
Les corps REST préparés se trouvent dans `outils/livraison/MOBILE-SUITE-PR-20261106.json`.
Ils sont en brouillon pour ne pas confondre préparation et livraison.

## Preuves exécutées

- Recette ciblée consolidée : **77 tests réussis, 0 échec, 0 ignoré**.
- Bureau 1440×900 : PNG strictement identiques avant/après pour plateau, création et
  forum ; comparaison avec le témoin embarqué `728010c8` vérifié par SHA-256.
- Formats Chromium : 375×667, 393×852, 412×915, 852×393 et 768×1024.
- Reprise : hors ligne, retour visible simulé, signal d'un autre onglet, chargement
  tardif et contexte changé. Un autre onglet n'est pas une preuve de deux appareils.
- Garde fiche serveur : 23 contrôles et 9 mutations détectées. Le détecteur exige
  la nouvelle garde ; aucune assertion supprimée ni rendue optionnelle.
- Restauration différée et position F5 : 8 tests réussis.
- Contrôleur client complet : résultat final dans `MOBILE-SUITE-RESULTATS-20261106.json`.
- Contrôle global : **8/12**, même verdict et mêmes quatre familles en échec sur
  le main détaché `b41d387e`, avec les mêmes dépendances locales.

Empreintes des PNG 1440 (chaque paire avant/après a la même empreinte) :

| Vue | SHA-256 |
|---|---|
| Plateau | `78162d765b6d26a2d5a3b13c31e3a0e84d9deeffa61bbf025d34633a35811384` |
| Création | `cb2620ccb6da7ef219d6431c03c08a7fccee320e45b78d467c68c044ede6307b` |
| Forum | `0d7f587b0fd0431fd012100265b8e8a479040dbb9099ccf573061d47113a7dc0` |

Les journaux bruts et captures de cette campagne restent locaux dans `/tmp` ; seuls
les résultats structurés et empreintes sont versionnés. Les scènes de test emploient
des fixtures, sans données privées ni requêtes vers la production.

## Échecs hérités, non masqués

1. Workflow : SQL ponctuel hors des trois maisons,
   `outils/corrections/RATTRAPAGE-SALAIRE-MINISTRE-STAROVKA-20261106.sql`.
2. Baseline : miroir `ordres_couts`, nombre de lignes `chaines_production_usine`
   (6 contre 5), empreintes des seeds `chaines_production_usine`, `ordres_couts`
   et `ressources_economie`. Huit anomalies rapportées, aucune empreinte ajustée.
3. Authority : migration `20261104173000_trading_livraison_terrestre.sql` cite
   une signature inconnue `trading_acheter(text,text,text,integer,text)`.
4. Referential : artefact `RESSOURCES_ECONOMIE_SERVEUR` illisible ; diagnostic
   du contrôleur conservé, aucun référentiel réécrit dans le chantier mobile.

Une première comparaison main sans Acorn local avait aussi échoué sur Fonctions.
Après installation des mêmes liens de dépendances, Fonctions passe : cette erreur
était celle de l'environnement de comparaison et n'est pas comptée comme héritage.

## Réserves et livraison

- REST GitHub GET et POST refusés par `Forbidden` ; une requête HTTP indépendante
  reçoit également 403/Envoy. Le push Git fonctionne. Aucun numéro de PR inventé,
  aucune CI distante ni fusion certifiée. GraphQL n'a pas été utilisé pour créer ces PR.
- Safari iOS, clavier réel, verrouillage OS, authentification et deux appareils
  n'ont pas été testés. Pas de secret récupéré ni compte créé. La recette réelle
  L10 reste ouverte jusqu'à ces vérifications sur un compte isolé autorisé.
- Helvetia historique conserve son calcul local de PA. Le verrou évite la double
  application dans la même interface, mais ne prouve pas l'idempotence serveur après
  perte d'une réponse. Le contrat vivant des RPC n'a pas été inspecté. Aucune migration
  ni moteur financier supplémentaire introduit ; ne pas certifier cette garantie.
- L7 valide la présentation et les droits fournis par des fixtures ; les parcours
  institutionnels authentifiés complets ne sont pas certifiés par ce test.
- L9 : relevé indicatif avant les derniers petits correctifs, 65 scripts / 7 316 011
  octets bruts, gzip local 2 072 103 ; ce n'est pas une mesure réseau facturée.
  Mesurer les octets et requêtes réellement servis avant/après, à conditions égales,
  puis contrôler les consommations Supabase/Vercel après une livraison autorisée.

## Recette téléphone à l'intégration

Sur compte isolé : fiche, inventaire long, commerce et banque sans paiement ;
connexion et huit étapes de création dans chaque langue sans valider de personnage ;
organisations et rapport combat en consultation. Vérifier aussi le plateau au bureau.
Verrouiller le téléphone, couper/remettre le réseau, revenir et cliquer : la reprise
synchronise avant l'ordre, ne le rejoue pas. Avec deux appareils autorisés, confirmer
le refus des états périmés côté serveur. Toute transaction à effets reste réservée
aux bancs isolés et à une autorisation spécifique ; ne pas utiliser un joueur réel.

**Code et tests locaux disponibles ; pas de livraison ni de recette en jeu certifiée.**
