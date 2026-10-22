# Livraison autonome du 22 octobre 2026

**CHANTIER NON TERMINÉ. Aucune activation des migrations sensibles autorisée par ces résultats.**

Ce rapport complète `FINALISATION-57-69-20261022.md` et `COFFRES-SUCCESSIONS-69.md`. Résultats détaillés : `RESULTATS-LIVRAISON-AUTONOME-20261022.json`. Les mesures précédentes restent des étapes datées, pas des résultats du dernier passage.

## Intégration indépendante réellement livrée

Les seuls changements envoyés par cette intervention sur `main` sont `b5d9ede` (installer les dépendances Playwright avant les bancs client) et `5e38aaa` (régression sur cet ordre d'installation). Aucun fichier métier ou migration dans ce lot. Les deux GitHub Actions de `5e38aaa` sont réellement SUCCESS : [cohérence](https://github.com/FredJ74/res-publica/actions/runs/39797456206), [payload](https://github.com/FredJ74/res-publica/actions/runs/39797456325).

Les PR #75, #76, #77 et #78 n'ont pas été fusionnées en bloc. Les feuilles utiles de #77/#78 ont été examinées séparément ; leurs branches transportaient aussi la consolidation. #76 ne fournit qu'une proposition documentaire de vue dont la définition vivante n'a pas pu être obtenue : aucun SQL déployé sur cette base.

Les changements concurrents `4fa7625`, `95e3eb9`, puis `7da060f` ont été intégrés **de main vers la branche de travail**, pas l'inverse. Les Actions de `95e3eb9` sont également SUCCESS, ce qui ne démontre pas une visite authentifiée en jeu. Le parcours bancaire unique de main est conservé dans le moteur commun déjà préparé : relecture obligatoire comptes/placements, formulaire unique, commande atomique avec reçu. L'ancien ordre investir demeure masqué dans le catalogue technique pour conserver son coût, sans deuxième bouton ni deuxième débit. Une relecture impossible conserve l'intention à réconcilier.

Les conversions WebP et la décoration premium déjà livrées sont préservées. Les huit originaux Krasnov sont inchangés ; seules leurs huit URL PNG sont exclues du payload de la branche, sans exclure un futur WebP du répertoire.

## Construction #57 : préparée, non activée

- Les quatre pays actuels sont non P2W. Refus d'accélération avant débit côté client et serveur ; contre-épreuve réintroduisant un débit interdit conservée.
- Journée de chantier, financement commun PJ/organisation/commune, appels 35/35/30, approvisionnement et rémunération restent transactionnels dans le moteur préparé. La commune conserve ses droits au changement de maire.
- Commandes avec reçu, planification, travail et prix entiers, réception sur place et conservation des matériaux sont testés localement. 62 assertions du banc construction passent.

**À terminer dans le code :** permis sous compromis et ses contreparties ; occupation/squatteurs, combat et sécurité communs ; fermeture/raccordement de toutes les anciennes portes `terrain_lots_acte` et `terrain_reamenagement_poser` ; validation de la chaîne complète avec le financement #65 et l'autorité des organisations. Ces absences ne sont pas attribuées uniquement au manque d'accès distant. Ce lot n'est pas une construction complète prête à activer.

## Coffres #69 : code et tests préparés

Le parcours Luthécia Banque nationale réutilise louer_local/gerer_local, payer_ordre, les loyers, l'extraction d'inventaire et la résiliation existants.

- Souscription initiale : 1 PA et annuité dans une transaction, dérivation du propriétaire depuis l'UID authentifié, aucun coffre/bail/débit partiel en cas de refus.
- Offres S50/250, M100/450, L150/750, XL400/1250 FR/an. Une unité par exemplaire ou unité empilable ; fractions refusées.
- Dépôts/retraits privés et versionnés, métadonnées et identifiants conservés, limites serveur et conflits concurrents vérifiés.
- Redimensionnement immédiat, différence entre tailles successives, pas de prorata/crédit/remboursement, réduction sous capacité refusée et anniversaire conservé.
- Renouvellement dans le calendrier et la perception communs : banque avant liquide, aucun débit partiel, annuités échues sans duplication quotidienne, arriéré figé et conservation des objets lors d'impayés. Gestion du 29 février testée.
- Le cron utilise un verdict de paiement détaillé pour ces baux : montant réellement débité plutôt que tarif futur après changement de taille. Aucun repli provoquant un second prélèvement en cas de réponse incertaine. Suppression du faux journal client de loyer quotidien pour les coffres annuels.
- Résiliation uniquement à vide, confidentialité des baux et contenus, reçus de commandes et reprise F5 sans nouvelle dépense. Les transferts relisent l'inventaire courant au lieu d'adopter un ancien reçu.

Le vieux parcours hors périmètre Luthécia n'est pas converti automatiquement en contrat annuel. La migration refuse les anciens baux Luthécia non repris : aucune conversion silencieuse de données réelles.

### Blocage successoral démontré localement

Le banc `banc-coffres-autorite-succession-local.py` reconstruit les vrais droits et policies archivés de `successions`, avec un tiers authentifié fictif. Ce tiers peut modifier les dispositions/bénéficiaires d'un autre dossier. La transaction de démonstration est annulée et la base jetable détruite. **Le banc échoue ; il n'est pas déclaré réussi parce que l'attaque a été reproduite.** Il est bloquant dans le workflow de la branche.

Cela démontre un défaut du schéma archivé, pas l'état d'une production inaccessible. Un contrôle du catalogue vivant et un raccordement sécurisé des choix successoraux au moteur commun restent indispensables ; un simple filtre sur le propriétaire du dossier ne suffit pas à sécuriser chaque disposition. Le transfert successoral des coffres reste fermé. La garde de suppression du défunt conserve les coffres mais ne constitue pas une succession achevée ; elle empêche aussi de considérer le scénario sans héritier comme terminé. Ne pas activer les coffres tant que ce parcours commun n'est pas sécurisé et testé de bout en bout.

## Vérifications finales

| Vérification locale | Résultat |
|---|---|
| Contrôleur client complet | 109/109 bancs |
| Contre-épreuves | 90/90 |
| Workflow PostgreSQL jetable | 27/28 ; échec réel de l'autorité successorale |
| Coffres, stockage/annuités/contrats/verdicts | 103/103 assertions |
| Client coffres et Chromium réel avec RPC simulées | 11/11 tests |
| Cron coffres | 5/5 tests |
| Parcours bancaire commun après intégration concurrente | 8/8 tests |
| Pilote E2E, fixtures sans compte réel | 69/69 |
| Calendrier | 5/5 |
| Analyseur API | 23/23 modules |
| SQL préparé du 22 octobre, prévol, YAML | Analyse syntaxique valide |
| Décoration premium WebP | Conforme |
| Payload simulé de branche | 256,5 Mo / 330 Mo |
| Baseline global | 10/12 contrôles |

Authority : une signature renommée absente de l'analyse des migrations (`rue_position_enregistrer_moteur_20261021(text)`), et 46 appels RPC absents du baseline, comprenant les nouvelles commandes non déployées. Referential : trois dérives historiques `ordres_couts`, `postes_nommes_regles`, `miroirs_entreprises`. Aucun baseline généré, empreinte ou observation historique modifié pour obtenir un succès. Les contrôles de fonctions utilisent ici l'adaptateur Node local du lanceur historique, pas JavaScriptCore natif.

## Prévol et livraison encore nécessaires

1. Obtenir le catalogue vivant par accès autorisé en lecture seule et exécuter `outils/bancs/prevol-finalisation-57-69.sql` : définitions/droits/RLS/triggers, acteurs, miroirs, baux historiques, stocks et inventaires. Relever les dépendances effectives, sans rejouer les migrations déjà appliquées.
2. Terminer les portes construction et le moteur successoral commun décrits ci-dessus ; refaire les contre-épreuves et faire passer les préconditions critiques. Vérifier le comportement des baux historiques et tous les propriétaires/destinataires financiers ; ne pas élargir le périmètre actuellement fermé sur une destination non prise en charge.
3. Sur une copie isolée représentative, appliquer les dépendances puis les migrations préparées dans l'ordre de version, vérifier les gardes de définition et les parcours complets. Les gardes ne sont pas une autorisation de rejouer une ancienne migration sur une fonction modifiée par un fichier ultérieur.
4. Conserver un relevé intègre des données et définitions avant activation, tester rollback transactionnel et concurrence. Préparer la réversibilité fonctionnelle : fermer les nouvelles commandes sans supprimer les contrats/objets/reçus, puis correction en avant. Ne jamais restaurer un ancien snapshot financier sur les transactions intervenues depuis.
5. Seulement après prévol conforme : activation SQL coordonnée avec client/cron, tests authentifiés isolés, conservation des inventaires/livraisons/baux, contrôle Vercel et parcours réels. Comparer les consommations réelles avant/après ; le payload local ne mesure pas le trafic Supabase facturé.

Les connexions HTTPS Supabase et Vercel sont actuellement refusées au proxy (CONNECT 403), avant accès au service. Aucun connecteur correspondant exposé. L'API GitHub authentifiée est aussi refusée ; lecture publique des Actions et push Git disponibles. Aucun test authentifié ni état Vercel READY de ces nouveaux commits confirmé. **Aucune migration de production appliquée, aucune donnée joueur modifiée.** Aucun nouvel arbitrage de game design nécessaire ; les blocages restants sont techniques.

Travail sauvegardé sur `codex/finalisation-construction-coffres-20261022` par commits réguliers. Ne pas fusionner cette branche de consolidation en bloc. Les lots sensibles restent codés/testés partiellement, non fusionnés et non déployés ; la correction CI indépendante est seule intégrée à main par cette intervention.
