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

`TERRAIN_PNJ_PROFILES` contient profils, personnalités et images ; `genererPnjTerrain` tirage pondéré par indices ; `chargerPnjTerrain` génération client/persistance et sessionStorage ; Aucune RPC `terrain_occupation_generer/liberer/police` retrouvée dans le dépôt ou les branches examinées : ne pas les considérer existantes. `setTerrainState` est un cache local, pas une écriture serveur. Négociation, police, dissimulation et traces existent dans `plateau-pnj.js`. Combat : `ouvrirModalAssassinat`, `confirmerAssassinatArme`, modes/armes et PA communs ; branche PNJ député attestée par RPC dédiée ; `militaire_taux_combat`/degré ne sont pas des RPC de combat civil interchangeables.

Écarts à traiter : huit profils potentiels au lieu des quatre situations équiprobables ; génération de nouveau PNJ sur simple absence de cache sans visite vide attestée ; occupations non figées après acquisition ; aucun ordre de neutralisation des squatteurs branché au combat commun ; vérifier autorité serveur avant d'accepter un jet reçu du navigateur. Ne pas appeler une RPC d'Assemblée avec un faux siège ni créer un combat parallèle.

## Lot 3 — inventaire préalable

Moteur commun : `plateau-chantiers.js` (30/60/90/120k, 6/12/18/24 jours, 35/70/100 %, matériaux 30 %, travail 70 %, 50 h/jour et 70 FR/h). RPC existantes `chantier_lancer`, `chantier_verser`, `chantier_travailler`, `approvisionner_chantier`, `vendre_materiaux_chantier`. Cron `avancerChantiersQuotidien` réalise plusieurs écritures REST séparées. `helvetia_debiter_fonds_ordinaires` débite espèces avant banque ; `payer_ordre` vérifie son miroir. Prêt national appelé mais définition non retrouvée dans le baseline ; Helvetia a son circuit distinct.

Écarts : prélèvements manuels et non idempotents ; ordre banque/espèces contraire à l'apport demandé ; aucune atomicité globale du cron ; prix fournisseur libre sans prix propriétaire ; `personnages.arg/liquide` et comptes bancaires entiers dans l'archive, incompatible avec +10 % de 5,50 FR = 6,05 FR. La branche financière existante est à lire, pas à fusionner aveuglément ; aucune conversion monétaire générale à imposer ici. Pas de compensation historique.

## Lot 4 — inventaire préalable

Plan : `verdictModificationPlan`, `planEstVerrouille`, `appliquerVerrouPlan`, éditeur `doModifierPlanChantier` et RPC `terrain_permis_acte`. Livraison : `livrerChantier`/version cron, `appliquerReconfiguration`, RPC `restituer_reliquats_chantier`. Réaménagement : 10 FR/m² et 300 m²/j, baux protégés. Lots/onglets : `plateau-immobilier.js`, moteur de baux et commerce existant.

Écarts : ancien verrou au début du dernier tiers au lieu d'y ouvrir l'édition ; livraison automatique et reliquats au PJ ; pas de réception sur place ; absence de flag distinct de plan initial validé. La réception doit être autoritaire et atomique avec transfert des reliquats aux mécanismes de caisse/stock existants, pas un simple booléen client.

### Lot 2 — réalisé et blocage technique

Tirage commun des quatre situations à 25 %, profils/identités/prompts conservés ; visite vide mémorisée (pas de nouveau tirage pendant la visite ou sur F5), renouvellement de visite après sortie serveur confirmée sans titre/compromis, protection visuelle après acquisition et délai d'enquête cadavre fixé à trois jours. Les données financières et géométriques ne sont pas sérialisées dans ce cache.

La neutralisation ne peut pas être déclarée raccordée : le moteur civil existant ne produit pas de verdict final serveur pour une cible squatteur bêta, et la RPC de député est propre aux sièges de l'Assemblée. Le bouton ne prélève rien et signale le raccordement manquant. L'adaptateur de seuils ne jette pas les dés et n'applique pas de sanction parallèle. Aucun faux combat ou faux crime n'est simulé pour rendre le bouton actif. L'autorité partagée/persistance des occupations, négociation, police et dissimulation reste à porter sur un contrat serveur existant ou un socle autoritaire validé ; le cache de visite seul n'est pas une preuve de persistance Supabase.

## Lot 3 — transfert de matériaux, 20 octobre 2026

