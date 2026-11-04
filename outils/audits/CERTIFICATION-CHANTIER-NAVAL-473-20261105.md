# Chantier naval PSM #473 — certification corrective du 5 novembre 2026

**NON LIVRÉ EN PRODUCTION.** Branche `codex/certification-chantier-naval-473-20261105`,
issue du merge #473 `dcf1dff9` (livraison initiale `11d819b3`), réconciliée avec
`main` `1d1e36e5`. Aucun joueur réel, aucune écriture distante, aucune migration appliquée.

## Défauts reproduits et corrections

- Sur PostgreSQL jetable, l'ancienne commande accepte réellement une position rue
  `current_building=NULL` et débite l'acompte. La contre-épreuve est annulée. Le test
  corrigé refuse cette position avant toute mutation (`IS DISTINCT FROM`). Une nonce
  déjà utilisée ne peut pas être rejouée avec un modèle NULL ou différent.
- L'écran utilisait une intention indexée par modèle seulement et n'adoptait pas le
  paiement courant. Il utilise maintenant `executerReceptionInventaire`, le pilote
  commun existant : intention liée à l'identité, double clic, session, réponse perdue
  et adoption de la réponse serveur. Aucun bateau ni delta financier créé à l'écran.
  Le serveur renvoie l'inventaire inchangé et le paiement courant, aussi au rejeu.
- Les consultations abandonnent leurs réponses si le personnage, la session ou le lieu
  ont changé. Les erreurs de transport et de session ne deviennent pas un faux refus métier.
- La journée exige le contexte serveur, refuse les dates futures/rétrogrades, exclut
  la réserve militaire et refuse les prix invalides. Le prix signé reste fixe.
- Le cron appelle le même moteur après les transits **et** l'approvisionnement et la
  transformation industrielle, explicitement sous l'identité service. Le résultat
  naval figure dans son bilan. Aucun calendrier ni transport public remplacé.
- Les nouveaux contrats conservent la trace de l'acompte et de chaque journée. Les
  sorties de matière portent la référence du contrat dans le journal commun.
  Aucun historique ancien n'est fabriqué : la colonne ajoutée vaut `[]` pour l'existant.
- Les bateaux restent des actifs physiques privés, avec l'UUID existant comme
  identifiant unique, capacités et port affichés. Navigation privée toujours désactivée.
  Présentation via les classes communes `cpj-*`, cache `plateau.html` actualisé.

## Preuves locales

`banc-chantier-naval-certification-local.py --concurrence` : **68 assertions réussies
sur PostgreSQL 17.6**, avec les vrais corps du baseline pour paiement cash/banque,
caisses, lecture d'état, inventaire et livraison de transits. Les schémas, identités et
stocks sont des fixtures locales minimales, pas un clone certifié de production.
Les RPC joueur passent sous `authenticated` avec `request.path` ; les tâches passent
sous `service_role`. Le mode normal annule les transactions ; le mode concurrence
commet seulement des fixtures jetables pour deux connexions, puis détruit le cluster.

| Scénarios | Preuve exécutée |
|---|---|
| Deux commandes et constructions complètes | 7 et 10 journées, recettes exactes, 90 000 et 150 000 FR |
| Chaque matière absente | trois refus, aucun débit, stock ou jour consommé |
| Reprise après pénurie | transit institutionnel commun livré au même entrepôt, puis progression |
| Budget matières dépassé | refus avant dépense et sans dépassement du contrat |
| Acompte ou échéance sans fonds | refus, aucun paiement partiel ni consommation |
| Double clic et réponse perdue | UUID stable, rejeu unique, deux connexions concurrentes |
| Journées répétées ou dates anciennes | pas de rattrapage ni second paiement |
| Panne après débit fournisseur | exception et rollback intégral des contreparties |
| Livraison répétée | un bateau par contrat, inventaire témoin intact |
| Confidentialité | autre PJ : liste vide ; lecture directe de table interdite |
| Conservation financière | 400 000 FR initiaux = 160 000 restants + 240 000 dans les caisses ; séquestres soldés |
| Matières au prix du seed du dépôt | 36 000 / 48 000 FR ; entrepôt 84 000, constructeur 156 000 FR |
| Migration corrective | double installation, rollback DDL/données et rejeu |

