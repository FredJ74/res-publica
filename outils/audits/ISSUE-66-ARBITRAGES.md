Audit du 21 octobre 2026 — lecture du code **main** et des fonctions Supabase **réellement déployées** (aucune écriture ni migration).

## Rachat d'entreprise
- Interface client dans `plateau-actions-illegales-rumeurs.js` : `getEntreprisesRachetables()` énumère armureries, commerces alimentaires et imprimeries ; `doRachatEntreprise()` ne propose que les entreprises dont `data.proprietaire === 'PNJ'` et sans compromis actif. Compromis 7 jours, acompte 1 000 FR, possibilité de demande de prêt, puis acte notarié (`doActeRachatEntreprise` / `traiterActeRachatEntreprise`).
- RPC de production `entreprise_acte_rachat(p_acteur,p_entreprise,p_ordre,p_pa,p_cost)` débite le solde, efface le compromis et exécute **uniquement** `UPDATE public.entreprises SET data = ... jsonb_build_object('proprietaire',p_acteur)`. **Aucune mutation de `terrains_etat.proprietaire`, ni transfert de titre immobilier.** Ce rachat concerne l'**entreprise / fonds et son exploitation**, **pas les murs**.
- Cas spécial imprimerie : `imprimerie_cession_finaliser` en production transfère également seulement `entreprises.data.proprietaire` et crédite la caisse de l'État. Aucun titre foncier transféré.
- À noter : la limitation actuelle de mise en vente concerne essentiellement ces **entreprises PNJ** ; cela ne prouve pas qu'une vente de fonds PJ à PJ est gérée dans ce même parcours.
- Un commentaire du chemin `entreprise_acte_rachat` dit que le nom d'ordre `acte_rachat_entreprise` n'est déclaré dans aucun ordre `data.js` et peut rendre la route inaccessible : vérifier dans le catalogue effectivement chargé et résoudre avant toute prétention de fonctionnement de bout en bout.

## Acquisition des murs déjà bâtis
- `plateau-immobilier.js` distingue explicitement **titulaire des murs** et **locataire/exploitant**. Pour les lots privés, les loyers doivent être versés au titulaire actuel identifié par `terrains_etat.proprietaire`.
- L'Office notarial `doActeVenteTerrain` (`plateau-justice-economie.js`) traite les terrains sous compromis et les achats directs. Source `terrains_etat` et prix du terrain, pas transfert implicite à l'achat d'une entreprise. Le parcours immobilier #57 / PR #58 laisse explicitement acquisition, prêts, actes et transfert atomique partiellement non sécurisés.
- Aucune preuve à ce stade d'une **mise en vente générale par un PJ de ses murs déjà construits**, d'une offre acceptée par un acquéreur et d'un acte atomique conservant baux/locataires et lots, distinct de la vente de fonds. Parcours complet **non validé** ; ne pas le qualifier de codé/opérationnel.
- Pour terminer l'audit, retracer les événements et RPC de transfert de `terrains_etat.proprietaire` en présence de `niveau_construction`/lots, les droits du propriétaire vendeur, l'impact sur baux, l'acte notarial, la mise en vente et les financements, et valider en PostgreSQL local puis en environnement de test authentifié.

**Décision de game design non ajoutée ici** : présenter séparément acquisition du fonds et acquisition des murs au joueur, sans supposer qu'une vente de l'un emporte l'autre. Ne pas reconstruire les moteurs existants, continuer dans #57/#58 et financement #65.

## Arbitrage game design complémentaire — propriété initiale des commerces PNJ (21 octobre 2026)

**Validé :** les **murs** des commerces initialement exploités par des PNJ sont propriété de la **municipalité** de leur ville. La propriété du **fonds de commerce** est indépendante de celle des murs.

