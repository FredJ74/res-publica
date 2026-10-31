# Organisations — inventaire des écritures de l'écran et basculement (31/10/2026, Claude)

Suite de #295 (PR #300) et coordination avec #219 (Codex). **Aucune migration appliquée ici.**

## État de la production (lecture seule, 31/10 au soir)

- `organisations` : `authenticated` garde INSERT / UPDATE / DELETE au niveau table.
- DELETE réservé au chef ou fondateur (`organisations_suppression_chef`, PR #300).
- `trg_organisations_finances_garder` actif : caisse toujours celle du serveur ; trésorier, fondateur, direction, grades, adhésion d'autrui et votes d'autrui protégés.
- Commandes #219 `organisation_commande_membres`, `_administrative`, `_evenement` : **absentes**.

## Les 33 écritures par la sauvegarde générale (`sauvegarderOrga` / `sbSaveOrganisation`)

Liste figée par `outils/bancs/test-organisations-ecritures-inventaire.mjs` (CI) : un nouvel appel non classé fait échouer le test.

**17 avec commande #219** : l'écran tente d'abord la commande et ne retombe sur la sauvegarde générale que si le serveur répond « contrat absent » (PGRST202). Le repli disparaît dès l'installation de #219, sans changement d'écran.

| Fonction | Commande |
|---|---|
| monterGrade / descendreGrade / exclureMembre | promouvoir / retrograder / exclure |
| demanderAdhesion / accepterAdhesion / refuserAdhesion | demander / admettre / refuser_demande |
| envoyerInvitationOrga / accepterInvitationOrga / refuserInvitationOrga | inviter / accepter_invitation / refuser_invitation |
| sauvegarderOptionsOrga / renommerOrga / toggleVisibiliteOrga / quitterOrga | informations / informations / visibilite / quitter |
| confirmerDeclenchementElection / seProsenterCandidat / voterElection / verifierElectionsOrganisations | declencher_election / candidature / vote / avancer_election |
| dissolution (`sbDeleteOrganisation`) | dissoudre (repli DELETE réservé au chef) |

**16 sans commande serveur** (aucun contrat prévu dans #219 à ce jour) :
création (`confirmerCreationOrga`), ordres génériques (`executerOrdreOrga`), militants PNJ (`doRecruterMilitants`), blocus (`confirmerOrganiserBlocus`), adhésion et création du club de supporters (`doRejoindreClubSupporters`, `getClubSupportersLocal` ; la cotisation passe déjà par `club_supporters_cotiser`), création du syndicat des dockers (`chargerOuCreerSyndicatDockersPSM`), grèves (`validerLancementGreve`, `confirmerTerminerGreve`, `confirmerAppelGreveGenerale`, `repondreAppelGreveGenerale`, `verifierAdoptionGreveGenerale`, `confirmerRetraitGreveGenerale`, `recalculerPuissanceApresRetraitGreveGenerale`), répression policière (`confirmerMobilisationPolice`), influence après rumeur (`validerLancementRumeur`, après `rumeur_lancer`).
Aucun de ces chemins ne touche l'argent (la garde le refuse) ni les champs réservés aux commandes (vérifié par le test).

## Basculement préparé

**Étape A — `migrations/20261031230000_organisations_champs_commandes_serveur.sql` (PRÉPARÉE, non appliquée).**
Après installation de #219, nom, devise, avatar, visibilité, demandes d'adhésion, invitations et élection ne s'écrivent plus que par les commandes : une sauvegarde générale qui en porte une copie périmée voit ces champs remplacés par la valeur enregistrée, le reste de l'écriture passe (grève, blocus, militants, adhésion supporters, création).
Elle se refuse elle-même : sans les trois contrats #219 (`contrats_219_absents`), sans la garde financière, et sans feu vert explicite (`SET LOCAL hg.feu_vert_organisations = 'parcours_valides'` dans la même transaction, après la recette authentifiée).
Banc : `outils/bancs/banc-organisations-champs-commandes-local.py --local-jetable` (15/15, contre-épreuve incluse).

**Étape B — révocation de INSERT / UPDATE sur `organisations`** : seulement après le portage des 16 chemins sans commande (à attribuer : Codex dans #219 « autres opérations d'organisation », ou chantier dédié). Révoquer avant casserait création, grèves, blocus, supporters et militants. Préconditions : test d'inventaire avec `SANS_COMMANDE` vide, recette authentifiée des parcours, puis `REVOKE INSERT, UPDATE ON public.organisations FROM anon, authenticated` et suppression des politiques `organisations_ecriture_acteur` / `organisations_maj_acteur`.

## Ordre d'application conseillé

1. #219 installé et recetté (prévol sur le registre vivant ≥ 1011, cf. #295).
2. Étape A avec feu vert, dans une transaction ; contrôle : renommer par la sauvegarde générale ne change rien, une grève s'enregistre.
3. Portage des 16 chemins, puis étape B.
