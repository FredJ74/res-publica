# Sécurisation serveur des organisations — reprise du 19 octobre 2026

## Verdict et état réel

**CHANTIER NON TERMINÉ.** Un lot administratif supplémentaire est codé et éprouvé, avec raccordement progressif du navigateur. Le verrouillage global de `organisations.data` n'est PAS réalisé : plusieurs opérations légitimes restent à migrer. Les équipements ne sont donc pas activés en production par cette session.

Information nouvelle fournie par le propriétaire : `09c40b4` est READY en production Vercel et les nouvelles RPC d'équipement ne sont pas présentes dans Supabase. Ce rapport remplace l'incertitude de la session précédente concernant ce SHA uniquement. Le déploiement des commits de cette session n'a pas été observé.

Main repris propre à `09c40b4`. Pendant le travail, le commit distant `3c8f8c3` (six retours de rues de Port-Sainte-Marie) est arrivé. Le premier push a été refusé, puis le lot local a été rebasé sans conflit sur ce commit ; aucune modification de ses données ou de sa migration.

Accès réessayés : production, API GitHub Actions et REST Supabase échouent à l'établissement du tunnel HTTP avec **403 Forbidden**. Aucun connecteur Supabase/Vercel disponible dans les outils. Git fetch/push fonctionne. Ces refus ne prouvent ni une panne du jeu ni un quota Vercel. Pas de manipulation de clés ni de contournement réseau. Aucun secret demandé au game designer.

## Lot livré : commandes administratives atomiques

Migration préparée : `migrations/20261019094425_organisations_commandes_administratives.sql`.

Nouvelle RPC `organisation_commande_administrative(text,text,text,jsonb)` :

- Informations (`nom`, `devise`, `avatar`) : seulement le chef courant ; autres champs refusés.
- Visibilité : seulement le chef d'une organisation criminelle, valeur booléenne explicite.
- Exclusion : seulement le chef ; le dirigeant ne peut être exclu par cette commande.
- Départ : seulement soi-même ; le chef doit auparavant transmettre la direction.
- Trésorier : nomination/révocation conformes aux verdicts existants de `plateau-gouvernement.js` ; chef seul, trésorier membre distinct du chef, mémoire du précédent titulaire conservée lors de révocation. Aucun nouveau rôle inventé. Ces deux commandes sont préparées côté serveur ; il n'existe pas d'appelant de nomination persistant raccordé dans l'interface actuelle.
- Candidature et vote : identité authentifiée, appartenance actuelle, phase et échéances contrôlées avec `personnages_donnees.day`. Impossible de fournir l'identité du votant ; un vote ne peut viser qu'un candidat enregistré. Les deux votes simultanés de membres différents sont conservés.
- Dissolution : seulement le chef courant, suppression et reçu dans la même transaction. Les FK d'équipement refusent une suppression destructrice ; aucun objet ni reçu n'est supprimé pour la rendre possible.

La fonction verrouille la ligne actuelle avant de modifier un champ. Elle ne reçoit jamais le blob du navigateur et ne touche pas à la caisse, aux placements, aux montants historiques ni aux autres clés inconnues. Les commandes simples ne modifient pas l'élection ; candidature et vote ne changent que l'élection ciblée, pas la direction. Déclenchement, passage de phase et dépouillement restent à migrer.

Registre de reçus privé avec RLS, clé de requête unique et contrôle acteur/organisation/commande. Un rejeu exact confirme l'acte sans le répéter. Une réutilisation de clé pour une autre charge ou un autre acteur est refusée. L'échec tardif d'insertion du reçu annule aussi la mutation. Après dissolution, le reçu reste rejouable sans recréer l'organisation. Un ancien reçu ne renvoie pas d'ancien snapshot financier : le client relit l'organisation courante.

Gardes de version : toute définition de fonction non examinée ou tout registre de reçus non reconnu refuse la migration. Idempotence et refus d'écrasement testés. Aucun ancien rôle client n'est révoqué dans ce lot additif ; **la migration n'affirme pas sécuriser tous les accès historiques**.

## Raccordement navigateur

`supabase.js` : nouvelle porte `sbOrganisationCommande`, une requête simultanée par organisation, paramètres figés, identifiant conservé dans localStorage jusqu'à confirmation ; reprise après F5/réponse perdue. Pas de solde stocké dans cette reprise.

Transition conservatrice : seul un retour explicite **HTTP 404 / PGRST202** (contrat absent du cache PostgREST) permet de conserver le chemin historique. Une panne, un 403, une réponse indéterminée ou un refus métier ne déclenche jamais de PATCH/DELETE de repli. Stockage de reprise indisponible : commande refusée avant envoi. Cette compatibilité est temporaire et doit disparaître avec la fermeture finale des anciennes écritures ; elle ne constitue pas une protection serveur globale.