Un PJ peut investir progressivement en achetant **uniquement les murs**, **uniquement le fonds**, ou **les deux**, par des actes distincts. L'achat du fonds ne transfère jamais implicitement les murs ; l'achat des murs ne transfère jamais implicitement le fonds. Préserver les baux, l'occupant et le loyer pendant ces mutations, sans inventer de double propriété. Raccorder au système municipal, aux titres immobiliers, aux mécanismes d'entreprises et à l'office notarial déjà codés ; ne pas créer d'architecture concurrente.

**À arbitrer ensuite :** valeurs/prix distincts des murs et des fonds ; aucune valeur nouvelle n'est validée dans ce message. Avant proposition tarifaire, dresser l'inventaire des prix de rachat de fonds déjà codés, des valeurs cadastrales et des loyers existants ; différencier clairement prix déjà présent dans le code et nouvelle décision. Aucune migration ou déploiement tant que les contrats et valeurs ne sont pas finalisés.


## Surfaces des commerces PNJ et de l'hôtel La Republica (21/10/2026)

Nouvelle orientation de game design : **prix des murs calculé simplement en fonction de la surface en m²**, indépendamment de la valeur du fonds. Les commerces existants n'ont pas encore de surfaces générales définies ; centres commerciaux et bureaux ont déjà des surfaces à préserver.

Audit `data.js` : `hotel-republica` = établissement unique avec six pièces : accueil, restaurant, bar, chambres, suite privée, suite présidentielle. Ces pièces sont internes au même bâtiment ; ne pas les traiter comme six biens immobiliers autonomes. La valorisation de 380 000 FR dans `PRIX_RACHAT_COMMERCE` concerne le fonds entier, pas les murs. Le bâtiment doit recevoir une surface immobilière totale (à arbitrer), et les autres commerces PNJ une surface chacun. Ne pas inventer ni déployer de superficie sans validation explicite de Fred ; garder les surfaces des centres et bureaux déjà établies. Prochaine étape : proposer un barème simple de surfaces par catégorie puis arbitrer le tarif unique FR/m² et les surfaces des grands établissements.


### Arbitrage validé — surface de La Republica
Fred valide **1 200 m² de surface totale** pour l’hôtel-restaurant-bar La Republica de Luthécia, englobant accueil, restaurant, bar, chambres, suite privée et suite présidentielle. Il s’agit de la surface des murs du bâtiment unique, distincte de la valeur du fonds (380 000 FR existants). Les autres surfaces proposées et le tarif au m² ne sont pas encore validés.


### Arbitrage validé — tarif uniforme des murs dans Républia
Un **même prix de référence par m²** sera appliqué dans toutes les villes de Républia, sans coefficient de ville ni de quartier. La **valeur numérique FR/m² reste à déterminer** ; aucune modification des superficies déjà fixées. Surface de La Republica : 1 200 m², déjà validée. Ne pas confondre prix des murs et prix du fonds.


### Arbitrage validé — tarif immobilier et présentation chez le notaire (21 octobre 2026)
- **Prix des murs : 150 FR/m²**, unique pour toutes les villes de Républia, sans coefficient local. La Republica : **1 200 m² × 150 = 180 000 FR pour les murs**, à distinguer des **380 000 FR de fonds** déjà déclarés, soit **560 000 FR pour les deux** avant éventuels frais.
- **Le notaire doit distinguer les offres consultables :** « Fonds de commerce », « Murs / immobilier » et, lorsque les deux actifs sont proposés, « Fonds + murs ». Pour chaque offre afficher clairement propriétaire/vendeur, ville, établissement, surface des murs, prix du fonds, prix des murs, prix total si achat conjoint, statut disponible/sous compromis.
- Chacun des deux titres est **juridiquement et techniquement indépendant** : acquérir le fonds ne transfère pas les murs ; acquérir les murs ne transfère pas le fonds, ni les baux/occupants. Une acquisition conjointe doit protéger l'acheteur contre un demi-achat accidentel (transaction serveur atomique pour les deux transferts/paiements, ou mécanisme explicitement compensé et vérifié). Ne pas seulement concaténer les deux boutons clients existants.
- À l'origine les communes possèdent les murs des commerces PNJ ; les titulaires des fonds PNJ sont distincts. Les surfaces des autres commerces restent à fixer, **ne pas attribuer arbitrairement 80/150/250 m² sans validation**.
- Menu actuel `ouvrirMenuOfficialiserTransaction` (dans `plateau-justice-economie.js`) ne propose que « Vente de terrain » et « Rachat d'une entreprise » : étendre son UX **sans confondre consultation des offres et officialisation d'un compromis déjà signé**. Préserver les mécanismes d'achat/cession existants et financer les transactions via le moteur commun, avec titres distincts `terrains_etat` / `entreprises` et loyer revenant au propriétaire actuel.
- Tests à prévoir : prix calculé sur surface validée, acheter fonds seul / murs seuls / les deux, vendeurs différents, baux conservés, loyers vers bon propriétaire, achats concurrents, refus/débit intégral, rechargement F5, compatibilité anciens titres.