Les prix 5/15/20 sont ceux du seed présent dans le dépôt, **pas une mesure de
production**. Le premier banc historique conserve volontairement ses prix fictifs
6/12/20 et réussit également ; le nouveau banc efface ces trois fixtures avant de
charger le seed, sinon son `ON CONFLICT DO NOTHING` conserverait les faux prix.

Autres essais exécutés :
- interface : **13/13** (5 assertions de source conservées, 6 scénarios runtime du
  vrai pilote commun, 2 Chromium réels à 390/1280 px avec RPC et identité simulées) ;
- banc historique PostgreSQL réussi ; essai de compatibilité PostgreSQL 16.2 réussi
  avant ajout des deux assertions transit (63 assertions), sans le confondre avec 17.6 ;
- contrôleur clients avant intégration du nouveau main : **196/196** ; résultat final
  après intégration consigné dans l'archive de preuves ;
- contrôles globaux : **9/12**, mêmes trois rouges sur `dcf1dff9` et après correction ;
- étape locale « Calendrier sur main » : **114/116**, mêmes deux échecs reproduits
  sur `dcf1dff9` et après intégration. Aucun test supprimé ni référence modifiée.

## Échecs hérités, non masqués

- Baseline : seeds `chaines_production_usine`, `ordres_couts`, `ressources_economie`
  divergents de leurs générateurs/empreintes. Aucun fichier généré corrigé à la main.
- Authority : signature de `trading_acheter` dans la migration terrestre
  `20261104173000` et appel `p_livraison` dans `plateau-equipements.js:219` incompatibles.
- Referential : artefacts serveur déclarés « RENDU » ; voir sortie complète archivée.
- Calendrier : surfaces/prix des quinze parcelles et contrat RPC après migrations.
  Ces défauts préexistent ; ils ne prouvent pas la cause exacte du job distant rouge,
  dont les journaux ne sont pas accessibles ici. Pas d'élargissement de ce chantier.

## Migration et livraison : opération technique restante

Versions initiales à rechercher dans le registre réel : `20261104223000`,
`20261104224500`. **Leur application n'a pas été vérifiée dans cette session.**
Ne pas les rejouer automatiquement.
Correction préparée : `migrations/20261104231550_chantier_naval_certification.sql`.
Ses remplacements contrôlent les fragments attendus ; une définition différente
provoque une exception et exige une réconciliation, jamais un écrasement aveugle.

L'intégrateur disposant du canal Supabase doit exécuter le prévol lecture seule
`outils/bancs/prevol-chantier-naval-473.sql`, contrôler les définitions, droits,
triggers, modèles, caisses et agrégats. Comparer particulièrement les circuits
financiers au catalogue vivant et les changements entrepôts par pays de #476.
Le prévol n'exporte aucun compte, inventaire ou solde individuel.
Après certification sur ce catalogue : appliquer uniquement la version manquante
par le registre, réextraire le baseline via ses générateurs, vérifier les contrôles,
puis intégrer le client compatible. Un retour arrière de schéma est testé localement ;
en production, préférer le correctif en avant après capture technique, sans jamais
supprimer contrats, bateaux ou historique acquis.

Aucun outil Supabase callable n'est exposé dans cette session. `gh run list` est
refusé (HTTP/API Forbidden). `gh pr create --draft` est refusé par GraphQL Forbidden.
Le push Git fonctionne ; la branche est sauvegardée. Aucun numéro de nouvelle PR
n'est inventé. L'accès HTTPS à Vercel échoue au proxy CONNECT/HTTP 403 (Envoy),
ce qui **ne démontre pas une panne du jeu**. Aucun déploiement ni statut READY
observé, aucun test authentifié en production effectué.

Après intégration autorisée : contrôler la version réellement servie, puis recette
avec compte isolé autorisé (aucune opération sur un PJ réel), deux modèles, pénurie,
reprise, replay, livraison et consultation après rechargement. Les sauvegardes
périmées spécifiques à un clone vivant et les transports publics authentifiés restent
à éprouver ; les bancs clients couvrent seulement leurs simulations locales.

**Verdict : correction codée et éprouvée localement ; chantier non terminé tant que
prévol Supabase, CI distante et livraison/recette réelle ne sont pas vérifiés.**

Sorties complètes compressées dans `preuves-naval-473-20261105/` ; `SHA256.json`
contient les empreintes des archives et des journaux décompressés. Ces preuves ne
contiennent que des fixtures locales, des diagnostics de code et des refus d'accès.