Avant modification : un moteur `vendre_materiaux_chantier` existe déjà ; il verrouille le vendeur puis le terrain, calcule la quantité possible et transfère stock/trésorerie/inventaire dans une transaction. Le client laissait toutefois le vendeur choisir son prix, créditait un delta local après réponse, interprétait une réponse perdue comme une absence de transfert et ne conservait aucun reçu. Les colonnes financières archivées sont entières : un tarif unitaire de 5,50 FR ne peut pas toujours être payé sans arrondi.

Modification : conservation du moteur à six arguments comme service interne, enveloppe à sept arguments portant le reçu, droits directs retirés à l'ancienne signature. Même transaction pour don gratuit ou vente au tarif fixé par le propriétaire ; défaut entrepôt + 10 %, arrondi explicitement au centime. Contrôles pays, ville, propriété des tarifs, gel et fin de chantier. Réponse monétaire en chaînes décimales. Refus avant mutation si un paiement fractionnaire ne peut pas être représenté. Aucune conversion des soldes historiques. Le client conserve le reçu dans sessionStorage avant envoi, bloque les doubles clics et relit inventaire/soldes après confirmation au lieu d'appliquer des deltas. Les réponses d'un autre contexte sont ignorées.

Migration **préparée uniquement** : `migrations/20261020214955_construction_materiaux_prix_et_dons.sql`. Gardes des définitions SQL examinées ; arrêt si la définition vivante diffère. Précondition : réception versionnée existante. Les fonctions d'identité et de réception sont simulées dans le banc PostgreSQL local ; il ne valide donc pas leur installation réelle ni leurs triggers/RLS. Les reçus contiennent un inventaire historique : le client le relit systématiquement, sans le recopier.

Vérification : 14 groupes PostgreSQL jetables, dont application répétée, paiement 2 × 5,50 FR, refus 1 × 5,50 FR sur colonnes entières, don, prix propriétaire, rejet sous-centime/null, pays/ville, réponse rejouée, concurrence, rollback après transfert, droits et garde de définition inconnue. Banc JavaScript enrichi pour financement exact (projection seulement), prix individuels non initialisés, transfert/don, réponse perdue et changement de personnage.

### Limites restant à traiter avant activation

- Prélèvements automatiques aux tiers, gel du temps utile, mails une seule fois et approvisionnement nocturne : le cron actuel fait plusieurs écritures séparées ; la projection monétaire ajoutée ne le remplace pas et ne rend pas ces opérations atomiques.
- Prix par défaut encore calculé sur l'entrepôt courant pour les anciens chantiers sans tarif enregistré, et non photographié automatiquement au lancement.
- Acquisition, compromis, permis, prêts et acte : plusieurs circuits existants dissocient débit et mutation du terrain ; aucune prétention de sécurisation complète de ces circuits.
- La protection financière globale contre sauvegarde générale périmée doit être vérifiée sur le catalogue vivant avant toute activation. Le seul verrou de cette RPC ne suffit pas.
- Transport des soldes historiques : le rafraîchisseur commun accepte actuellement les nombres JSON ; une migration globale vers chaînes décimales serait un chantier financier transversal, non dissimulé dans cette migration.

## Lot 4 — inventaire avant modification et obstacles confirmés

L'inventaire du code réel confirme que `verdictModificationPlan` ferme le plan à 2/3, `terrain_permis_acte('permis_plan_modifier')` ne vérifie que le propriétaire/permis et laisse la validation temporelle au navigateur, `livrerChantierServeur` active automatiquement le bâtiment à 100 %, puis `restituerReliquatsServeur` crédite le bénéficiaire PJ. Modifier seulement le menu ou retirer le verrou client ne respecterait donc ni les seuils ni l'autorité serveur. Un tableau `decoupageInitial: []` ne distingue pas un plan jamais initialisé d'une validation indivise. Les anciens chantiers n'ont pas le marqueur explicite exigé par #57 : aucune déduction silencieuse sur cet historique.

Les pièces dynamiques et les baux existent dans `plateau-immobilier.js`. Une livraison ne rend pas à elle seule le local louable : les données de location et l'éligibilité du local dans les fonctions serveur doivent concorder. La reconfiguration payante existante (10 FR/m² concerné, 300 m²/jour, financement intégral et protection des baux) doit être conservée. Il ne faut pas la remplacer par un simple enregistrement gratuit du JSON du plan.

**Non implémenté / non prêt à activer** : nouvelle fenêtre temporelle du premier plan, marqueur historique de validation, réception physique atomique, transfert des reliquats vers caisse/stock du bâtiment, remplacement du cron de livraison, adaptation des locations. Aucune réception simulée ni animation de fausse réussite n'est ajoutée. La commande de réception affiche explicitement cette indisponibilité au lieu de tomber dans l'ordre générique.

