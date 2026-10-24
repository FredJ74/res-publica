# Livraison #135 — acquisition et Banque Nationale

## Statut et responsabilité d’installation

Lot L11/L04 codé et éprouvé sur PostgreSQL jetable, **pas installé en production**. Branche `codex/stabilisation-luthecia-135-20261024`. Premier lot poussé : `17d99f1` ; intégration du main `3b01469` : `d347cdb`. Durcissement complémentaire poussé : `11ebd80`. Aucun joueur réel utilisé, aucun solde réel modifié. L’agent principal assure prévol final, installation Supabase, réextraction officielle, PR/fusion et Vercel ; aucune manipulation demandée au propriétaire.

Source de compatibilité : prévol réel `980146185e29285335958a3c46e8350be0b6672e`, 22 définitions conservées sans changement dans `outils/bancs/fixtures/prevol-135-fonctions.json`. Ce fichier est une photographie datée, pas une attestation que la production n’a pas évolué depuis.

## Comportement livré

Les quatre étapes dépôt, compromis, acte direct et acte sous compromis empruntent `terrain_acquisition_commande`. Le navigateur fournit une intention et un UUID, jamais prix, superficie, titre ou montant à débiter. Les caractéristiques propres à chaque parcelle sont conservées ; surface absente => refus explicite, aucune valeur inventée. Les réservations concurrentes sérialisent le terrain. Paiement, réservation/titre, archive de vente, document de permis joint et reçu sont dans la même transaction. Le dépôt de 1 000 FR est imputé une fois : exemple 25 800 FR, puis 24 800 FR au notaire.

Le permis joint conserve les 2 PA/1 000 FR historiques de la signature : moteur `terrain_permis_deposer` existant, même archive et SAS, pas de moteur documentaire ni paiement supplémentaire. Le permis autonome conserve ses 1 PA/100 FR.

Le financement immobilier emploie le bloc de crédit réel extrait du prêt national vivant : dette + reçu unique de crédit + compte national + miroir financier. Il reste distinct de travaux. La règle d’acceptation du compromis et son échéance sont conservées. Une demande encore en attente ne signifie pas que l’argent a déjà été versé. Les anciens financements marqués accordés ne sont jamais recréés/recrédités. Un refus de financement restitue réellement le dépôt par le moteur financier, pas par un remboursement navigateur.

Prêt consommation : règles déjà présentes dans `TYPES_PRET` et son formulaire, 1 000–10 000 FR entiers, 12 %, 5/10/15/20/25/30 jours. Travaux : 1 000–1 000 000, durées 10/15/20/25/30, compte national et guichet de Républia, un prêt actif par type. Immobilier du compromis : plafond historique 150 000, jours entiers positifs et taux national capturé à la signature, aucune durée maximale inventée. Le taux capturé est conservé dans le reçu privé, pas accepté du navigateur. Helvetia et placements restent distincts et ne financent aucune dépense ordinaire automatique.

Les migrations 10/11 imposent en plus la relecture du prix, du dépôt, du montant, de la durée et du taux dans les reçus privés. Une ancienne primitive de modification du JSON ne peut donc pas obtenir un titre gratuit ni gonfler un crédit. Les réservations historiques sans version 2 restent traitées selon leur circuit existant : le lot ne les atteste pas rétroactivement.

Les nouveaux contrats portent `contrat_version=2` ; aucune ligne historique n’est mise à jour par les migrations. Leur échéance atomique utilise la date commune Europe/Paris, débite au plus le reliquat, puis actualise la dette dans la même transaction. Le cron appelle cette porte uniquement pour ces contrats nationaux ; les contrats historiques et Helvetia gardent leur circuit. Les impayés historiques J1/J2(+10 %)/J3/J4 sont conservés, la saisie ne peut prendre le terrain d’un autre propriétaire. Les écritures directes des dettes versionnées sont interdites hors moteur.

