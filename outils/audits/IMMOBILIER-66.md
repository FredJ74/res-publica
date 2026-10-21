# Socle immobilier #66 — inventaire préalable

Base : PR #58, `cda39528ead0df92b5cedfe441ca0898fcbf874b`, encore brouillon et non déployable. Branche dédiée ; aucun changement de la PR #56 ni des réservations #63 repris.

| Flux | Source existante | Réutilisation / manque confirmé |
|---|---|---|
| Fonds historiques PNJ | `entreprises`, `entreprise_signer_compromis`, `entreprise_acte_rachat`, `entreprise_prix_rachat` | Prix catalogue, acompte, compromis et prêt existants ; pas de titre des murs |
| Fonds version 2 | même table `entreprises`, `vendre_fonds_commerce` | Déjà transactionnel, conserve l'identité, extrait la caisse et transfère le titulaire du bail. Service-only car consentement acheteur manquant : la nouvelle offre acceptée doit apporter cette preuve |
| Murs | `terrains_etat.proprietaire` et miroir JSON `data.proprietaire` | Préserver les deux représentations existantes et les subdivisions ; aucune vente implicite avec le fonds |
| Baux / loyers | `locations_actives`, `bail_destination_attestee`, `prelever_loyer_bail` | Les lots dynamiques résolvent le titulaire à chaque débit ; les autres locaux restent routés vers la commune, même après vente des murs : adaptation commune requise |
| Paiement | `helvetia_debiter_fonds_ordinaires`, `helvetia_crediter_destination`, `payer_ordre`, `recette_municipale` | Pas de caisse parallèle ; refus/rollback de toute la transaction si une contrepartie échoue |
| Titulaires | `pj:`, `orga:`, `ville:<pays>_<ville>` déjà définis dans `plateau-fonds.js` | Réutiliser le format municipal existant ; ne pas créer de nouveau type de propriétaire |
| Notaire | `ouvrirMenuOfficialiserTransaction`, `officialiser_transaction` (1 PA, 0 FR) | Consultation d'offres séparée du menu des compromis historiques ; frais existants uniquement |
| Préemption | préemptions d'État des entreprises | Mécanisme distinct du droit nouveau de l'exploitant : ne pas détourner le pouvoir du ministre. Nouvel état d'offre, même courrier et horloge serveur ; aucun moteur de bâtiment |
| Financement #65 | `prets`, prêts travaux/consommation, `pretDemande` des compromis | Type acquisition et termes non définis dans #65 ; ne pas créer un faux prêt ni créditer sans décaissement attesté. Garder les prêts existants et leurs clauses |

## Arbitrages et données

Républia : 150 FR/m² pour cessions publiques, sans coefficient ; prix de revente PJ libre, indépendant des références. La Republica : un bâtiment, 1200 m², murs 180000 FR, fonds 380000 FR. Les autres surfaces restent NULL, aucune surface extrapolée ; les surfaces persistantes des centres/locaux ne doivent pas être écrasées.

La fiche de raccordement ne remplace aucun titre : elle référence les lignes canoniques existantes. Les offres et reçus attestent une vente ; ce ne sont ni un second cadastre ni une seconde caisse. Les anciens titulaires PJ ne sont jamais convertis en titulaires municipaux.

Préemption : mail avant départ de la fenêtre, 72 heures réelles exclusives, refus explicite ou échéance autoritaire => publication. La politique de retrait/republication/changement de prix n'est pas validée : aucune de ces commandes ne sera ajoutée implicitement. Baux multiples/occupation ambiguë : refuser la mise en vente au lieu de choisir arbitrairement un prioritaire.

## Dépendances et limites préalables

Les corps vivants, contraintes, RLS et tâches Supabase restent à confronter au prévol avant toute application. Les archives sont des sources locales, pas une preuve de production. Pas de migration en production, pas de modification de joueur, pas de fusion.
