# Tirages de l’écran — inventaire du 8 novembre 2026

Coupe immuable : main `d633524f` (PR #633 incluse). Lecture de RELAIS.md, AGENTS.md,
ARCHITECTURE.md et du relevé du 05/11 dans AUDIT_UNE_SEULE_VERITE.md.

Recherche exhaustive `Math.random` dans les fichiers suivis `plateau-*.js`, `data.js`
et pages HTML. **81 lignes textuelles, 75 appels exécutables, 9 mentions
en commentaire** ; plusieurs appels partagent une ligne. Aucune occurrence dans
data.js ou les pages HTML à cette coupe. Le JSON voisin conserve colonnes et fonctions.

**A : conserver**, cosmétique/narration ou identifiant technique sans choix de
résultat (ces identifiants sont distingués explicitement des jets). Une écriture
historique utilisant un identifiant local n’en devient pas autoritaire : sa sécurité
reste un autre contrôle. **B : décisif**, y compris progression ou lieu persistant.
Les commentaires ne sont pas des tirages : rangés A, non exécutables.

## État déjà livré et règles à préserver

- **Antipoison déjà serveur** : `doCentreAntiPoison` → `centre_anti_poison_traiter`,
  migration `20261105101000`, PR #482. Relais : appliquée ; aucune réapplication,
  aucune affirmation de lecture du registre vivant dans cette session. Républia :
  dispensaires 65 %, 1 PA/60 FR ; clinique 85 %, 1 PA/150 FR ; deux tentatives/jour.
- Dons PNJ : argent, présence, refus et POP/INF passent déjà par
  `jauges_ordre_executer('don_argent_pnj',...)`. Il reste précisément DIS côté écran.
- Les noms d’informateur/militant sont cosmétiques : leurs profils sont fixes au
  recrutement serveur (commentaires et appels des moteurs employés existants).
- Les buts et blessures football ne sont **pas** des animations ; le blob est écrit
  par CAS et alimente primes, blessures et classement. Il n’existe pas de moteur
  serveur de match dans les sources examinées (résidu déclaré dans le baseline).
- `genererEvenementsMatch` décrit un score déjà fixé ; ses minutes/noms de récit
  ne modifient pas le résultat. `genererBut` modifie le score mais son tirage
  particulier choisit seulement le nom du buteur, après la décision de but faite
  dans `avancerEvenementsJusqua`. Ses poids restent à déplacer ensemble lors du lot
  football pour préserver les mêmes récits, sans créer de prime individuelle.
- Les rumeurs narratives (confession, abandon, mobilisation) ne créent ni trace
  pénale ni malus : ne pas les confondre avec `crime_detecter_interne`.

## Inventaire occurrence par occurrence

Les lignes ci-dessous sont celles de la coupe ; les lots ultérieurs peuvent les
faire bouger. Une ligne par appel AST, y compris deux appels sur une même ligne.

| Fichier : ligne (colonne) | Ordre / fonction porteuse | Classe | Justification |
| --- | --- | --- | --- |
| `plateau-actions-illegales-rumeurs.js:12:50` | `tracerActionPourRumeur` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-actions-illegales-rumeurs.js:603:63` | `confirmerFuite` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-actions-illegales-rumeurs.js:740:68` | `confirmerCorrompreJournaliste` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-actions-illegales-rumeurs.js:889:66` | `confirmerScandale` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-actions-illegales-rumeurs.js:1722:61` | `confirmerSubtilisationExplosif` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-actions-illegales-rumeurs.js:1760:64` | `confirmerSubtilisationExplosif` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-actions-illegales-rumeurs.js:2183:113` | `getInfomateurInfo` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-actions-illegales-rumeurs.js:2196:25` | `getInfomateurInfo` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-assemblee.js:767:49` | `assembleeNouvelleRequete` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-commerce-pj.js:570:58` | `commercePjInstaller` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-communication.js:908:58` | `confirmerTractageCollectifStade` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-communication.js:949:64` | `confirmerDistribuerTractElectoral` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-communication.js:1058:65` | `confirmerDistribuerTractCalomnieux` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-communication.js:1145:26` | `doLogePortail` | B | Portier de la loge : accès au dialogue 95 %, paiement par l’ordre demander_parler_loge. |
| `plateau-divers.js:21:6` | `genererEvenementAleatoire` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-divers.js:23:15` | `genererEvenementAleatoire` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-divers.js:530:36` | `doSeConfeser` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-divers.js:534:6` | `doSeConfeser` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-divers.js:609:26` | `doDemanderBenediction` | B | Bénédiction historique : réussite et bonus de prochain ordre ; formule CHA titulaire + piété. |
| `plateau-divers.js:697:26` | `doDemanderBenedictionContact` | B | Bénédiction en contact : 80 %, bonus prochain jet +5, 24 h non cumulable. |
| `plateau-football-realisateur-ia.js:815:66` | `undefined::<callback> / selectionnerRealisation` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-football-realisateur-ia.js:1056:70` | `undefined::<callback> / construireArcNarratif` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-immobilier.js:858:100` | `construireDocumentUrbanisme` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-immobilier.js:1005:72` | `archiverEvenementUrbanisme` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-justice-economie.js:882` | `commentaire` | A | Mention en commentaire, non exécutable. |
| `plateau-justice-economie.js:998:49` | `ouvrirModalArrestation` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-justice-economie.js:2062` | `commentaire` | A | Mention en commentaire, non exécutable. |
| `plateau-justice-economie.js:2785:52` | `appliquerSentence` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-justice-economie.js:2859:60` | `appliquerSentence` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-justice-economie.js:3782:80` | `confirmerDonPnj / confirmerDonPnj::<callback>` | B | Don PNJ : issue DIS dépendant du métier et de DUP ; décompte encore local après commande serveur. |
| `plateau-justice-economie.js:6192:62` | `genererIdArmoireSouvenirs` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-justice-economie.js:6201` | `commentaire` | A | Mention en commentaire, non exécutable. |
| `plateau-justice-economie.js:6205:18` | `genererReferenceSecreteArmoire` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-justice-economie.js:6205:62` | `genererReferenceSecreteArmoire` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-justice-economie.js:7823:65` | `confirmerCreationFonds` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-maxence.js:22:34` | `maxenceVerifierPresence` | B | Présence personnelle de Maxence et progression persistées ; choix parc/serre 50/50. |
| `plateau-multijoueur.js:997:55` | `doRecruterInformateurPNJ` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:1035` | `commentaire` | A | Mention en commentaire, non exécutable. |
| `plateau-organisations-quetes.js:1582:24` | `genererEvenementsMatch / minuteLibre` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:1586:53` | `genererEvenementsMatch / genererEvenementsMatch::<callback>` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:1602:33` | `genererEvenementsMatch` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:1604:17` | `genererEvenementsMatch` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:1606:40` | `genererEvenementsMatch` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:1627:65` | `simulerMatch / simulerMatch::<callback>` | B | Score de match ; classement, primes et salaires en découlent. |
| `plateau-organisations-quetes.js:1663:26` | `choisirStadeFinale` | B | Lieu persistant de la finale, donc destination de jeu. |
| `plateau-organisations-quetes.js:2372:19` | `notifierCompositionsEtBlessures` | B | Blessure réelle après match instantané : probabilité 8 %. |
| `plateau-organisations-quetes.js:2374:20` | `notifierCompositionsEtBlessures` | B | Gravité réelle de blessure : 30 %. |
| `plateau-organisations-quetes.js:2375:44` | `notifierCompositionsEtBlessures` | B | Durée réelle de blessure : grave 7..10 jours, légère 2..3 (deux appels distincts). |
| `plateau-organisations-quetes.js:2375:80` | `notifierCompositionsEtBlessures` | B | Durée réelle de blessure : grave 7..10 jours, légère 2..3 (deux appels distincts). |
| `plateau-organisations-quetes.js:2482:41` | `tirerPondere` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:2483:10` | `tirerPondere` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:2513:32` | `genererBut` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:2522:15` | `genererEvenementCouleurLive` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:2525:48` | `genererEvenementCouleurLive` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:2528:32` | `genererEvenementCouleurLive` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:2542:6` | `tenterBlessureLive` | B | Blessure en direct selon probabilité déjà calculée. |
| `plateau-organisations-quetes.js:2543:39` | `tenterBlessureLive` | B | Choix du titulaire effectivement blessé. |
| `plateau-organisations-quetes.js:2544:16` | `tenterBlessureLive` | B | Gravité effective 30 %. |
| `plateau-organisations-quetes.js:2545:40` | `tenterBlessureLive` | B | Durée effective grave 7..10 ou légère 2..3 jours (deux appels). |
| `plateau-organisations-quetes.js:2545:78` | `tenterBlessureLive` | B | Durée effective grave 7..10 ou légère 2..3 jours (deux appels). |
| `plateau-organisations-quetes.js:2556:82` | `tenterBlessureLive` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-organisations-quetes.js:2653:8` | `avancerEvenementsJusqua` | B | Décide du but domicile et du score ; tauxButHome/90. |
| `plateau-organisations-quetes.js:2654:8` | `avancerEvenementsJusqua` | B | Décide du but extérieur et du score ; tauxButAway/90. |
| `plateau-organisations-quetes.js:2655:8` | `avancerEvenementsJusqua` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:2788:50` | `construireEffetsRestantsMatch / construireEffetsRestantsMatch::<callback>` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-organisations-quetes.js:3284:33` | `doRecruterMilitants` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:4241` | `commentaire` | A | Mention en commentaire, non exécutable. |
| `plateau-organisations-quetes.js:5636:27` | `positionnerBallon` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-organisations-quetes.js:6010` | `commentaire` | A | Mention en commentaire, non exécutable. |
| `plateau-personnage.js:2787` | `commentaire` | A | Mention en commentaire, non exécutable. |
| `plateau-personnage.js:2847:59` | `doSoinPublic` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-personnage.js:2893:71` | `doSoinCliniquePrivee` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-personnage.js:3901:6` | `jeterObjetInventaire` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-pnj.js:638:17` | `repondreNegociationParcelle` | A | Variante de réplique 50/50, même progression et aucune conséquence économique dans les deux cas ; consommateurs et banc vérifiés. |
| `plateau-pnj.js:2549:26` | `validerLobbyingPresse` | B | Lobbying presse : succès, paiement conditionnel et publication ; jet uniforme 1..100, taux clamp(base+2*(CHA-13),5,95). |
| `plateau-pnj.js:2720` | `commentaire` | A | Mention en commentaire, non exécutable. |
| `plateau-pnj.js:2941:59` | `ouvrirModalFaireLAmour` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-pnj.js:2960:61` | `ouvrirModalFaireLAmour` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-politique.js:4711:34` | `signerDecretInutile` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-politique.js:7855:53` | `confirmerSubventionMontant` | A | Identifiant technique ; aucune issue ni quantité décidée par ce hasard. |
| `plateau-politique.js:8500` | `commentaire` | A | Mention en commentaire, non exécutable. |
| `plateau-politique.js:9671:54` | `doConsulterDossiersGouv` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-politique.js:12489:6` | `confirmerMobilisation` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |
| `plateau-politique.js:13802:85` | `confirmerRechercheMilitaire` | A | Texte, choix de nom à profil serveur fixe, récit ou réalisation visuelle ; ne décide pas du succès, score, paiement ou effet de jauge. |

## Vérification de la portée de la négociation

L’examen de tous les consommateurs de `resultatNegociation` montre qu’il ne
change que le texte du retour à Laurent. Dans les deux branches, l’étape devient
`negociation_obtenue`, puis `terminee` sans effet économique. Le tirage 50/50 est
donc **A** (réplique) et conservé. Deux contre-cas exécutent les vrais gestionnaires
avec les deux réponses et vérifient progression identique, argent/PA/jauges et
inventaire inchangés (`banc-tirages-narration.cjs`). Ce reclassement corrige
l’inventaire initial, il ne retire aucune assertion sur un jet décisif.

## Lots de livraison

Comptage exécutables : **A 56, B 19**. Les lots partent séparément du dernier main,
avec leurs bancs et leur propre rubrique RELAIS ; aucune migration appliquée ici.

1. Inventaire (cette branche), aucune modification de jeu.
2. Dons PNJ : compléter DIS dans le dispatcher existant et adopter le résultat.
3. Portier de la loge : paiement + jet par le socle d’ordres, sans nouvelle tarification.
4. Bénédiction : porter les deux formules existantes et l’état du bonus, après
   identification de tous les consommateurs (dont p_benediction côté crime).
5. Lobbying : reprendre le même paiement conditionnel, les recettes de rédaction,
   les règles d’étouffement et la publication en une commande transactionnelle.
6. Maxence : conserver l’état par PJ et le moteur de quête ; la réponse du promoteur est cosmétique et conservée.
7. Football : porter le moteur commun complet, CAS, primes, effets et calendrier ;
   ne pas remplacer seulement la fonction qui appelle Math.random.

## Points à ne pas arbitrer silencieusement

- La bénédiction historique variable et le contact à 80 % coexistent. Le contact
  documente explicitement la règle fixe validée ; le routeur conserve l’ancienne
  entrée `demander_benediction`. Vérifier les catalogues/consommateurs avant de
  déclarer l’ancienne formule morte ou de l’uniformiser.
- Blessures **de match** : grave 7..10 et légère 2..3 dans ces sources. La réduction
  à trois jours livrée dans #309 concerne explicitement **l’entraînement**, pas le
  match : ne pas étendre cet arbitrage par supposition.
- Deux formules de score football (instantané et direct) existent réellement.
  Les préserver à parcours constant ; ne pas les uniformiser sans arbitrage.

Ce document certifie la lecture du code, **pas** l’état réel du catalogue Supabase.
Aucun fichier Sovarka, montant, ordre ou texte RP modifié. Aucun accès réseau de
production, aucune migration, fusion ou campagne sur joueur réel.

## Livraison partielle et suites — 08/11

Branche inventaire réconciliée sans conflit avec main `9e1ec47f` (décors Novomirsk
préservés). La coupe du tableau reste `d633524f`, pour conserver des lignes
vérifiables. Tests de narration : deux tirages opposés donnent exactement la même
progression et aucun gain/perte. La variante du promoteur reste cosmétique.

**Lot dons préparé et poussé séparément**, branche
`codex/tirages-dons-pnj-20261108`, source `f3fab7c6`, preuves `edc59c9c`, intégration
main `95fb97e7`. Migration `20261108130723_dons_pnj_dis_serveur.sql` non appliquée,
dépendante du nouvel écran. 93 assertions SQL annulées, deux courses authentifiées,
rollback/rejeu et deux mutations négatives détectées ; 204 bancs clients avant
intégration du dernier main. Rapport complet sur cette branche. Le jet DIS est
retiré de l'écran dans ce lot, pas encore dans le jeu publié.

### Questions réellement non résolues (aucune règle choisie ici)

- **Expiration de la bénédiction** : le texte annonce 24 h mais
  `doDemanderBenediction` et `doDemanderBenedictionContact` enregistrent
  `expire=(state.day||1)+1`, consommé avec `state.day<=expire`. Ce n'est pas une
  échéance réelle. La règle d'horloge commune est acquise ; aucune migration ne
  doit convertir silencieusement cette durée contradictoire. Préciser l'échéance
  applicable au bonus, sans changer ses taux ni ses cinq points.
- **Portier** : `demander_parler_loge` passe 1 PA via le routeur ; les appels sans
  arguments de `plateau-navigation.js:331,447` passent par les valeurs par défaut
  zéro de `deduireCoutOrdre`. Les 95 % sont non ambigus, le coût des appels depuis
  la rue ne l'est pas. Ne pas créer un ordre gratuit ni débiter arbitrairement.

### Raccordements encore à réaliser (pas des blocages d'accès)

- Bénédictions : les sept appels encore présents à `consommerBonusBenediction`
  concernent vol, arme noire, évasion, enquête, filature, chasse et matériau de
  chantier. Ils transmettent encore `p_benediction` depuis l'écran. Porter le
  seul tirage sans consommation serveur permettrait de rejouer le bonus : le lot
  doit fermer ces chemins ensemble, dans les fonctions existantes.
- Lobbying : PA prélevés avant le jet, argent seulement au succès, recette de la
  rédaction, étouffement et publication sont aujourd'hui plusieurs appels. La
  nouvelle commande devra rendre ce parcours entier atomique, conserver
  `clamp(round(base+2*(CHA-13)),5,95)` et ne pas se limiter à un RPC « lancer un dé ».
- Maxence : choix personnel parc/serre 50/50 puis fuite après deux questions ;
  conserver cette continuité par PJ. Il est classé B par prudence : sa présence
  est persistante, même si les succès relevés n'accordent aucune jauge.
- Football : les deux modes, les blessures, le lieu de finale et les effets du
  championnat restent à porter. Aucun contrôle ni commande fictive ne remplace
  cette réalisation. Les taux recensés ne sont pas déclarés validés au serveur.

**Chantier global non terminé.** Aucune panne extérieure ne justifie les lots
encore non implémentés ; ils sont explicitement laissés ouverts. Ni CI distante,
ni application SQL, ni vérification en production n'est revendiquée.