### Décision impérative d'architecture — socle immobilier transversal (21 octobre 2026)
**Ne surtout pas implémenter la vente des murs et des fonds bâtiment par bâtiment.** Concevoir un **socle commun paramétré**, réutilisable par toutes les villes et tous les commerces présents et futurs. Chaque établissement ne fournit que sa fiche/données de raccordement : identifiant canonique, pays/ville, surface validée, titre des murs, titre du fonds ou de l'entreprise, propriétaire de chacun, possibilité de vente séparée/conjointe, baux/occupants.

Responsabilités du socle : découverte des offres chez le notaire ; prix des murs = surface × barème territorial (Républia : 150 FR/m²) ; prix du fonds selon son catalogue ; compromis/expiration ; financement ; transfert transactionnel des titres des murs et/ou du fonds ; pérennité des baux et attribution des loyers au nouveau propriétaire des murs ; traçabilité, vérification des droits et anti-double paiement. **Un seul moteur de transaction**, pas de branches spécifiques `hotel-republica` ou par enseigne. Un achat conjoint ne peut pas aboutir à un transfert partiel.

**Réutiliser prioritairement** les moteurs déjà existants (entreprises, terrains_etat, locations_actives, office notarial, paiement et prêts) et les adapter en commun plutôt que construire un second cadastre ou un second système de ventes. Un nouveau bâtiment ou commerce ne doit pas nécessiter de nouvelle fonction métier : seule sa configuration change.

Conserver l'exemple La Republica comme **cas de test et donnée initiale**, pas comme exception codée (surface 1 200 m², fonds 380 000 FR, murs 180 000 FR). Prévoir la migration des commerces PNJ sans surfaces et les droits municipaux des murs en empêchant toute vente tant que la fiche n'est pas complète ; ne pas inventer des surfaces. Vérifier baux, PJ/PJ et PNJ/PJ, changements de propriétaire et intégrité en concurrence. Aucun déploiement avant tests.


### Clarification ferme de game design — mécanique identique partout
Le game designer confirme : **une mécanique immobilière strictement commune pour tous les bâtiments et tous les pays**. La **seule variable de barème entre territoires est le prix au m²** (Républia = 150 FR/m²). Aucun coefficient selon la ville, le quartier, le standing ou le type de commerce ; aucune branche de moteur par hôtel, bar, bureau ou bâtiment. Chaque bien possède naturellement sa surface et son identité (données), sans que cela constitue une règle de valorisation différente. La valeur du fonds reste un actif distinct et ne doit pas être assimilée à la valeur des murs. Architecture laissée au responsable technique, dans le respect de la réutilisation des socles existants.


