# Disk IO — suspects, classés par ce que le code prouve

> **Audit statique du 8 octobre 2026.** **Aucun accès à Supabase**, aucune
> mesure. Ce document liste des **suspects** et, pour chacun, **la requête de
> mesure qui le confirmera ou l'innocentera**. Il ne contient aucune
> optimisation : optimiser avant d'avoir mesuré, c'est déplacer le problème.
>
> Classes : **A** = le code prouve à la fois le volume et la fréquence ·
> **B** = le mécanisme est coûteux, un des deux facteurs n'est pas établi ·
> **C** = plausible, mais le code ne le prouve pas.

---

## 0. Le cadrage qui change la lecture de tout le reste

`baseline/classification-donnees.csv`, point de coupe du **5 octobre 2026 à
15 h 17**, donne une base **minuscule**. La seule table au-dessus de 500 lignes
est `historique_deplacements` (**10 429**). Ensuite : `ordres_couts` 405,
`cron_journal` 254, `dotations_amorcage_caisses` 159, `entrepot_journal` 151,
`caisses_batiments` 151, `personnages_supprimes` 135, `pnj_membres` 105.
`batiments_etat` 38, `cycles_electoraux` 13, `terrains_etat` 5,
**`personnages_donnees` 7**, `mails` 31, `messages_chat` 0.

> **Conséquence : aucun suspect ne peut être classé A sur un argument de volume
> de lignes.** Le code prouve en revanche des **fréquences** élevées et des
> **réécritures de lignes larges**. C'est là que tout se concentre, et c'est
> pourquoi les mesures recommandées portent d'abord sur `calls` et `n_tup_upd`,
> jamais sur le temps d'exécution.

Point de vocabulaire : `personnages` **n'est pas une table** mais une vue sans
`security_invoker` au-dessus de `personnages_donnees`, dont chaque ligne évalue
`auth.uid()` et `est_appel_serveur()` dans douze `CASE`. Toute lecture
« personnages » les paie.

---

## 1. Classe A — deux suspects, et ils sont le même minuteur

### A1 — La sauvegarde du personnage toutes les 30 secondes, sans comparaison de contenu

**Le candidat le plus net de tout l'audit.** `sbVerifierEtSauvegarderPersonnage`
lit `updated_at`, le compare au dernier connu, et sauvegarde si personne d'autre
n'a écrit. **La garde ne compare jamais le contenu.** Dans le cas normal — un
seul onglet, joueur inactif — la condition est fausse et la sauvegarde part.

Donc : **1 SELECT + 1 PATCH des 48 colonnes, toutes les 30 secondes, par onglet
ouvert, même si rien n'a changé.** Le payload est complet, sans diff, sans
sélection des colonnes modifiées. Et `personnages_donnees` porte **~35 colonnes
`jsonb`**, dont plusieurs croissent sans borne structurelle : `journal`,
`inventory`, `historique_crimes`, `recherche`, `enquetes_en_cours`,
`convocations`, `informateurs`, `contacts`, `employes`, `qualifications`,
`effets_actifs`.

`journal` en particulier — le journal de bord complet du personnage — est
renvoyé **en entier** toutes les trente secondes. C'est exactement le motif
« réécriture du TOAST entier pour modifier un seul champ », et ici pour ne
modifier aucun champ.

**Mesures, dans cet ordre :**

1. `SELECT n_tup_upd, n_tup_hot_upd, n_tup_newpage_upd FROM pg_stat_user_tables
   WHERE relname = 'personnages_donnees';` — **avec 7 lignes en table, un
   `n_tup_upd` de plusieurs centaines de milliers EST la preuve.** Un rapport
   `n_tup_hot_upd / n_tup_upd` bas signifie que chaque UPDATE crée une nouvelle
   page ;
2. `pg_stat_statements` filtré sur `UPDATE … personnages` : `calls`,
   `total_exec_time`, `rows` ;
3. `pg_size_pretty(pg_relation_size(...))` et `pg_total_relation_size(...)` :
   l'écart avec 7 lignes **mesure le bloat accumulé** ;