`plateau-organisations-quetes.js` : options, renommage, visibilité, exclusion, départ, candidature et vote utilisent la nouvelle porte lorsqu'elle existe. Confirmation attendue avant rendu positif ; relecture actuelle après succès, réponses d'ancien personnage ignorées. Une relecture indisponible après transaction confirmée est annoncée comme telle, sans inventer de snapshot local.

Dissolution : `sbDeleteOrganisation` utilise désormais la commande serveur si présente, et exige l'identifiant confirmé. Le circuit historique ne reste disponible qu'en cas d'absence explicitement attestée de la nouvelle RPC. Le panneau conserve son organisation si la suppression est refusée ou indéterminée.

Lecture fraîche d'organisation corrigée pour accepter les deux représentations déjà gérées par le chargement général : JSON texte ou objet jsonb. Les tableaux/valeurs invalides restent refusés.

`plateau.html` : versions des deux scripts actualisées. `.github/workflows/coherence-client.yml` : réemploi de la CI existante, ajout du banc administratif PostgreSQL local ; aucun workflow de déploiement supplémentaire.

## Vérifications finales

| Vérification | Résultat | Limite |
|---|---|---|
| Banc administratif PostgreSQL jetable | **41/41 groupes** | SQL réel ; identité de fixture, pas JWT Supabase réel |
| Banc client administratif | **16/16** | Fonctions réelles, transport simulé |
| Équipements collectifs PostgreSQL | **32/32 groupes** | Anciennes 31 épreuves conservées, dissolution via la nouvelle RPC et FK réelle ajoutée |
| Contrôleur client complet après stabilisation des fichiers | **82/82 bancs** | Inclut Chromium et chargement du bundle Vercel, pas production authentifiée |
| Réception atomique PostgreSQL | **31 groupes réussis** | Local uniquement |
| Achat PostgreSQL | **12 groupes réussis** | Services annexes de fixture |
| Assemblage PostgreSQL | **20/20 groupes** | Migrations préparées, aucun stock réel |
| Jodie PostgreSQL | **6/6 groupes** | Publications et rollback locaux |
| Contre-épreuves | **90/90** | Assertions conservées |
| Syntaxe API | **23/23 modules** | Sans appel distant |
| Calendrier | **5/5** | Tests Paris existants |
| Payload simulé Vercel | **315,2 Mo / 330 Mo** | Pas un build Vercel distant |
| Contrôle global | **10/12** | Authority et Referential rouges |

La suite complète avait été lancée pendant l'écriture d'un fichier source lu à chaque scénario : une lecture intermédiaire a produit un `SyntaxError` dans le banc réception. Relance complète sur les sources stabilisées : **82/82**, sans modification ni suppression d'assertion du banc réception. Aucun défaut du mécanisme de réception n'est déduit de cette lecture concurrente du fichier en cours d'édition.

Le workflow révélait aussi que le prévol antérieur `BEGIN TRANSACTION READ ONLY` n'était pas reconnu par son détecteur d'enveloppe. Le SQL est reformulé en `BEGIN; SET TRANSACTION READ ONLY; ... ROLLBACK;`, avec la même protection de lecture seule et l'annulation finale. Pas de désactivation de contrôle. Le prévol inclut désormais le contrat administratif et le registre de reçus.

### Deux contrôles rouges maintenus

**Authority** : 19 RPC utilisées absentes du baseline archivé, contre 18 précédemment ; le nom supplémentaire est la nouvelle commande administrative préparée. Cela ne mesure pas la présence réelle dans Supabase. Les définitions du baseline ne sont pas éditées manuellement pour masquer cette absence.

**Referential** : mêmes divergences `ordres_couts` (`79ecb2f9d4bf71f5` généré contre `20e52d8f9bbe8e3f` déclaré) et `postes_nommes_regles` (`694f117ace57b0b1` contre `6c0c7aa0d29bf852`). Sans relevé vivant, aucune mesure remplacée ni règle modifiée.

Le contrôleur global utilise le venv équipé de pglast et le pont JSC/Node déjà disponible dans cet environnement. Les échecs applicatifs/d'écart ne sont pas présentés comme de simples dépendances manquantes.

## Préconditions et reste exact

### Avant toute application

