# Hospitalisation à 0 PA (Claude, 01/11/2026)

Règles : `GAME-DESIGN-HOSPITALISATION.md` (décisions de Fred du 01/11, non redemandées).
Base : tête de `claude/circuits-residuels-219-20261101` (#318, elle-même sur la branche de #219).
Branche `claude/hospitalisation-20261101`, PR dédiée vers #318. **Aucune fusion, aucune migration
appliquée, aucun déploiement, aucune donnée de production touchée.**

## Correctif serveur

`migration-a-integrer-hospitalisation.sql`, **hors de `migrations/`** comme celui de #318 (le lot
certifié de #219 n'est pas modifié) : à placer **après** le correctif de #318. Idempotent.

| Règle | Où elle vit |
|---|---|
| PA à 0 (ordre payé, combat perdu, toute fonction) → hospitalisation automatique au dispensaire de la ville | déclencheur différé `trg_hospitalisation_pa_epuises` (fin de transaction ; ne fait jamais échouer l'ordre ou le combat) |
| Détention prioritaire (arrêté au terme du combat) | même déclencheur, qui juge l'état final |
| Immobilisation jusqu'à la sortie | régime `pa0` avec `dateFinParis = 9999-12-31` : les interdits existants de #219 (navigation, recrutement, police, batailles) s'appliquent sans être retouchés |
| Dormir refusé à J0 ; 2 / 6 / 12 PA ; ×3 en clinique ; +2 si repas la veille | patch en place de `pa_repos_nocturne` (fragments exacts, marqueur `hospitalisation_pa0_repos_v1`) |
| Repas de l'hôpital, 1 PA, une fois par jour | `hospitalisation_repas_prendre()` ; coût au miroir `ordres_couts` (`repas_hopital`, 1, 0) |
| Mails et forums interdits à J0 | `hospitalisation_ecriture_j0_garder()` sur `mails`, `forum_topics`, `forum_posts` (refus nommé `hospitalise_j0`) |
| Transfert en clinique dès J0 (ambulance) | porte `hospitalisation_lieu_rejoindre` de #318, inchangée pour ce cas |
| Sortie à partir de J2 et de 20 PA | **même porte**, `p_lieu = 'sortie'` : lève l'hospitalisation, rend la chambre de clinique, sort par la porte du bâtiment (`rue_position_personnage_interne`) |
| Empoisonnement inchangé | aucune de ces règles ne s'applique hors du régime `pa0` |

La porte de #318 devient `hospitalisation_lieu_rejoindre_interne(p_nom, …, p_automatique)` ; la porte
réseau garde sa signature et ses droits et appelle l'interne pour l'appelant. En mode automatique,
l'ambulance emporte aussi un PJ intercepté ou sorti d'un combat (jamais un détenu), et le verrou du
graphe des groupes est pris s'il est libre, sans attente (pas d'étreinte fatale avec un combat qui
tient déjà la fiche).

## Écran

- `declencherHospitalisation` : hors empoisonnement, n'enregistre que la chute des PA à 0 puis relit
  l'hospitalisation et la position décidées par le serveur (`relireHospitalisationServeur`).
  L'empoisonnement garde l'ancien chemin. Détachement militaire « assassiner » : même chemin.
- `updateUI` : PA à 0 sans hospitalisation connue → relecture de la fiche (ordre payé jusqu'au dernier PA).
- `doDormir` : refus J0 nommé ; nuit à l'hôpital relatée avec les montants du serveur ; « Sortie autorisée ».
- `verifierProgressionHospitalisation` : ne touche plus aux PA ni à l'hospitalisation du régime `pa0`.
- Ordres `repas_hopital` et `sortie_hopital` : salle d'attente de Luthécia, gabarit des dispensaires de
  province, réception (sortie) et dix chambres de la clinique (réservés au patient).
- Mails, sujets et réponses de forum : bloqués à J0 avant l'envoi (le serveur refuse de toute façon).
- Description de la pièce : « Hospitalisé(e), jour N. Sortie possible à partir du jour 2, avec 20 PA. »

## Preuves

- `preuve-sql.log` : **25/25** sur PostgreSQL 16 jetable (baseline + 95 migrations #219 + correctif #318
  + ce correctif, appliqué deux fois).
- `preuve-sql-contre-epreuve.log` : sans ce correctif, **18 défauts dénoncés** ; les 7 cas verts décrivent
  des comportements qui ne doivent pas changer (détention, PA rendus, empoisonnement, sommeil ordinaire…).
- `preuve-client.log` : **10/10** ; contre-épreuve sur la tête de #318 : **9 échecs** (seul reste vert
  l'empoisonnement, inchangé par conception).
- Non-régression : banc SQL de #318 **14/14** sur la base avec ce correctif ; banc client de #318
  **12/12** (son cas 6 décrivait l'ancien circuit écran → porte ; il est scindé : 0 PA → serveur seul,
  empoisonnement → porte) ; bancs clients #219 **136/136** ; `test-*.mjs` **23/23** ;
  `controler-client.py` : mêmes échecs qu'avant le chantier, à deux près, tous deux d'environnement ou
  de convention déjà présents avec #318 (module `acorn` absent hors CI ; fichier SQL « à intégrer »
  hors des trois dossiers, comme celui de #318).

Rejouer : `outils/bancs/banc-hospitalisation.sh [--contre]` (root, PostgreSQL 16) ;
`node --test outils/bancs/banc-hospitalisation-client.cjs` (contre-épreuve : `CONTRE=<sha> node --test …`).

## Pour l'intégrateur

1. Placer ce fichier SQL après celui de #318 (les deux sont hors de `migrations/`).
2. Après application : vérifier en jeu qu'un PJ qui dépense son dernier PA arrive au dispensaire de sa ville.
3. `GAME-DESIGN-HOSPITALISATION.md` n'existait que sur `main` : il est repris ici avec une section
   « Implémentation » ajoutée.