4. `n_dead_tup` et `last_autovacuum` : si autovacuum tourne en boucle sur cette
   table, l'I/O est là.

### A2 — Le bloc de polling de 30 secondes, et l'onglet qu'on oublie

Huit requêtes par cycle et par onglet : upsert `presences`, RPC
`deplacement_enregistrer`, `sbGetPresencesInRoom`, **`sbListPersonnages`** (deux
fois : titulaires de postes électifs, puis cache des photos),
`rafraichirAssembleeInterdictions`, `camionRafraichirContexte`, et A1.

**Rien ne suspend ces minuteurs sur `visibilitychange`.** Un onglet oublié en
arrière-plan polle indéfiniment — et le dépôt confirme que ce scénario s'est
déjà produit en production : « un onglet oublié republiait aveuglément son état
périmé toutes les 30 s ».

Cumul de tous les minuteurs permanents, par la seule lecture du code :
**35 à 45 requêtes par minute et par onglet ouvert**, soit 2 000 à 2 700 par
heure et par onglet.

**Mesures :**

- Dashboard Supabase → API Gateway, **requêtes par minute sur 24 h**. Un
  plancher nocturne non nul alors que personne ne joue prouverait les onglets
  oubliés — et désignerait le polling, pas le cron ;
- `pg_stat_statements` trié par **`calls DESC LIMIT 30`**. L'ordre des dix
  premières lignes devrait reproduire le tableau du §4 ; s'il ne le reproduit
  pas, cet audit est à revoir ;
- `pg_stat_database` : `blks_read` contre `blks_hit` — dit si on lit le disque ou
  le cache, question préalable à toute conclusion sur un « Disk IO Budget » ;
- `pg_stat_bgwriter` : `checkpoints_timed`, `checkpoints_req`,
  `buffers_checkpoint`, `buffers_backend`. **Si le coût est en écriture
  (hypothèse A1), c'est ici qu'il se verra, pas dans `pg_stat_statements`.**

---

## 2. Classe B

| Suspect | Ce que le code prouve | Ce qui manque |
|---|---|---|
| **`championnat.data` lu en entier deux fois par 20 s et par onglet** | `sbLireChampionnat` fait un `sbGet` **sans `select=`**, donc ramène `data` en entier ; `tickFootballLive` tourne toutes les 20 s et déclenche **deux** lectures. Le blob contient le calendrier complet de la saison, tous les matchs, les événements minute par minute, les compositions et le live | sa **taille** : `SELECT pg_column_size(data) FROM championnat WHERE id = 2;` répond en une ligne |
| **`sbListPersonnages()` non borné** | 30 sites d'appel, dont **deux dans la boucle de 30 s** ; lecture de la vue entière, douze `CASE` évalués par ligne | le volume : 7 lignes aujourd'hui. Le coût est en **nombre d'appels**, pas en pages lues |
| **`sbAMessagesNonLus`, toutes les 15 s** | `messages_chat` en `ORDER BY created_at DESC LIMIT 200` **sans index sur `created_at`** → seq scan + tri top-N ; puis `salons_membres` filtré sur `membre`, **non indexé** ; puis **un `sbGet` sur `lectures_chat` par conversation** (N+1) | le nombre d'itérations du N+1 |
| **`mails` en `or=(to_player, from_player, from_real)`, toutes les 60 s** | **aucun** de ces trois champs n'est indexé, ni `created_at` ; `mails` n'a que sa clé primaire | — |
| **`forum_posts` / `forum_topics`, toutes les 60 s** | aucun index hors clé primaire, et un sondage paginé avec join `forum_topics!inner` | — |

**Mesures communes :** `pg_stat_user_tables` (`seq_scan`, `seq_tup_read`,
`idx_scan`) sur `mails`, `messages_chat`, `salons_membres`, `forum_posts`,
`forum_topics` ; et `pg_stat_statements` trié par `calls DESC` en cherchant la
signature exacte d'un N+1 — **un `calls` très élevé avec un `mean_exec_time`
très bas**. Les deux requêtes à regarder d'abord sont
`FROM lectures_chat WHERE id = $1` et `FROM salons_chat WHERE id = $1`.

