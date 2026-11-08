# Relevé de la base Supabase active — lecture seule

**9 novembre 2026, projet `res-publica` (référence `jxpwoosmmhohoihxpbuc`).** Interrogations **strictement SELECT** sur les catalogues PostgreSQL et deux tables de **règles statiques**, plus lecture du registre des migrations Supabase. Aucune table contenant les informations d'un personnage, aucun inventaire ou solde de PJ, aucune modification de base, aucun ordre de jeu exécuté.

## Inventaire constaté sur le serveur
| Objet | Mesure directe | Méthode |
|---|---:|---|
| Tables physiques `public` | **444** | `information_schema.tables`, `BASE TABLE` |
| Tables physiques `public` avec RLS activé | **444** | `pg_class.relrowsecurity` |
| Fonctions `public` (toutes signatures) | **1 605** | `pg_proc` + `pg_namespace` |
| Politiques RLS `public` | **249** | `pg_policies` |
| Vues `public` | **3** | `information_schema.views` |
| Entrées du registre de migrations Supabase | **1 317** | lecture du registre par le connecteur |

**Comparaison :** `ARCHITECTURE.md` donnait **357 tables et 1 058 fonctions**, chiffre historique d'octobre. Cela représente **+87 tables publiques et +547 fonctions publiques** au sens des comptages ci-dessus, sous réserve que le périmètre de comptage historique ait été identique ; ce n'est pas une croissance fonctionnelle prouvée. Les **297 fichiers SQL** de `migrations/` sur GitHub ne représentent pas les **1 317 entrées historiques** du registre (voir `historique/`). Il ne faut pas mettre ces chiffres en concurrence : leur périmètre est différent.

**Prudence sécurité :** RLS activé sur une table ne suffit pas à certifier les politiques, les vues, les droits `GRANT` ou les fonctions `SECURITY DEFINER`. Aucun audit ACL exhaustif n'a été réalisé à ce stade.

## Chantier naval : règles actives en base

La table `public.chantier_naval_modeles` contient actuellement :

| Code | Personnes | Fret | Prix FR | Bois | Métal | Dérivés | Jours effectifs |
|---|---:|---:|---:|---:|---:|---:|---:|
| `bateau_3` | 3 | 300 | 90 000 | 1 200 | 1 200 | 600 | 7 |
| `bateau_5` | 5 | 500 | 150 000 | 1 800 | 1 800 | 600 | 10 |

**Statut : configuration serveur vérifiée**, conforme à `GAME-DESIGN-CHANTIER-NAVAL.md` et aux identifiants de `plateau-naval.js`. **Aucune contradiction prouvée** entre la règle écrite, les identifiants du client et le catalogue SQL vivant au 9 novembre. Une variante historique éventuelle ne saurait être retenue sans source explicite datée. Aucun achat, aucune commande et aucune navigation privée n'ont été exécutés.

Tables présentes : `chantier_naval_modeles`, `chantier_naval_commandes`, `chantier_naval_bateaux`. Fonctions observées : `chantier_naval_devis`, `chantier_naval_commander`, `chantier_naval_mes_commandes`, `chantier_naval_avancer_interne`, `chantier_naval_avancer_jour`. Leurs signatures ont été lues dans `pg_proc`, leur **corps et leurs droits d'exécution n'ont pas encore été audités**.

## PNJ sociaux : règles actives en base

La table de règles `public.pnj_social_jalons_regles` contient deux lignes :

| Identifiant PNJ | Événement | Nombre minimal de rencontres | Nombre maximal de conversations |
|---|---|---:|---:|
| `jean_lou_demer` | `abordage_deuxieme_visite` | 2 | 0 |
| `marine_leroux` | `accueil_premiere_visite` | 1 | NULL |

Trois tables repérées : `pnj_social_escort_choisi`, `pnj_social_jalons_regles`, `pnj_social_relations`. Trois fonctions trouvées : `pnj_social_entrer(p_pnj_id text)`, `pnj_social_contexte(p_pnj_id text)`, `pnj_social_noter(p_pnj_id text, p_evenement text)`. Cela prouve le **socle stocké et ses portes RPC**, non le déclenchement réel en session ou le rappel conversationnel DeepSeek. Les relations privées n'ont pas été consultées.

## Migrations recoupées avec le registre Supabase
Les entrées suivantes ont été **effectivement trouvées dans le registre lu** (numéro de version réel distinct parfois du nom et de l'horodatage du fichier) :

| Version registre | Nom enregistré |
|---|---|
| `20260929070539` | `pnj_social_relations` |
| `20261104225620` | `chantier_naval_modeles_devis` |
| `20261104225625` | `chantier_naval_construction_transactionnelle` |
| `20261107235247` | `sovarka_deputes_salle_partis_20261108004500` |
| `20261108204424` | `sovarka_palais_presidentiel_20261108190500` |
| `20261108211644` | `sovarka_greffe_tribunal_populaire_20261108224500` |
| `20261108225901` | `sovarka_justice_circuit_20261108230000` |

Ces dernières entrées recoupent les déclarations d'application de `RELAIS.md` pour Sovarka. **Présence au registre ≠ succès de toutes les actions de justice / pouvoir**, et ne donne pas de preuve de l'identité du client, du contenu des ordres, ni de la recette réelle. Il reste à examiner fonctions, politiques, données de configuration, routeurs et tests.

## Catalogue d'ordres et villes — existence vérifiée

- `ordres_couts` : **517 lignes**, exportées intégralement dans [CATALOGUE-COUTS-SERVEUR.md](CATALOGUE-COUTS-SERVEUR.md) ; ce nombre ne doit pas être comparé sans retraitement aux 346 actions différentes d'octobre (`fn` peut être une variante, une fonction inactive ou un coût de branche conditionnelle).
- `ordres_generiques` : **6 règles de fonction** actuellement configurées : `deliberer_loge` (100 %, +3 INF), `fuite_info` (60 %, +5 INF et +10 POP), `interroger` (75 %, +5 INF, commissaire), `interroger_renseignement` (75 %, +5 INF, ministre de la Défense), `soins_discrets` (95 %, +30 santé, -2 discrétion), `soins_urgence` (100 %, +40 santé). Ces **champs stockés** n'établissent ni coût PA ni droit d'accès complet, et le comportement dépend de la fonction serveur.
- `villes` : **12 lignes**, correspondant au référentiel de `data.js` pour `republic`, `soviet`, `narco`, `khalija` (trois villes chacun). **Un nom en base n'implique pas qu'une ville soit terminée ou ouverte aux joueurs.**
- `ordres_couts_inconnus` : **8 lignes** existent, non examinées (peuvent signaler des écarts de prix rencontrés). Évaluer avant toute déclaration d'exhaustivité de la couverture des ordres.

## Conclusion probatoire
- **Vérifié :** existence de tables/fonctions/registre, règle des deux modèles navals, deux jalons PNJ sociaux.
- **Non vérifié :** permissions de chaque action, exactitude opérationnelle des RPC, cohérence client/serveur de toutes les transactions, activation de traduction, déploiement Vercel, jouabilité humaine.
- **Intention de sécurité respectée :** aucun accès ni modification aux données des joueurs.
