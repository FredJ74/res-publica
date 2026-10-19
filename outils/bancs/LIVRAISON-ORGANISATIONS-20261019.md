# Livraison nocturne et équipements collectifs — 19 octobre 2026

## Verdict

**CHANTIER NON TERMINÉ.** Socle collectif écrit et testé localement, sauvegardé sur `main`. Aucun déploiement SQL ni test authentifié de production. Les fonctions métier utilisant le matériel (renseignement, fret international, impression et recettes 3D) ne sont pas encore raccordées. Leurs moteurs existants restent inchangés.

La dépendance bloquante supplémentaire est explicite : les sauvegardes historiques peuvent encore écrire `organisations.data`, qui contient à la fois direction, trésorier et caisse. Les deux nouvelles migrations REFUSENT leur activation tant que `anon` ou `authenticated` possède UPDATE sur ce champ. Révoquer simplement ce droit casserait les usages historiques : il faut d'abord migrer leurs écritures légitimes. Les bancs reproduisent et vérifient ce refus ; une réussite locale sur schéma isolé ne prouve pas la sûreté de l'autorité historique de production.

## État repris et accès réels

Départ `a42a5d5`, puis avance rapide sur `ce87677` (liaisons des terrains). Le fichier de migration arrivé sous `supabase/migrations/` est déplacé, contenu inchangé, dans `migrations/`, conformément à WORKFLOW-SUPABASE.md. Sa présence dans Git ne prouve pas son application.

Les tentatives HTTPS vers GitHub Checks, l'API Vercel, `/plateau.html` en production et Supabase REST sont rejetées par le tunnel réseau : `403 Forbidden`. Git fetch/push fonctionne. Aucun connecteur Supabase/Vercel n'est exposé et aucun jeton de déploiement n'est disponible dans cet environnement. Aucun contournement tenté.

Le lien de check fourni par l'utilisateur pour `a42a5d5` contient `upgradeToPro=build-rate-limit` : c'est un indice de limitation Vercel fourni par l'utilisateur, distinct du refus de proxy observé ici. Aucun historique de quota ni déploiement récent n'a pu être lu. Le dernier déploiement confirmé par l'utilisateur reste `78f74b2` ; impossible d'affirmer que les nouveaux SHA sont servis. Aucune modification de forfait, réglage distant, intégration ou déploiement forcé.

`vercel.json`, son ignoreCommand et les workflows existants sont conservés. La CI existante reçoit un seul banc PostgreSQL local supplémentaire ; aucun pipeline de déploiement concurrent ajouté.

## Livrables

### Serveur préparé, non appliqué

- `migrations/20261019064000_organisations_equipements_collectifs.sql` : inventaire appartenant durablement à `orga:`, preuve de vente obligatoire, intégration de livraison avant sa suppression, installation/retrait/transfert entre organisations, reçus d'actes et journal transactionnels. Autorisation issue du personnage authentifié, du représentant courant et de la présence réelle. Verrous ordonnés, rejeu contrôlé, interdiction de réutiliser une clé avec une autre commande. Tables sans écriture directe client et fonctions privées non exécutables par les clients.
- Le matériel reste propriété de l'organisation après changement de direction. Suppression d'une organisation possédant du matériel refusée par FK, sans destruction du matériel.
- Capacités calculées sur le matériel réellement installé dans les locaux canoniques : un ordinateur sert simultanément internet, caméras, intranet, imprimantes papier et 3D. Plusieurs caméras comptées. Ni matériel consommé ni fonction de jeu vidéo activée.
- `migrations/20261019064500_achat_equipements_collectifs.sql` : adaptateur au moteur d'achat et au mouvement financier existants, sans seconde caisse. Le gestionnaire de caisse historique est respecté : trésorier s'il existe, chef sinon. Le payeur `orga:` reste propriétaire à travers reçu, livraison et inventaire. Paiement, stock et réception collective sont atomiques ; erreur tardive annule l'ensemble. Décimaux exacts, refus des fractions de centime ; promotion des reçus en numeric sans facteur 100.
- Remplacement du moteur d'achat limité à des définitions archivées expressément examinées. Toute autre définition vivante refuse la migration, notamment une variante alimentaire non examinée. L'ancien test `active:false` de cette source archivée subsiste : pas d'affirmation de compatibilité avec tous les catalogues vivants.