Le prévol `outils/bancs/prevol-construction-57.sql` prépare la collecte en lecture seule des signatures, définitions, types, triggers, droits, politiques et dépendances nécessaires. Il n'a pas été exécuté à distance : le proxy refuse l'accès Supabase et aucun connecteur n'est exposé. Cela bloque la confirmation de compatibilité et le déploiement, pas la collecte locale d'informations ; aucun état de joueur n'a été modifié.

## Contrôle complémentaire des données de parcelles

`node outils/audits/auditer-parcelles-57.cjs` relit les références déclarées, sans nombre de parcelle utilisé comme règle. `PARCELLES-57.json` contient les 15 parcelles de Républia avec leurs surfaces et prix distincts. Le contrôle renvoie volontairement un code non nul : **terrain-a-batir-6, Port-Sainte-Marie (`ville_b`), superficie absente**. Son prix déclaré de 25 000 FR est conservé ; aucune surface n'est inventée et son achat est bloqué avant débit faute de donnée. Les surfaces 1 500 m² des parcelles 8 à 11 viennent des descriptions existantes. Les valeurs persistantes explicites restent prioritaires sur les références du dépôt ; leur contenu réel n'est pas connu sans lecture Supabase.

Un défaut supplémentaire a été corrigé : l'état client non initialisé injectait un prix forfaitaire de 25 000 FR, qui pouvait masquer le prix individuel déclaré. Il renvoie maintenant un prix absent et le résolveur commun relit le véritable ordre d'achat. Aucun calcul de prix à partir d'une surface ou du numéro du terrain n'a été ajouté.

## Protection avant déploiement du dépôt sous compromis

La porte SQL archivée n'accepte que le propriétaire. La nouvelle sélection admet le dossier sous compromis, mais sa confirmation est explicitement arrêtée **avant archive, PA ou frais** tant que le raccordement atomique manque. Il ne faut pas facturer un acte qui sera refusé. Même sous titre, le dépôt existant garde archive/paiement/permis en plusieurs appels : son atomicité n'est pas acquise. Le catalogue des coûts `ordres_couts` doit être régénéré avec le générateur existant et comparé au vivant avant activation du tarif 100 FR/1 PA ; aucune empreinte n'a été ajustée pour faire passer ce contrôle.

## Vérification finale de cette étape — travail incomplet

- 93/93 bancs client réussis après les dernières modifications ; 18 cas ciblés du parcours et 4 groupes de monnaie exacte.
- 14 groupes PostgreSQL jetables réussis, dépendances d'identité/réception simulées ; 90/90 contre-épreuves réussies. Analyse syntaxique SQL du prévol et de la migration réussie.
- Contrôleur global : **10/12**, Authority et Referential restent rouges. Comparaison avec une archive de `origin/main` : Authority avait déjà 28 RPC absentes, la branche en signale 30 ; Referential avait déjà trois empreintes divergentes, celle des coûts change encore avec le tarif de permis validé. Ce ne sont pas des contrôles verts. Aucun baseline ou résultat modifié pour les masquer.
- Une erreur de classement du nouveau prévol a été détectée et corrigée sans toucher au contrôleur : `BEGIN; SET TRANSACTION READ ONLY; ... ROLLBACK;` conserve la lecture seule et l'enveloppe reconnue par le workflow.
- Vérification des données de parcelles : code non nul attendu, une surface absente, aucune valeur inventée. Rapport `PARCELLES-57.json` et tests du blocage avant débit.
- `git fetch origin main` : base toujours `baa9cb7`, aucun commit concurrent de main à réintégrer. PR #56 non incorporée. Versions des seuls scripts/styles modifiés actualisées.
- Accès Supabase : tunnel HTTPS refusé 403, aucun connecteur exposé. Aucun test authentifié du jeu ni vérification des définitions vivantes, aucun déploiement. API GitHub GraphQL refusée (`Forbidden`), bien que lecture HTML publique et push Git fonctionnent. Ouverture de PR à tenter après sauvegarde finale ; ne pas la prétendre créée en cas d'échec.

**Verdict : chantier #57 non terminé, branche non fusionnable.** Lots 1–3 partiellement raccordés, lot 4 inventorié et non implémenté. Restent notamment le dépôt atomique du permis sous compromis, l'autorité partagée des occupations et le combat PNJ commun, les échéances/cron atomiques, les prêts et actes concernés, le découpage et la réception/baux. Les limitations d'accès empêchent la validation vivante ; elles ne constituent pas, à elles seules, une explication à tout le code restant à écrire. Aucun arbitrage supplémentaire n'a été demandé et aucun déploiement ne doit être engagé sur cet état.
