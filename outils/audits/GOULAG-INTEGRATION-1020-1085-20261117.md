# Intégration du goulag de Sovarka — #1020 (moteur) puis #1085 (ordres internes), 17/11/2026

Coordination reprise par Claude (Codex indisponible), sur instruction de Fred. **Aucune fusion, aucune
migration appliquée sur Supabase, goulag non activé** (CHECK `active IS FALSE` conservé et éprouvé).

## Têtes et ordre d'intégration
- `main` de référence : `37bb26c` (interface mobile #1089, #1091 incluse).
- **#1020** `chatgpt/goulag-moteur-survie-20261116` : `main` fusionné (`47f77f0`), contrat de corruption définitif
  et trois validations finales (`8a37a17`), CI de récupération de la référence #1085 (`6012cd8`).
- **#1085** `claude/goulag-ordres-internes-20261117` : **empilée sur #1020** (`25f115e`, puis `f3c691e`).
  Fusionner **#1020 d'abord** ; le diff de #1085 se réduit alors à ses propres fichiers.
- Ordre des migrations : celles de #1020 (`20261116*_goulag_*`), puis les quatre de #1085
  `20261117170000` registre → `170500` détention → `171000` bureau et mirador → `171500` raccord du départ.
  Les migrations #1085 refusent de s'installer sans le moteur (`goulag_moteur_1020_requis`).

## Divergences résolues
- Plan recette 97 : tarifs actuels **577** = 558 + 8 menus du moteur (#1020) + 11 ordres internes (#1085) ;
  photographie historique inchangée (461 lignes, empreinte identique).
- `INVENTAIRE.json` et `ordres_couts.sql` régénérés par `outils/baseline/regenerer-seeds-miroirs.py` :
  19 ajouts goulag, **aucun tarif historique modifié**.
- Épreuves moteur #1020 dans l'arbre commun : trois assertions encodant l'ancienne règle (départ sans jet,
  reliquat calendaire) adaptées (`outils/integration/goulag-1020-adaptation-tests-ordres-internes.diff`).
- Contrat obsolète de corruption (table de paramètres) remplacé par la règle définitive :
  cadeau obligatoire, `min(90, 70 + 10 + 2 × CHARME)`, objet consommé réussite ou échec.
- CI `goulag-survie` : récupère désormais le commit #1085 réellement lu par les bancs.

## Trois validations finales de Fred — éprouvées
1. Absence à minuit sans évasion : statut « Détenu », `present_controle = false`, incident `hors_du_camp`,
   détention ouverte, contrôle idempotent.
2. Transfert d'une détention commencée : jours restants au transfert (10 − 3 = 7), puis sommeil (6) ;
   par le vrai jugement de 30 jours : 7 + 30 = **37**, jugement compté une fois.
3. Corruption réussie : refus `gardien_deja_corrompu` sans consommer d'objet, puis évasion à 95 %.

## Résultats (PostgreSQL 17.6 jetable, macOS 12 ; preuves dans `preuves-goulag-integration-20261117/`)
| Banc | Résultat |
|---|---|
| Ordres internes #1085 (`--moteur-1020 .`) | 38/38 |
| Moteur #1020 avec #1085 | 32/32 |
| Raccords d'intégration (HEAD) | 41/41 |
| Contrats d'intégration (HEAD) | 11/11 |
| Node #1085 + Héros du Travail | 17/17 ; 18/18 contrôles Node du workflow #1020 |
| Chrome 150 : ordres internes / raccord / moteur | 189 rendus / 27 scénarios / 54 rendus (9 langues, RTL) |
| Plan 97, seeds miroirs, workflow | conformes |
| Lanceur officiel `controler-client.py` | 248/386 **identique à main** (mêmes 138 bancs, mêmes épreuves) |

WebKit : non exécutable sur macOS 12, couvert par la CI GitHub.

## CI GitHub
Sur `25f115e` (#1085) et `8a37a17` (#1020) : `ordres-internes` et `descriptions-goulag` verts.
`moteur-survie` rouge sur les deux têtes → **corrigé** (`6012cd8`, référence #1085 non récupérée).
`bancs-hors-production` rouge : `banc-mobile-coque` L1/L2, **mêmes épreuves rouges sur `main` 37bb26c**
(préexistant, chantier mobile hors goulag). `descriptions-tactiles` : démarrage Chromium > 20 s (machine CI),
vert sur main. `guillemets` (#1020) : exécution annulée.

## Limites
Simulations : aucune recette avec un personnage connecté, aucune session GoTrue réelle, aucun téléphone
physique. Aucune compilation sur Supabase de production. Vercel ne déploie que `main` (configuration du
dépôt) : pas de prévisualisation de branche.