Le client conserve l’UUID avant envoi et après réponse incertaine, y compris F5. Rejeu => aucun deuxième débit/crédit, puis relecture financière et terrain actuels. Un refus métier relit aussi l’état. Le changement de personnage invalide une réponse tardive. Aucun polling ajouté. Les reprises par lecture de reçu ne déclenchent aucune nouvelle mutation.

## Ordre exact d’installation — bloc indivisible avant le client

Ne pas jouer tout le répertoire migrations. Vérifier le registre et sélectionner les absentes. Chaque fichier a sa transaction ; durant l’installation, ne pas exposer un groupe partiel au client.

Préconditions : moteurs d’autorité/personnage, fonds ordinaires, crédit unique, permis PR112 (`20261022220516_permis_depot_transactionnel.sql`), archive/SAS, compromis et titres déjà présents. Référentiel privé des pays `20261024072349_occupation_actions_et_echeances.sql` requis pour les indices hors Républia ; vérifier aussi ses dépendances PR134. Si le lot réaménagement est sélectionné, installer ses migrations jusqu’à `20261023090017` avant le présent groupe. Ne pas importer coffres/successions/ventes indépendants.

1. `20261024121400_prets_nationaux_moteur_credit_commun.sql`
2. `20261024121900_prets_nationaux_commandes_versionnees.sql`
3. `20261024122600_acquisitions_capacites_et_gardes.sql`
4. `20261024123500_compromis_financement_reel.sql`
5. `20261024123600_terrains_referentiel_acquisition.sql`
6. `20261024123700_terrain_acquisition_commandes.sql`
7. `20261024123800_terrain_banque_relecture_recus.sql`
8. `20261024124000_prets_nationaux_echeances_atomiques.sql`
9. `20261024124100_prets_versionnes_fermer_ecritures_directes.sql`
10. `20261024131720_acquisitions_depots_attestes.sql`
11. `20261024132140_financement_compromis_termes_attestes.sql`
12. `20261024133310_terrain_vente_archive_reference_acte.sql`
13. `20261024134528_permis_instruction_transactionnelle_acquisitions.sql`
14. `20261024135353_acquisition_refus_rollback_financement.sql`

La nouvelle façade de prêt du fichier 2 référence à l’exécution les capacités créées au fichier 3 : ne pas appeler cette RPC entre les deux installations. Chaque migration est exécutée immédiatement deux fois pour son idempotence ; ne pas rejouer une ancienne définition après les durcissements 10/11/12.

Gardes sur les corps vivants : prêt national `8a08c4561a32f8eafb3c03429fa63b38`, payeur `9a461bfc3c33f04f342ce6f5586393a7` ou sa transformation exacte du lot réaménagement 17, compromis `17e26d10e1fb5585d5f5e60a0e816b68`, mutation `df5c90d592cc16812eb0d139d8ead87b`, résolution `d3e35ecf0edb0b1c2a6858f5ad6f1b81`, permis PR112 `2e0c9a32aa2b9c71b47fbc961caa9f01` (définition de la migration PR112 ; cette RPC ne figure pas parmi les 22 corps du relevé, son empreinte vivante doit donc encore être contrôlée). Les gardes acceptent également exclusivement leur propre résultat pour le rejeu. Toute autre définition => arrêt et comparaison, jamais élargissement pour faire passer. Les nouvelles fonctions refusent aussi une définition homonyme inconnue.

Après le serveur seulement, déployer le client et le cron de ce commit : `plateau-terrain-banque.js`, adaptateurs `plateau-pnj.js`, `plateau-justice-economie.js`, `plateau-construction-commandes.js`, `plateau.html`, `api/cron-minuit.js`. L’ancien client voit un refus sans débit sur les commandes fermées jusqu’au déploiement du nouveau. Le maintenir durablement avec le nouveau serveur n’est pas compatible ; coordonner la fenêtre d’installation. Ne pas déployer d’abord le nouveau client.

## Objets et fermetures à contrôler

