# Livraison #135 — acquisition et Banque Nationale

## Statut et responsabilité d’installation

Lot L11/L04 codé et éprouvé sur PostgreSQL jetable, **pas installé en production**. Branche `codex/stabilisation-luthecia-135-20261024`. Le SHA exact du lot se lit dans le commit portant ce document. Aucun joueur réel utilisé, aucun solde réel modifié. L’agent principal assure prévol final, installation Supabase, réextraction officielle, PR/fusion et Vercel ; aucune manipulation demandée au propriétaire.

Source de compatibilité : prévol réel `980146185e29285335958a3c46e8350be0b6672e`, 22 définitions conservées sans changement dans `outils/bancs/fixtures/prevol-135-fonctions.json`. Ce fichier est une photographie datée, pas une attestation que la production n’a pas évolué depuis.

## Comportement livré

Les quatre étapes dépôt, compromis, acte direct et acte sous compromis empruntent `terrain_acquisition_commande`. Le navigateur fournit une intention et un UUID, jamais prix, superficie, titre ou montant à débiter. Les caractéristiques propres à chaque parcelle sont conservées ; surface absente => refus explicite, aucune valeur inventée. Les réservations concurrentes sérialisent le terrain. Paiement, réservation/titre, archive de vente, document de permis joint et reçu sont dans la même transaction. Le dépôt de 1 000 FR est imputé une fois : exemple 25 800 FR, puis 24 800 FR au notaire.

Le permis joint conserve les 2 PA/1 000 FR historiques de la signature : moteur `terrain_permis_deposer` existant, même archive et SAS, pas de moteur documentaire ni paiement supplémentaire. Le permis autonome conserve ses 1 PA/100 FR.

Le financement immobilier emploie le bloc de crédit réel extrait du prêt national vivant : dette + reçu unique de crédit + compte national + miroir financier. Il reste distinct de travaux. La règle d’acceptation du compromis et son échéance sont conservées. Une demande encore en attente ne signifie pas que l’argent a déjà été versé. Les anciens financements marqués accordés ne sont jamais recréés/recrédités. Un refus de financement restitue réellement le dépôt par le moteur financier, pas par un remboursement navigateur.

Prêt consommation : règles déjà présentes dans `TYPES_PRET` et son formulaire, 1 000–10 000 FR entiers, 12 %, 5/10/15/20/25/30 jours. Travaux : 1 000–1 000 000, durées 10/15/20/25/30, compte national et guichet de Républia, un prêt actif par type. Immobilier du compromis : plafond historique 150 000, jours entiers positifs et taux national capturé à la signature, aucune durée maximale inventée. Le taux capturé est conservé dans le reçu privé, pas accepté du navigateur. Helvetia et placements restent distincts et ne financent aucune dépense ordinaire automatique.

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

La nouvelle façade de prêt du fichier 2 référence à l’exécution les capacités créées au fichier 3 : ne pas appeler cette RPC entre les deux installations. L’ensemble est testé deux fois pour son idempotence.

Gardes sur les corps vivants : prêt national `8a08c4561a32f8eafb3c03429fa63b38`, payeur `9a461bfc3c33f04f342ce6f5586393a7` ou sa transformation exacte du lot réaménagement 17, compromis `17e26d10e1fb5585d5f5e60a0e816b68`, mutation `df5c90d592cc16812eb0d139d8ead87b`, résolution `d3e35ecf0edb0b1c2a6858f5ad6f1b81`, permis PR112 `fe477be60c077cee84331a80426dc22b`. Les gardes acceptent également exclusivement leur propre résultat pour le rejeu. Toute autre définition => arrêt et comparaison, jamais élargissement pour faire passer. Les nouvelles fonctions refusent aussi une définition homonyme inconnue.