Les huit types d'organisation utilisent le même socle ; pas de moteur distinct par type. La transition électorale historique est conservée et éprouvée depuis l'état ancien des votes, sans changer son calcul métier. Cela ne clôt pas la sécurité générale des écritures d'élections dans le blob legacy.

### Interface

- Nouveau `plateau-equipements-collectifs.js`, chargé par `plateau.html` : inventaire collectif dans la modale Commerce existante, réserve/installation, retrait/transfert et configuration calculée par le serveur.
- `plateau-organisations-quetes.js` : entrée Équipements pour le représentant ; dissolution désormais confirmée par la suppression réelle avant toute disparition locale, journal ou annonce de succès.
- `supabase.js` : suppression d'organisation à verdict, exigeant le retour de la ligne supprimée. Réponse vide, refus ou panne ne valent pas confirmation.
- `plateau-commerce-pj.js` : choix explicite du payeur seulement si le serveur expose le contrat et les organisations autorisées. Sinon le circuit personnel est conservé. Achat collectif sans delta local de solde ni détournement vers l'inventaire PJ.
- Clé d'achat non confirmé conservée dans localStorage par session utilisateur/personnage/organisation/produit/quantité : reprise avec le même reçu après réponse perdue, F5 et reconnexion. Stockage indisponible : refus avant commande. Le stockage ne porte aucun solde et ne fait pas autorité. Les commandes d'installation ne sont pas relancées automatiquement après réponse inconnue : relecture explicite de l'état serveur.
- Rendus échappés, réponses d'ancien personnage/session et doubles clics en cours ignorés.

### Contrôles

`verifier-autorite.py` ignorait `sbRpcVerdict` et les mutations via helpers `*Verdict`. Détection ajoutée, espaces avant parenthèses acceptés, test couvrant plusieurs fichiers et paramètres imbriqués. Aucun invariant supprimé ni déclaration/empreinte ajustée. Les 13 écarts précédents deviennent **18 RPC absentes du baseline**, dont quatre nouveaux contrats collectifs et une porte jusque-là invisible ; ce n'est pas une preuve de présence ou d'absence dans la base vivante.

`outils/bancs/prevol-equipements-collectifs.sql` prépare une inspection en transaction READ ONLY : ACL, policies, signatures, empreintes, types, triggers, dépendances et nombre agrégé de reçus contenant une fraction de centime. Aucun montant individuel ni nom de joueur extrait. Syntaxe analysée par pglast, exécution distante NON effectuée. Compléter impérativement par les quatre extractions canoniques du workflow ; cette requête ciblée ne remplace pas un relevé complet.

## Vérifications exécutées

| Vérification | Résultat | Portée |
|---|---|---|
| Contrôleur client complet, après corrections finales | **81/81** | Fonctions réelles, transports simulés ; inclut le bundle Vercel et le nouveau détecteur Authority |
| Sous-banc collectif client | **13/13** | Achat personnel/collectif, reprise après F5, stockage indisponible, permissions d'affichage, réponses tardives, dissolution confirmée/refusée |
| SQL collectif PostgreSQL jetable | **31/31 groupes** | Migrations réelles, mouvement financier existant ; identité, présence et fiscalité de fixture |
| Réception atomique PostgreSQL jetable | **31 groupes réussis** | Sans Supabase ni inventaire réel |
| Achat PostgreSQL jetable | **12 groupes réussis** | Débit/livraison/rollback/rejeu/concurrence ; services annexes de fixture |
| Assemblage PostgreSQL jetable | **20/20 groupes** | Deux défauts historiques reproduits avant correctif ; dix recettes et 5,50 FR |
| Publications Jodie PostgreSQL jetable | **6/6 groupes** | Idempotence, deux supports, échappement, rollback |
| Contre-épreuves existantes relancées | **90/90** | Aucun test neutralisé |
| Syntaxe API | **23/23** | Aucun appel DeepSeek ni secret requis |
| Calendrier | **5/5** | Paris et peines/clôtures |
| Contrôle global | **10/12** | Authority et Referential rouges, détails ci-dessous |
| Payload simulé Vercel | **315,2 Mo** | Sous le garde-fou 330 Mo ; simulation des fichiers Git, pas build distant |
| Git diff --check | Conforme | Aucun marqueur ni espace fautif |

