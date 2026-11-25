# Mission de fin de soirée du 25/11/2026 — agent B (1.4, 1.6, 1.8, 1.9, 1.10, 2.1, 2.2, 2.3)

Branche `claude/soir2-b-20261125`, issue de main 50b6f162. Migration écrite, testée en PGlite, **non appliquée** :
`migrations/20261125820000_fin_soiree_regles_chances.sql`. Sans elle, le jeu garde le comportement actuel (chaque appel
d'écran retombe sur l'ancien chemin si la fonction n'existe pas, sans erreur pour le joueur).

## Fait, point par point

- **1.4 Contrebande** : le gain n'existait nulle part (la « Cargaison de contrebande » n'a ni prix ni revente). Il devient un
  réglage MJ : `crim_parametres.contrebande_gain` = 500 (FR et autres devises), `contrebande_gain_soviet` = 100 PSK ; la
  cargaison porte ce gain (`valeur`). Échec repéré par la douane : amende égale au gain, prise sur le liquide puis le compte
  national dans la limite des fonds, plus la recherche ; plus de saisie. Description des trois variantes et message à l'écran
  fidèles (montant payé si le joueur n'a pas tout).
- **1.6 Médaille du Tractorisme** : `souv_novomirsk_medaille` n'est plus achetable (l'emplacement de la liste 3 ne change pas).
  À la Grange Sainte de Novomirsk, « Chanter l'hymne au Tracteur » passe par `tractorisme_chanter_hymne` : paiement de l'ordre
  `prier` (1 PA) et, au premier chant, remise de la médaille avec le message exact de Fred ; mémoire durable
  `tractorisme_medailles` (une fois par personnage). Inventaire plein : la médaille attend le chant suivant. L'église de
  Krasnov ne la donne pas.
- **1.8 Visites** : règles déjà au serveur (410000). L'ordre « Visiter un détenu » est ajouté à l'accueil du commissariat
  central et des commissariats locaux. Textes alignés : « seuls un avocat inscrit au barreau et le conjoint du détenu ».
- **1.9 Mobiliser** : ouvre le syndicat du joueur du pays où il est, sinon n'importe lequel de ses syndicats ; sans syndicat,
  refus expliqué (« Vous n'êtes membre d'aucune organisation syndicale. Fondez-en une ou rejoignez-en une… »).
- **1.10 Censure** : l'indice serveur le plus proche de la popularité du régime en Sovarka est la **popularité du parti au
  pouvoir** (`sovarka_parti_au_pouvoir`, `sovarka_parti_pop_interne`, celle que les manifestations de soutien font monter).
  Règle : censure sans scandale = +3 au parti au pouvoir (immédiat) ; scandale = −5. Le scandale peut désormais éclater en
  Sovarka aussi (même chance que Républia, réglage `censure_scandale_taux` = 30 ; −20 POP pour le ministre). Réglages MJ
  `censure_sovarka_hausse` (3) et `censure_sovarka_baisse` (5). Description et message fidèles.