Après le serveur seulement, déployer le client et le cron de ce commit : `plateau-terrain-banque.js`, adaptateurs `plateau-pnj.js`, `plateau-justice-economie.js`, `plateau-construction-commandes.js`, `plateau.html`, `api/cron-minuit.js`. L’ancien client voit un refus sans débit sur les commandes fermées jusqu’au déploiement du nouveau. Le maintenir durablement avec le nouveau serveur n’est pas compatible ; coordonner la fenêtre d’installation. Ne pas déployer d’abord le nouveau client.

## Objets et fermetures à contrôler

RPC authenticated : `terrain_acquisition_commande(text,text,jsonb,uuid)`, `pret_national_contracter_versionne(numeric,integer,text,text,uuid)`, `finance_terrain_banque_recu(uuid,text)`. RPC échéance `pret_national_jour_traiter(text)` : service_role seulement + vérification serveur interne. Moteur privé `pret_national_creer_interne(text,numeric,integer,text,text,text,numeric)` inaccessible aux clients/service_role directement. Tables privées avec RLS et droits révoqués : `acquisitions_transactions_internes`, `terrain_acquisitions_recus`, `prets_ecritures_internes`, `prets_nationaux_demandes`, `terrains_referentiel`.

L’ancienne façade à quatre arguments est conservée mais refuse avant tout effet (`commande_versionnee_requise`). Les anciens paiements génériques d’achat/signature/acte/prêt et les primitives de réservation ou mutation d’acquisition exigent la capacité transactionnelle privée. Les autres mutations légitimes et les gardes de permis/location existantes restent en place. La modification isolée d’une demande de prêt non-Helvetia est fermée : la clause est enregistrée par la signature complète. Trigger `pret_versionne_ecriture` (`pret_versionne_ecriture_proteger`) : vérifier sa présence et les permissions de sa fonction ; une sauvegarde périmée ne doit pas modifier un contrat versionné.

Après application autorisée : relever signatures, `proconfig`, ACL, RLS, triggers et registre ; vérifier les colonnes historiques, volumes métier avant/après (aucune écriture métier des migrations), puis exécuter les quatre exports officiels `requetes.py`, `rendre.py`, `seeds.py`, lire les différences et relancer les contrôles. Aucun SQL généré retouché à la main. Sur tout doute de prévol, arrêter l’installation sensible ; ne pas supprimer des données pour la faire passer.

## Preuves et limites

`banc-terrain-banque-135-local.py` charge les vrais corps du prévol et les tables du baseline dans PostgreSQL jetable. 42 assertions nouvelles et 59 de négociation conservées : titre et 25 800 FR concordants, deux acquéreurs concurrents, refus sans fonds ou terrain occupé, expiration, UUID détourné, injection après débit avant titre, injection après crédit avant titre, rollback dette/fonds/archives/reçu, prêt réel/rejeu, remboursement de dépôt réel/rejeu, permis joint archive/SAS, échéances concurrentes du jour suivant sans sommeil, sommeil sans nouvelle échéance et solde exact 1 120 FR.

Le changement de jour est simulé en datant la dernière échéance à hier dans la fixture jetable, pas en modifiant l’horloge de production. Les identités, notifications et contexte d’authentification annexes sont fictifs. Cela ne vaut pas parcours authentifié Supabase ou test du cron Vercel vivant.

`banc-terrain-banque-reprise-135.cjs` : sept scénarios d’incertitude/réponse tardive/rechargement. `banc-mutation-terrain.js` : 47 assertions adaptées aux vrais adaptateurs ; les garanties financières passent désormais aussi par PostgreSQL plutôt que par un patch JSON client. Les quatre mutants terrain ont été portés, pas retirés : les 91 contre-épreuves restent vertes.

Le contrôleur client complet passe 108/108. Les 31 bancs PostgreSQL du workflow passent tous ; journaux structurés `luthecia-20261024/TERRAIN-BANQUE-*`. Les contrôles globaux restent publiés séparément, sans assimilation aux tests métier. Aucune affirmation de consommation facturée, de déploiement ni de succès authentifié. L09 bénédiction reste un lot distinct : ce lot bancaire n’en dépend pas et ne prétend pas corriger ses jets historiques.