### Arbitrage complémentaire — liberté des prix de vente entre PJ (Républia)
**Les barèmes de fonds PNJ et de murs à 150 FR/m² sont des prix de cession de biens qui n'appartiennent pas à des PJ** (PNJ / municipalité). **Dès qu'un PJ est propriétaire d'un fonds ou de murs en Républia, il fixe librement son prix de vente**, sans plafond ni plancher dérivé du barème. La liberté vaut pour le fonds seul, les murs seuls et leurs offres conjointes (prix explicitement fixés par le ou les titulaires des droits respectifs). Ne jamais substituer automatiquement la valeur de référence à l'offre d'un PJ. L'interface du notaire doit distinguer « prix public/de référence » et « prix demandé par le propriétaire PJ ». Règle de prix de revente des autres empires non arbitrée ; ne pas l'extrapoler. 


### Arbitrage validé — vente de murs loués et priorité de l'exploitant
Le propriétaire des murs peut les mettre en vente **sans demander l'accord de l'exploitant du fonds**. **Le bail en cours survit à la vente** et engage le nouvel acquéreur des murs. **L'exploitant en place bénéficie d'une priorité pour acheter les murs** avant tout acquéreur tiers (droit de préemption). Raccorder au socle immobilier commun, en vérifiant l'occupant/bail actuel au serveur au moment de la mise en vente et de l'acte ; empêcher qu'un tiers puisse finaliser tant que la priorité est ouverte. Le délai et la procédure d'exercice de cette priorité ne sont pas encore arbitrés ; ne pas inventer de valeur. Préserver un prix offert identique lors de la priorité et de la cession à un tiers, sauf offre ultérieure distincte validée selon les règles à définir.


### Arbitrage validé — procédure de préemption des murs loués (21 octobre 2026)
- Le propriétaire met les murs en vente **chez le notaire**, au prix qu'il a fixé selon son régime économique.
- Si les murs sont occupés par un exploitant locataire, celui-ci reçoit **automatiquement un mail** lui notifiant l'offre et son **droit de priorité** pour acheter au prix annoncé.
- **Délai de priorité : 3 jours réels** à partir de la notification. Durant cette période, l'offre n'est **pas ouverte officiellement aux tiers** et ceux-ci ne peuvent pas finaliser l'achat.
- Si l'exploitant n'exerce pas son droit avant l'expiration, **le bien est mis en vente officiellement à tous** et l'exploitant **perd sa priorité** pour cette mise en vente. Il peut alors acheter comme n'importe quel autre acheteur.
- Toute vente des murs conserve le bail et ses conditions, avec substitution du nouveau bailleur.
- Implémentation commune : état des offres et échéances autoritaires côté serveur, notification mail idempotente, publication automatique après délai même sans joueur connecté (cron/horloge commune), protection transactionnelle contre ventes prématurées, et aucun mécanisme propre à un bâtiment.
- Un refus explicite de l'exploitant, et les conséquences d'un changement de prix ou d'un retrait puis republication, n'ont **pas** été arbitrés dans cet échange : ne pas leur attribuer implicitement une règle irréversible.


### Précision préemption : refus explicite
Si l'exploitant locataire refuse explicitement l'offre prioritaire, cela met fin à sa priorité et permet la publication générale sans attendre 3 jours. Si aucune réponse, publication automatiquement après 3 jours réels. Publication/horodatage et reprise de vente sécurisés côté serveur ; courrier automatique conservé.

### Contrôle de cohérence économique (21/10)
Le moteur actuel `plateau-chantiers.js` porte des coûts forfaitaires de construction : hangar 30 000 FR / 6 jours, commerce standard 60 000 FR / 12 jours, commerce premium 90 000 FR / 18 jours, immeuble 120 000 FR / 24 jours, **hors achat du terrain**. À 150 FR/m², 1 200 m² de murs La Republica valent 180 000 FR ; écart 60 000 FR avec le chantier d'immeuble seul, avant terrain, délais, matériaux et frais. Vigilance : construction = palier forfaitaire, vente murs = superficie ; arbitrer si cette asymétrie est voulue, avant coder une rentabilité automatique ou modifier les coûts existants.