L'agent technique disposant de l'accès doit lire le registre et les quatre ensembles de catalogues canoniques du workflow, plus `outils/bancs/prevol-equipements-collectifs.sql`. Examiner fonctions, droits, policies, triggers et types réels. Aucun lot SQL de cette session n'est appliqué à Supabase.

Le lot administratif est additif. Il peut être éprouvé sous transaction annulée avant fermeture globale, après inspection des préconditions vivantes ; il ne justifie PAS l'application immédiate des équipements. L'ordre des horodatages ne suffit pas : les anciennes migrations d'équipement sont dépendantes de la fermeture des écritures, qui est encore à construire.

### Encore à migrer pour fermer organisations.data

- Fondation générale et domiciliation, en préservant le circuit distinct `syndicat_etudiant_domicilier` déjà serveur.
- Demandes/admissions/invitations, grades, transitions institutionnelles et administratives encore via `sauvegarderOrga`.
- Déclenchement payant et résolution des élections (`confirmerDeclenchementElection`, `verifierElectionsOrganisations`) ; ne pas juxtaposer coût client et résultat serveur non atomiques.
- Actions d'organisation avec coûts, gains, ressources, influence et caisse (`executerOrdreOrga`, adhésions dockers/supporters, grèves, etc.).
- Caisse, subventions, transferts et contreparties ; sauvegardes serveur du cron (`sbSaveOrganisationServeur`) et effets de rumeurs/successions. Le rôle service_role peut également écraser un blob périmé ; supprimer seulement les droits navigateur ne suffit pas à sécuriser ces tâches.
- La fermeture doit couvrir INSERT/UPSERT/DELETE et UPDATE de table/colonne, les vues, RPC et tâches, pas seulement le bouton de sauvegarde. Ne jamais révoquer les droits tant que ces appelants légitimes ne sont pas raccordés et testés.

Après ces migrations, appliquer les équipements seulement contre les définitions examinées. Le garde-fou d'achat continue de refuser un moteur vivant différent, notamment une évolution alimentaire non examinée. Ni hash de garde ni baseline ne doit être ajusté sans analyse.

### Autres chantiers conservés mais non clos

- Assemblage `20261018231225`, Jodie `20261018231849`, réception `20261016131932` : tests locaux relancés, application toujours bloquée faute d'accès vivant. Ne pas les rejouer si le registre confirme une application indépendante.
- Commerce international, piratage, caméras/intranet, papier et recettes 3D : raccordements aux équipements non réalisés. La cellule de renseignement ministérielle existe, mais sa réutilisation ne se réduit pas à ouvrir ses pouvoirs aux organisations : il faut préserver ses droits et raccorder les résultats/coûts aux contrats serveur examinés. Aucun bonus, risque, tarif ou droit inventé dans cette session.
- Finances globales, entreprises, PJ et traitements différés : autorité serveur intégrale non réalisée. Aucun revenu/placement/loyer remplacé par une constante ou un calcul d'affichage.
- Baseline et contrôles : extraction vivante nécessaire ; pas de falsification documentaire.

Aucune fonctionnalité de matériel déclarée opérationnelle en production. Aucun mini-jeu ajouté.

## Données et exploitation

Aucune migration appliquée. Aucun solde, inventaire, livraison, personnage ou poste de joueur réel modifié. Aucun crédit ni débit d'Angie ; ses 2 000 FR, placement bloqué de 500 FR et échéance n'ont pas été modifiés ou réécrits.

GitHub Actions et déploiement des nouveaux commits : non observés, API bloquées par le proxy. `09c40b4` READY reste la confirmation indépendante reçue du propriétaire. Aucun parcours authentifié de production effectué ; aucun compte de test autorisé exploitable ici.

L'intervention externe nécessaire porte sur l'accès technique de cette session aux API/connecteurs et à un environnement de tests autorisé, pas sur une manipulation SQL ou GitHub à faire exécuter au game designer. Les développements restants ci-dessus ne sont pas imputés au seul réseau : ils sont réellement encore à implémenter.

## Sauvegardes Git

- `eff0c1e` : contrat administratif, raccordements et bancs (rebasé sur `3c8f8c3`, puis poussé).
- `702e6cc` : enveloppe de prévol compatible avec le workflow, toujours READ ONLY et ROLLBACK ; poussé.
- Commit accompagnant ce rapport : cas supplémentaires de droits/gardes SQL, prévol étendu et point de reprise.

Retour arrière : avant usage, DDL transactionnel testé ; après usage, conserver reçus, données et matériels. Ne pas supprimer le registre pour annuler une opération déjà confirmée. Un retour d'interface ne doit pas réouvrir les écritures générales après leur future fermeture. Aucun script destructeur de retour arrière préparé.