RPC authenticated : `terrain_acquisition_commande(text,text,jsonb,uuid)`, `pret_national_contracter_versionne(numeric,integer,text,text,uuid)`, `finance_terrain_banque_recu(uuid,text)`. RPC échéance `pret_national_jour_traiter(text)` : service_role seulement + vérification serveur interne. Moteur privé `pret_national_creer_interne(text,numeric,integer,text,text,text,numeric)` inaccessible aux clients/service_role directement. Tables privées avec RLS et droits révoqués : `acquisitions_transactions_internes`, `terrain_acquisitions_recus`, `prets_ecritures_internes`, `prets_nationaux_demandes`, `terrains_referentiel`.

L’ancienne façade à quatre arguments est conservée mais refuse avant tout effet (`commande_versionnee_requise`). Les anciens paiements génériques d’achat/signature/acte/prêt et les primitives de réservation ou mutation d’acquisition exigent la capacité transactionnelle privée. Les autres mutations légitimes et les gardes de permis/location existantes restent en place. La modification isolée d’une demande de prêt non-Helvetia est fermée : la clause est enregistrée par la signature complète. Trigger `pret_versionne_ecriture` (`pret_versionne_ecriture_proteger`) : vérifier sa présence et les permissions de sa fonction ; une sauvegarde périmée ne doit pas modifier un contrat versionné.

Après application autorisée : exécuter `outils/bancs/prevol-terrain-banque-135.sql` (agrégats, aucun acte métier), relever signatures, `proconfig`, ACL, RLS, triggers et registre ; vérifier les colonnes historiques, volumes métier avant/après (aucune écriture métier des migrations), puis exécuter les quatre exports officiels `requetes.py`, `rendre.py`, `seeds.py`, lire les différences et relancer les contrôles. Aucun SQL généré retouché à la main. Sur tout doute de prévol, arrêter l’installation sensible ; ne pas supprimer des données pour la faire passer.

## Preuves et limites

`banc-terrain-banque-135-local.py` charge les vrais corps du prévol et les tables du baseline dans PostgreSQL jetable. 58 assertions nouvelles et 59 de négociation conservées : titre et 25 800 FR concordants, deux acquéreurs concurrents, refus sans fonds ou terrain occupé, expiration, UUID détourné, injection après débit avant titre, injection après crédit avant titre, rollback dette/fonds/archives/reçu, prêt réel/rejeu, remboursement de dépôt réel/rejeu, permis joint archive/SAS, échéances concurrentes du jour suivant sans sommeil, sommeil sans nouvelle échéance et solde exact 1 120 FR.

Le changement de jour est simulé en datant la dernière échéance à hier dans la fixture jetable, pas en modifiant l’horloge de production. Les identités, notifications et contexte d’authentification annexes sont fictifs. Cela ne vaut pas parcours authentifié Supabase ou test du cron Vercel vivant.

`banc-terrain-banque-reprise-135.cjs` : sept scénarios d’incertitude/réponse tardive/rechargement. `banc-mutation-terrain.js` : 47 assertions adaptées aux vrais adaptateurs ; les garanties financières passent désormais aussi par PostgreSQL plutôt que par un patch JSON client. Les quatre mutants terrain ont été portés, pas retirés : les 91 contre-épreuves restent vertes. Six contre-épreuves PostgreSQL supplémentaires confirment que le banc rougit si le prix public remplace le reçu, si le crédit bancaire n’est plus versé, si le rejeu bancaire est retiré si la garde des dettes est désactivée ou si deux ventes du même jour entrent en collision dans l’archive, ou si l’instruction peut prendre deux journées dans le même jour Paris. Les cas positifs falsifient volontairement prix/acompte et montant/durée du financement : seuls les termes privés payés/capturés sont appliqués.