- **2.1 Bénédiction** : la bénédiction demandée à un religieux présent est accordée au serveur
  (`benediction_contact_demander` : 1 PA, 80 %, 24 h, non cumulable, refusée à l'excommunié ; table `benedictions`). Les jets
  du commissaire (enquête, filature) la consomment au serveur ; le `p_benediction` de l'écran est ignoré. L'écran garde son
  drapeau local pour les autres jets qui le lisent encore (non commissaire).
- **2.2 Charisme** : `presse_cha_effectif_interne` = CHA du serveur − 2 si excommunié + bonus temporaires tenus au serveur
  (`effets_actifs`, deltas CHA non expirés). La moyenne du groupe de l'ancien écran n'est pas reprise (le serveur reste la
  seule source).
- **2.3 Demi-effet** : `ordres_chances_lire` rend `fuite_info_demi` et `soins_discrets_demi` (même jet
  qu'`ordre_generique_executer`) ; la pastille affiche « X % · ½ Y % » et l'infobulle « (demi-effet : Y %) ».

Bancs : nouveau `outils/bancs/banc-fin-soiree-regles-pglite-20261125.cjs` (9/9) ; `banc-audit-chances-soir-pglite` (11/11,
attentes de texte mises à jour) ; `test-*.mjs` 441/441 ; i18n (communes, Républia, communes-fonctions et partage) verts après
mise à jour des décomptes (visite devenue commune, censure réécrite gardée en ligne livrée) ; `test-plan-recette97-219.py` OK ;
`banc-couts-reconciliation-219-local.py` OK ; seeds miroirs régénérés (aucun changement : mêmes triplets de coûts).

## Lignes de suivi (prêtes pour docs/suivi-decisions.md)

| 25/11/2026 | 1.4 Contrebande : un échec repéré par la douane coûte une amende égale au gain qu'aurait rapporté la contrebande (réglage MJ, 500 ; 100 PSK en Sovarka), plus la recherche ; plus de saisie (migration 20261125820000 écrite, non appliquée). | en cours |  |  | Mission de fin de soirée 1.4 |
| 25/11/2026 | 1.6 Médaille du Tractorisme : plus vendue au musée ; offerte au premier chant de l'hymne au Tracteur à la Grange Sainte de Novomirsk, une fois par personnage, avec le message de Fred (migration 20261125820000 écrite, non appliquée). | en cours |  |  | Mission de fin de soirée 1.6 |
| 25/11/2026 | 1.8 Visites en prison : avocat inscrit au barreau et conjoint marié au QHS, une visite par jour par visiteur et par détenu (déjà au serveur) ; ordre de visite ajouté aux commissariats. | en cours |  |  | Mission de fin de soirée 1.8 |
| 25/11/2026 | 1.9 « Mobiliser les membres » ouvre le syndicat du joueur où qu'il soit ; sans syndicat, refus expliqué. | en cours |  |  | Mission de fin de soirée 1.9 |
| 25/11/2026 | 1.10 Censure en Sovarka : +3 à la popularité du parti au pouvoir, −5 si le scandale éclate (scandale possible aussi en Sovarka, même chance) (migration 20261125820000 écrite, non appliquée). | en cours |  |  | Mission de fin de soirée 1.10 |
| 25/11/2026 | 2.1 Bénédiction accordée et tenue par le serveur ; les jets du commissaire la lisent au serveur (migration 20261125820000 écrite, non appliquée). | en cours |  |  | Mission de fin de soirée 2.1 |
| 25/11/2026 | 2.2 Charisme : le serveur seule source, bonus temporaires tenus au serveur compris (migration 20261125820000 écrite, non appliquée). | en cours |  |  | Mission de fin de soirée 2.2 |
| 25/11/2026 | 2.3 Fuite d'information et soins sans trace : chance du demi-effet affichée à côté de celle de l'effet complet (migration 20261125820000 écrite, non appliquée). | en cours |  |  | Mission de fin de soirée 2.3 |

## Migration à valider

`migrations/20261125820000_fin_soiree_regles_chances.sql`, après 20261125700000. Ancrages vérifiés en lecture sur la
production le 25/11 (chacun trouvé une fois) : `jauges_ordre_executer` (deux lignes de la censure), `commissaire_enquete_mener`,
`filature_mener`, `ordres_chances_lire` (ligne d'audit) ; `crime_contrebande` remplacée en entier, garde sur la marque
`audit_chances_contrebande_v1`. Contrôles en lecture (en tête du fichier) :
```sql
SELECT position('contrebande_amende_v1' in pg_get_functiondef('public.crime_contrebande(integer,integer)'::regprocedure)) > 0;   -- vrai
SELECT valeur FROM public.crim_parametres WHERE cle IN ('contrebande_gain', 'contrebande_gain_soviet') ORDER BY cle;           -- 500, 100
SELECT achetable FROM public.souvenirs_objets WHERE cle = 'souv_novomirsk_medaille';                                            -- faux
SELECT has_function_privilege('authenticated', 'public.tractorisme_chanter_hymne(uuid)', 'EXECUTE');                            -- vrai
SELECT position('censure_sovarka_v1' in d) > 0 AND position('censure_sovarka_regime_v1' in d) > 0
  FROM (SELECT pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure) d) x;                          -- vrai
SELECT position('benediction_serveur_v1' in pg_get_functiondef('public.commissaire_enquete_mener(uuid,text,boolean)'::regprocedure)) > 0
   AND position('benediction_serveur_v1' in pg_get_functiondef('public.filature_mener(uuid,text,boolean)'::regprocedure)) > 0;  -- vrai
SELECT has_function_privilege('authenticated', 'public.benediction_contact_demander(uuid,text)', 'EXECUTE');                    -- vrai
SELECT has_function_privilege('authenticated', 'public.benediction_consommer_interne(text)', 'EXECUTE');                        -- faux
SELECT position('cha_serveur_v1' in pg_get_functiondef('public.presse_cha_effectif_interne(text)'::regprocedure)) > 0;         -- vrai
SELECT position('demi_effet_v1' in pg_get_functiondef('public.ordres_chances_lire(text[],text)'::regprocedure)) > 0;           -- vrai
```

## Pour Codex (français nouveau ou changé)

- `data.js` : descriptions de `contrebande_port` (×3, « … un échec repéré vous coûte une amende égale au gain qu'aurait
  rapporté la contrebande. »), `censurer_media` (nouvelle description Républia / Sovarka), `visiter_prisonnier` (×3, « seuls un
  avocat inscrit au barreau et le conjoint du détenu entrent »).
- `plateau-navigation.js` (contrebande) : « Amende de {n} (vous n'avez pu en payer que {p}). », message d'échec repéré.
- `plateau-divers.js` : titre « Médaille du Tractorisme » ; message de la médaille (rendu par le serveur, texte de Fred).
- `plateau-politique.js` (censure) : « Parti au pouvoir : {±n} de popularité. »
- `plateau-justice-economie.js` (visites) : « Quartier de haute sécurité : réservé aux avocats inscrits au barreau et au
  conjoint du détenu. », refus `qhs_avocat_famille`.
- `plateau-organisations-quetes.js` : refus de « Mobiliser les membres » sans syndicat.
- `plateau-chances-reelles.js` : « demi-effet : {n} % » (infobulle) et « ½ {n} % » (pastille).

## Questions de game design

- Contrebande : quel gain pour une cargaison ? Réglé à 500 (100 PSK en Sovarka) faute de prix existant ; la cargaison n'a
  toujours aucun usage ni revente. L'amende va-t-elle dans une caisse (douane, État) ? Aujourd'hui elle est simplement retirée.
- Contrebande : si le joueur n'a pas de quoi payer toute l'amende, seule la part disponible est prise (pas de dette). Faut-il une
  dette ou une peine complémentaire ?
- Médaille : un joueur qui avait déjà chanté avant la migration la reçoit à son prochain chant (aucune trace des chants passés).
- Censure en Sovarka : +3 / −5 au parti au pouvoir et scandale à 30 % comme en Républia (auparavant jamais en Sovarka) : à
  valider.
- Bénédiction : la demande au religieux présent ne vérifie pas au serveur qu'un religieux habilité est bien dans la pièce
  (garde restée à l'écran, comme avant).
- Mobiliser : `state.organisations` ne contient peut-être que les organisations chargées pour le pays courant ; un joueur à
  l'étranger dont le syndicat n'est pas chargé verra le refus.