Le contrôleur global a d'abord été lancé avec Python système sans pglast/JSC : abstentions supplémentaires d'environnement. Relance avec le venv équipé et le pont JSC/Node déjà utilisé par les bancs historiques : dix contrôles passent ; les assertions sont conservées. Aucun de ces résultats locaux ne vaut contrôle Supabase vivant ni parcours authentifié.

### Authority : 18 noms manquants du baseline

`consommer_sur_place_commerce`, `inventaire_reception_etat`, `inventaire_reclamer_livraison`, `inventaire_sauver_revision`, `justice_executer_condamnation_soi`, `organisation_equipement_acheter`, `organisation_equipement_deplacer`, `organisation_equipements_etat`, `organisation_equipements_payeurs`, `police_action_resultat_lire`, `police_detection_verifier`, `police_reprise_lire`, `pret_national_contracter`, `rue_position_enregistrer`, `rue_position_lire`, `rue_sortie_batiment_lire`, `subvention_entreprise_verser`, `tracts_electoraux_distribuer_collectif`.

Ne pas ajouter ces fonctions manuellement au baseline. Il faut déterminer dans le registre vivant lesquelles sont appliquées et réextraire, puis traiter les migrations réellement absentes sous préconditions.

### Referential : deux mesures incohérentes

- `ordres_couts` : générateur `79ecb2f9d4bf71f5`, déclaration `20e52d8f9bbe8e3f`.
- `postes_nommes_regles` : générateur `694f117ace57b0b1`, déclaration `6c0c7aa0d29bf852`.

Sans catalogue vivant, impossible d'arbitrer mesure périmée et miroir SQL obsolète. Aucun hash remplacé pour masquer l'écart ; aucune règle économique changée.

## Déploiement et suite précise pour l'agent technique

1. Rétablir les accès autorisés aux API/projet et observer quota, check et SHA réellement servi. Ne pas multiplier les déploiements pour tester le réseau.
2. Extraire les catalogues et examiner les définitions vivantes : réception, assemblage, publications, achat, finance et organisation. Préserver leurs évolutions alimentaires/commerciales récentes.
3. Migrer les écritures légitimes d'organisation (métadonnées, membres, élections/direction, trésorier, caisse et toutes contreparties financières) vers des RPC atomiques contrôlées, avec reçus et concurrence. Puis fermer l'UPDATE général, sous tests de régression. La branche financière reconstruite a été consultée, pas fusionnée aveuglément.
4. Rééprouver M1/M2 contre ces définitions exactes ; un refus de garde se corrige par examen et adaptation justifiée, pas par simple changement d'empreinte. Appliquer uniquement les migrations validées, suivant WORKFLOW-SUPABASE.md. Puis réextraire le baseline et vérifier les douze contrôles.
5. Raccorder le contrôle privé de capacités aux moteurs métier existants (commerce international/fret, renseignement/caméras/intranet, impressions/document et recettes 3D). Aucun de ces raccordements n'est annoncé comme fini ici.
6. Parcours authentifiés isolés : matériel, direction/élection, trésorerie, achats individuels inchangés, inventaire et réception ; réponses perdues et concurrence. Ne pas modifier les personnages des joueurs pour les essais.

Retour arrière : sauvegarder les définitions et relever les données avant application ; la migration ne purge aucun avoir. Avant usage réel, le DDL est transactionnel. Après usage, bloquer les nouvelles commandes et conserver objets, reçus et journaux ; ne jamais supprimer les tables ou recréer des livraisons/compensations par deltas supposés. Un retour de moteur nécessite une migration examinée, pas la réactivation aveugle d'un ancien débit défectueux.

**Aucun solde réel modifié ; aucune lecture ciblée ni modification d'Angie, de ses 2 000 FR, de son placement bloqué de 500 FR ou de son échéance. Aucune migration appliquée.** Aucune réussite de dialogue, d'assemblage, de publication ou de réception authentifiée de production affirmée.

## Sauvegarde Git

- `7d8259b` : socle SQL collectif et banc PostgreSQL, gardes de déploiement.
- `e67d076` : interface collective, choix du payeur, reprises d'achat et dissolution confirmée ; tous deux poussés sur `main`.
- Le commit accompagnant ce rapport ajoute le contrôle Authority corrigé, son banc et le prévol en lecture seule.

Les fichiers sont intégrés à `main` selon la mission ; ce fait n'atteste ni déploiement Vercel ni application Supabase. Dernier fetch avant livraison : aucun commit distant concurrent à intégrer.