Pour le championnat : `pg_statio_user_tables`, `toast_blks_read` contre
`toast_blks_hit`. **C'est la mesure décisive** — un `toast_blks_read` élevé
prouve l'I/O disque, un `toast_blks_hit` élevé l'innocente.

---

## 3. Classe C — plausible, non prouvé

- **Le cron de minuit** : 265 appels Supabase (116 `sbGet`, 88 `sbUpdate`, 36
  `sbInsert`, 25 `sbRpc`), dix-huit tâches, cinq passes read-modify-write sur
  `terrains_etat`, et le registre `joursCron` écrit **puis relu** dix-huit fois
  sur **la même ligne**. Mais **une fois par nuit, sur des tables de 5 à 38
  lignes** : cela ne peut pas, seul, épuiser un budget d'I/O. Le code ne prouve
  pas le contraire et je ne vais pas au-delà.
  **Mesure :** `pg_stat_statements_reset()` juste avant 23 h 00 UTC, extraction à
  23 h 10 — le seul moyen d'isoler la contribution du cron du bruit du polling.
- **Colonnes non indexées à faible fréquence** : `terrains_etat(proprietaire)`,
  `dons_en_attente`, `vols_en_attente`, impacts, `souvenirs_accueil(revele)`.

**Déjà correctement indexés, à ne pas suspecter** : `presences`,
`objets_recus(destinataire)`, `batiments_fermes(pays, ville)`,
`evenements_globaux`, `historique_deplacements`, `offres(destinataire, statut)`,
`batiments_etat(country, city, building_id)`, toute la famille `pnj_*`.

**Déjà traité, à ne pas rouvrir** : `sbUpdatePresence` n'insère dans
`historique_deplacements` **que si la position a changé**. Les 10 429 lignes de
cette table sont l'héritage documenté de l'époque où ce n'était pas le cas — « 98 %
des lignes répétaient la précédente à l'identique ». Ce point est fermé.

---

## 4. Les minuteurs du navigateur, par période

Tous armés au démarrage, donc **par onglet ouvert**.

| Période | Ce qui part |
|---|---|
| **4 s** | `messages_chat` filtré et **incrémental** (`created_at=gt.`) — uniquement panneau de chat ouvert, `clearInterval` à la fermeture. **Correctement borné** |
| **10 s** | état du camion — uniquement à bord, arrêté en descendant |
| **15 s** | `messages_chat` top-200 + `salons_membres` + un `lectures_chat` par conversation |
| **20 s** | **deux lectures intégrales de `championnat.data`** |
| **30 s** | les huit requêtes du §A2 |
| **60 s** | `mails` en `or=` ; pagination forum |
| **90 s** | 2 × `evenements_globaux` (indexés) + 3 lectures non indexées |
| **120 s** | `objets_recus`, `batiments_fermes` (indexés) |
| **300 s** | championnat, organisations, version |

---

## 5. Les trois requêtes à lancer avant toutes les autres

Elles départagent « lecture » et « écriture », ce que le code seul ne peut pas
faire :

1. `n_tup_upd` sur `personnages_donnees` — teste le suspect A1, le seul classé A
   sur un argument de volume **et** de fréquence ;
2. `pg_stat_statements` trié par `calls DESC` — teste la thèse « beaucoup de
   petites requêtes » ;
3. `pg_stat_database.blks_read` contre `blks_hit`, plus `pg_stat_bgwriter` — dit
   si le budget part en lecture disque ou en checkpoints d'écriture.

Toutes les trois sont en **lecture seule** et ne touchent aucune donnée de jeu.

---

## 6. Décisions de game design

**Aucune.** La performance ne tranche aucune règle. Un seul point frôle le game
design et il faut le nommer : suspendre le polling d'un onglet caché change ce
qu'un joueur voit en revenant d'un onglet d'arrière-plan. Ce n'est pas un
arbitrage à prendre maintenant — il ne se pose que si la mesure 2 désigne le
polling.
