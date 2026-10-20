# Construction — issue #57, inventaire avant modification

Branche depuis main `baa9cb7`, indépendante de la PR #56 ; aucun déploiement autorisé.
Source des décisions : `ISSUE-57-ARBITRAGES.md` et précisions du propriétaire dans la conversation.

## Lot 1 — inventaire et écarts

Existant réutilisé : registre `RP_ORDRES_DYNAMIQUES` et son champ `masque`, routeur `doOrder`, dossier État civil `ouvrirEtatCivil`, chargement terrain `chargerTerrainState`, demandes/documentation `doDeposerDemandePermis`, `confirmerDepotPermis`, `verdictNouvelleDemandePermis`, `emettreDocumentUrbanisme`, illustrations `NIVEAUX_CONSTRUCTION` et onglets d'`hydraterPiecesDynamiques`.

Écarts : ancien formulaire initial de plan ; dépôt réservé au propriétaire ; coût déclaré 2 PA/0 FR ; instruction building 10 jours ; cadastre client classant les autres pays comme Républia ; quatre surfaces PSM absentes malgré descriptions 1500 m² ; achat utilisant surface de repli 2000 ; salles initiales nommées terrain, terrain2, terrain8…

Image examinée : `images/terrain-a-vendre-republic.webp`, véritable friche avec panneau À VENDRE, conservée sans retouche. La priorité du rendu est modifiée seulement pour les terrains nus de Républia, sans toucher aux scènes de rues ni aux bâtiments construits.

Les superficies/prix sont des données propres à chaque parcelle, pas une formule liée à son numéro. Les superficies persistantes et valeurs d'achat existantes restent prioritaires. Les prix explicitement déclarés sont conservés, dont PSM 3500 FR ; aucune conversion générale à 12 FR/m² n'est appliquée. Surface 6 historiquement indéterminée : achat bloqué avant débit. Les lots 6/7 des autres empires n'ont pas de surface typée non plus. Aucun inventaire vivant accessible pour compléter ces références.

Porte serveur à traiter avant activation : `terrain_permis_acte` archivée n'accepte que le propriétaire et ne fait pas le débit/documents atomiquement. Son parcours historique archiver → débit → mutation est un écart confirmé ; la modification UI seule ne le résout pas. Le miroir de coûts doit être synchronisé après une migration validée, jamais falsifié dans baseline.

## Lot 2 — inventaire préalable

`TERRAIN_PNJ_PROFILES` contient profils, personnalités et images ; `genererPnjTerrain` tirage pondéré par indices ; `chargerPnjTerrain` génération client/persistance et sessionStorage ; `terrain_occupation_generer/liberer/police` côté serveur. Négociation, police, dissimulation et traces existent dans `plateau-pnj.js`. Combat : `ouvrirModalAssassinat`, `confirmerAssassinatArme`, modes/armes et PA communs ; branche PNJ député attestée par RPC dédiée ; `militaire_taux_combat`/degré ne sont pas des RPC de combat civil interchangeables.

Écarts à traiter : huit profils potentiels au lieu des quatre situations équiprobables ; génération de nouveau PNJ sur simple absence de cache sans visite vide attestée ; occupations non figées après acquisition ; aucun ordre de neutralisation des squatteurs branché au combat commun ; vérifier autorité serveur avant d'accepter un jet reçu du navigateur. Ne pas appeler une RPC d'Assemblée avec un faux siège ni créer un combat parallèle.

## Lot 3 — inventaire préalable

Moteur commun : `plateau-chantiers.js` (30/60/90/120k, 6/12/18/24 jours, 35/70/100 %, matériaux 30 %, travail 70 %, 50 h/jour et 70 FR/h). RPC existantes `chantier_lancer`, `chantier_verser`, `chantier_travailler`, `approvisionner_chantier`, `vendre_materiaux_chantier`. Cron `avancerChantiersQuotidien` réalise plusieurs écritures REST séparées. `helvetia_debiter_fonds_ordinaires` débite espèces avant banque ; `payer_ordre` vérifie son miroir. Prêt national appelé mais définition non retrouvée dans le baseline ; Helvetia a son circuit distinct.

Écarts : prélèvements manuels et non idempotents ; ordre banque/espèces contraire à l'apport demandé ; aucune atomicité globale du cron ; prix fournisseur libre sans prix propriétaire ; `personnages.arg/liquide` et comptes bancaires entiers dans l'archive, incompatible avec +10 % de 5,50 FR = 6,05 FR. La branche financière existante est à lire, pas à fusionner aveuglément ; aucune conversion monétaire générale à imposer ici. Pas de compensation historique.

## Lot 4 — inventaire préalable

Plan : `verdictModificationPlan`, `planEstVerrouille`, `appliquerVerrouPlan`, éditeur `doModifierPlanChantier` et RPC `terrain_permis_acte`. Livraison : `livrerChantier`/version cron, `appliquerReconfiguration`, RPC `restituer_reliquats_chantier`. Réaménagement : 10 FR/m² et 300 m²/j, baux protégés. Lots/onglets : `plateau-immobilier.js`, moteur de baux et commerce existant.

Écarts : ancien verrou au début du dernier tiers au lieu d'y ouvrir l'édition ; livraison automatique et reliquats au PJ ; pas de réception sur place ; absence de flag distinct de plan initial validé. La réception doit être autoritaire et atomique avec transfert des reliquats aux mécanismes de caisse/stock existants, pas un simple booléen client.
