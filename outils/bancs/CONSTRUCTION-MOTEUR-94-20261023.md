# #94 — isolation et raccordement du moteur de construction

Branche `codex/construction-moteur-94-20261023`, base main `7b8b163`.
Aucune reprise en bloc de la consolidation. Seules ses quinze migrations de
construction et ses deux bancs PostgreSQL ont ete extraits. Ni coffres, ni
successions, ni journal des ventes, ni moteur de ventes immobilieres importe.
La PR #112 n'est pas embarquee.

## Code raccorde

Les adaptateurs existants de lancement, versement, travail et premier plan
appellent maintenant `chantier_commande`, avec intention persistante et relecture
du terrain et des finances. Ils sont extraits du parcours existant dans
`plateau-construction-commandes.js` ; le registre dynamique d'ordres est reutilise,
sans remplacer les menus mairie/permis du lot #112. Reception, premier plan et
prix proprietaire ont leurs acces ; les dons et ventes reutilisent la meme RPC
transactionnelle a sept arguments. Le vendeur ne saisit plus le tarif du chantier.
Le prix initial reste entrepot +10 %, plafond au franc, puis francs entiers.

Le cron delegue la construction a `chantier_jour_traiter`. Une panne ou l'absence
de RPC ne retombe jamais sur les anciennes ecritures REST. Les reamenagements
restent identifies comme une lacune distincte, pas declares securises par ce changement.
Les quatre pays refusent l'acceleration payante, cote client ET serveur.

Le moteur extrait couvre financement 35/35/30, banque nationale avant liquide,
financeurs PJ/organisation/commune, jours incompressibles, approvisionnement,
travail 1 PA/h a 70 FR, pauses/reprise, notifications et reception avec reliquats.
Les caisses et droits municipaux sont attaches a la commune, pas a l'ancien maire.
Le premier plan n'active pas les locaux avant reception. Les anciennes entrees de
plan/lancement/versement/travail ne doivent pas contourner la commande versionnee.

## Compatibilite avec #112

La garde de `terrain_permis_acte` a ete adaptee a sa definition exacte apres #112
(empreinte `e52c2c7a16a7c13588e7dba99b39a513`). Elle conserve son refus du depot legacy
et ajoute celui du plan legacy. L'empreinte combinee est calculee depuis les corps
examines, sans toucher au baseline ou aux observations du catalogue.
**Ordre si les deux lots sont retenus : #112, puis construction.** La migration
#112 originale refuse legitimement une definition deja modifiee par construction ;
ne pas ignorer ce refus ni retirer sa garde. Le banc est execute dans les deux
etats examines : fonction d'origine, puis avec le garde exact de #112. Cela ne
remplace pas l'essai de toutes les migrations de #112 sur le catalogue vivant.

## Tests et limites

- 62 assertions PostgreSQL construction dans chacun des deux etats ci-dessus.
- Banc PostgreSQL materiaux reussi : ventes/dons, entiers, refus, rejeu, concurrence,
  rollback, droits, compatibilite financiere historique et priorite bancaire.
- **17/17 bancs PostgreSQL du workflow complet** ont egalement ete relances.
- 11 tests Node calendrier/placements, 23 analyses de syntaxe API et garde de payload passent.
- Cinq scenarios du client reel extrait, transport simule : reponse perdue,
  double clic, contexte obsolete, relecture financiere indisponible et reprise.
- Controleur client : 92/92 bancs ; contre-epreuves historiques : 90/90.
  Les attentes de routage et d'approvisionnement ont ete remplacees par celles du
  chemin versionne, avec controle explicite de l'absence de debit d'acceleration.
  Aucune epreuve des refus, deltas ou blobs retiree pour obtenir un resultat vert.

Aucune migration appliquee, aucune fusion, aucun test authentifie du jeu.
Prevol prepare : `outils/bancs/prevol-construction-moteur-94.sql`.
Les gardes SQL et l'ordre complet de leurs dependances doivent etre compares au
catalogue vivant avant activation. Les restrictions de l'environnement continuent
vers Supabase (CONNECT 403) et l'API GitHub (Forbidden pour la creation de PR).

## Ce que ce lot ne termine pas

- Occupations/negociations/police et adaptation au combat commun : autre branche,
  encore incomplet. Aucun resultat de combat n'est fabrique.
- `terrain_lots_acte` et `terrain_reamenagement_poser` : anciens chemins de
  reamenagement et baux a terminer. Le premier plan securise ne les remplace pas.
- Financement #65 : main appelle `pret_national_contracter`, absent du baseline
  ET de toutes les migrations disponibles. L'issue #65 a ete relue integralement.
  Retrouver sa definition vivante/son contrat de versement est necessaire avant
  de le raccorder a la vente ; ne pas ajouter un second moteur bancaire ni
  inventer les taux/plafonds. La preuve de decaissement a la vente reste a faire.
- Les controles Authority et Referential exigent encore une relecture vivante.
  Sur cette branche, le controle Workflow herite du mauvais rangement bancaire
  corrige separement dans `codex/workflow-sql-94-20261023` ; ne pas les confondre.
  Main #111 apporte aussi une reference a `acheter_produit_commerce_interne`
  absente de la photographie ; les fichiers commerciaux n'ont pas ete modifies.

**Chantier #94 non termine ; branche de revue, non autorisee au deploiement.**
Les lacunes locales ci-dessus ne sont pas toutes imputables aux acces distants.