### Arbitrage économique — construire ne doit pas revenir plus cher qu'acheter l'existant
Le game designer précise : **construire soi-même ne doit pas coûter plus cher que l'achat d'un bâtiment existant comparable**. Pour comparer, prendre le **coût complet** de la construction (terrain + chantier et coûts obligatoires), versus le **prix des murs de référence hors fonds de commerce** d'un bâtiment existant comparable, en Républia pour les cessions non-PJ. Les prix libres PJ↔PJ restent souverains et peuvent évidemment sortir de cette comparaison ; ne pas leur imposer de plafond. Vérifier les surfaces réelles, les coûts de parcelle, les paliers et les coûts obligatoires avant toute modification ; ne pas modifier silencieusement le barème validé 150 FR/m² ni les coûts des chantiers. Faire remonter uniquement si ces paramètres existants rendent la règle impossible à respecter. Ne pas considérer le tarif du fonds dans la comparaison des murs.


## ORDRE D'EXÉCUTION TECHNIQUE — prêt pour Codex (21/10/2026)

Implémenter le **socle immobilier commun** décrit ici, en réutilisant l'existant. Ne pas coder un moteur spécifique à chaque établissement. Branche/PR dédiée depuis l'état cohérent de la PR #58 ; ne pas mélanger les correctifs de la PR #56 ni les réservations #63. Si #58 est encore instable, avancer sur des modules/test indépendants sans fusion en production.

1. AUDIT : cartographier titres `terrains_etat`, propriétaires et surfaces, `entreprises`, `locations_actives`, office notarial, compromis, prêts et migrations. Produire matrice des flux/acteurs/états, déterminer exactement le chemin vente fonds, murs et les deux et les transactions atomiques manquantes.
2. MODÈLE COMMUN : droits des murs distincts de droits du fonds ; initialiser correctement les murs municipaux des commerces PNJ sans réécrire des titres PJ ; surface explicite obligatoire avant offre. `prix_murs_public = surface*tarif_pays`, Républia 150 FR/m². Fonds PNJ prix catalogue existant, fonds et murs PJ prix libre en Républia ; Sovarka NON arbitré.
3. NOTAIRE : catalogue des offres fonds / murs / ensemble, vendeur véritable et propriétaire des deux droits, superficies et prix détaillés, compromis, acte sécurisé et droits de cession, préservation des baux. Paiements et changements de titres transactionnels/idempotents, y compris ensemble ; ne pas inventer une deuxième caisse.
4. PRÉEMPTION : dépôt d'offre sur murs occupés => mail automatique à l'exploitant, 3 jours réels de priorité exclusive ; **refus explicite = publication immédiate**, absence de réponse = publication automatique à J+3 même sans connecté ; achat du locataire pendant la fenêtre ; bail inchangé lors du transfert ; verrous pour publication et signature concurrentes.
5. ÉCONOMIE : vérifier les coûts complets de construction (terrain + chantier) face au prix public de l'existant comparable, pour que construire ne revienne **pas plus cher**. Ne pas modifier arbitrairement 150 FR/m² ni les paliers sans signaler une incompatibilité chiffrée. Prix libre des PJ jamais plafonné.
6. TESTS : matrice fonds seul/murs seuls/ensemble, baux et loyers, PNJ/municipalité/PJ, notification et refus, expiration hors connexion, prêts, protection du vendeur, rollbacks, clics concurrents, anciennes données et F5. Documenter les écarts et ne pas déployer sans prévol et vérification.

**Données approuvées :** La Republica 1 200 m², murs municipaux 180 000 FR, fonds PNJ 380 000 FR, ensemble 560 000 FR avant frais ; pas de surface inventée pour les autres commerces. Décisions déjà actées ci-dessus suffisantes pour commencer le moteur, les migrations préparatoires et les tests. Question à ne remonter que si nécessaire au fonctionnement, sans reposer les arbitrages existants.