Le contrôleur client complet passe 109/109 après ajout du banc cron des permis. Les 31 bancs PostgreSQL du premier lot passent tous ; le workflow enrichi compte 33 configurations natives, également vertes. Le banc bancaire final est aussi relancé avec la garde location installée avant lui ; journaux structurés `luthecia-20261024/TERRAIN-BANQUE-*`. Les contrôles globaux restent publiés séparément, sans assimilation aux tests métier. Aucune affirmation de consommation facturée, de déploiement ni de succès authentifié. L09 bénédiction reste un lot distinct : ce lot bancaire n’en dépend pas et ne prétend pas corriger ses jets historiques.

La migration 12 conserve la référence de l’acte dans l’identifiant d’archive de vente : deux acquisitions légitimes du même terrain par le même acheteur le même jour restent distinctes, tandis que le rejeu d’un acte ne crée rien. Le courrier de rendez-vous direct est rétabli côté serveur, après l’acte et avant son reçu, sans double envoi au rejeu ; la doctrine existante conserve l’achat même si le service de notification signale son échec.

Validations complémentaires : les 45 assertions du banc cron couvrent aussi l’absence absolue de PATCH legacy pour un contrat versionné, y compris réponse absente/refus/rejeu. Le pilote E2E passe 69 tests sur fixtures locales et les 11 tests complémentaires jours civils/fontaine/placements passent ; aucun personnage réel. Les globaux sont à 6/12 (journal `TERRAIN-BANQUE-GLOBAUX.txt`), dont Authority et Referential toujours rouges. Le baseline est inchangé par rapport au main 3b01469.

Retour arrière : conserver les contrats versionnés, leurs reçus et leur traitement atomique. Ne pas revenir au cron REST pour ces contrats ni supprimer les colonnes/tables pour forcer un ancien client. En incident, suspendre l’exposition des nouvelles commandes puis diagnostiquer et corriger en avant ; un ancien client est refusé avant paiement par les gardes. Toute restauration de code serveur doit être examinée avec les contrats effectivement créés, jamais par effacement des données métier.

## Complément instruction et accord tacite — après les douze migrations

Le cron historique d’instruction réécrivait tout le terrain à partir d’une lecture antérieure : une acquisition commise pendant ses appels pouvait disparaître. L’instruction est déplacée dans la transaction `terrain_permis_instruction_jour(text)` (service_role seulement). Le cron l’appelle pour les permis actifs, sans envoyer ni réécrire de blob. Même compteur Europe/Paris, même durée et suspensions, même accord tacite ; aucun délai nouveau. Archive, SAS et décision sont dans la transaction, notification par le moteur existant. Les fonctions pures historiques sont conservées pour leurs vérifications de règles, pas comme moteur d’écriture parallèle.

**Installer la migration 13 avant ce nouveau cron.** Requiert dossiers_urbanisme, objet_sas_deposer, mail_systeme_poser_interne, est_appel_serveur et les données réelles des permis. Le prévol complémentaire dans `prevol-terrain-banque-135.sql` doit constater zéro dossier actif incomplet et aucune durée absente avant activation. Si une ancienne demande manque de numéro/demandeur/ville/durée, arrêter cette activation et examiner la donnée ; aucun remplissage inventé. Le nouveau moteur refuse ces cas explicitement plutôt que d’accorder une autorisation sans dossier concordant.

Tests natifs additionnels : jour suivant sans sommeil, reprise le même jour, accord et attestation persistants uniques, panne SAS annulant aussi archive/compteur/autorisation, préservation de changements faits après le relevé cron. Le banc `banc-permis-cron-acquisition-135.cjs` vérifie qu’aucun PATCH ni blob ne subsiste même sur réponse perdue ou refus. Cela ne constitue pas un test authentifié Supabase.

La migration 14 corrige aussi le refus métier après décision du prêt dans la même commande : un manque de PA au paiement final renvoie le refus après rollback du crédit, de la dette et de la décision du prêt. Le même UUID peut réussir ensuite si les PA sont disponibles, sans second financement. Les erreurs techniques injectées restent des erreurs ; elles ne sont pas transformées en réussite. Le traitement autonome séparé du compromis reste conservé.
