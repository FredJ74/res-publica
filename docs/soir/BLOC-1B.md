# Mission du soir du 25/11/2026 — bloc 1B (point 1.2) : les jets du navigateur passent au serveur

Branche `claude/soir-b1b-20261125`. Principe de Fred : même formule, coût payé dans la même transaction que le jet, aucune
règle changée. Source : `docs/nuit/AUDIT-CHANCES-20261125.md`.

Migration **écrite, testée en PGlite, NON appliquée** : `migrations/20261125500000_jets_navigateur_serveur.sql`. Sans elle,
l'écran garde exactement son comportement actuel (repli sur le code PostgREST `PGRST202`, aucune erreur pour le joueur).
Ancrages des cinq remplacements contrôlés vérifiés en lecture sur la production le 25/11 (chacun trouvé une fois).

## Fait, ordre par ordre

| Ordre | Avant | Après (avec la migration) |
|---|---|---|
| Placer un article favorable (`article`) | dé, PA, prix, versement à la rédaction et chronique décidés par le navigateur | `presse_lobbying_tenter` : même formule clamp(5, 95, 75 + 2 × (CHA − 13)), base 10 si la cible est étouffée ; CHA effectif (excommunication −2) ; 1 PA dans les deux cas, 500 seulement à la réussite, versés à la caisse « rédaction » du lieu (rendus si ce journal n'en a pas, comme avant) ; article inscrit à la chronique au pays de la cible |
| Contrer une campagne de presse (`etouffer`) | idem, étouffement écrit par le navigateur | même porte : base 70 ; réussite = 1 PA + 1000 à la rédaction + étouffement de 7 jours ; échec = 1 PA |
| Demander à parler à quelqu'un (`demander_parler_loge`) | dé à 95 % dans le navigateur | `loge_frapper` : 1 PA et réponse à 95 % dans la même transaction |
| Corrompre un journaliste (`corrompre_journaliste`) | malus de sécurité fourni par le navigateur ; accord payé ensuite, à part | `corruption_presse_tenter` : malus lu au serveur (`crime_malus_isn_interne`, ville où l'on se trouve) ; en cas d'accord, 2 PA + 500 payés dans la fonction et versés à la rédaction ; blocus syndical refusé avant le jet |
| Fabriquer un scandale (`fabriquer_scandale`) | idem | `scandale_tenter` : même chose (3 PA + 800) ; le blocus est refusé avant que la tentative du jour soit consommée |
| Organiser une filature (`organiser_filature`) | caisse du commissariat et PA payés à part, avant un jet relançable ; PA retirés seulement à l'écran | `filature_mener(p_requete, …)` : caisse (150) et 2 PA pris au serveur avant le jet, une seule fois par requête ; depuis la ville du poste |
| Mener l'enquête (`mener_enquete`) | idem ; « sans trace » conclu par le navigateur | `commissaire_enquete_mener(p_requete, …)` : caisse (250) et 2 PA avant le jet ; sans trace contre la cible, « infructueuse » au serveur, sans jet |
| Censurer un média (`censurer_media`) | −8 à l'indice social appliqué au seul affichage | posé au serveur, après le paiement, sur les villes du pays (Républia : seules villes dont l'indice est tenu par le serveur) ; l'écran relit |
| Consulter des dossiers (`consulter_dossiers_gouv`) | dossier tiré par le navigateur | dossier tiré au serveur (`dossier_rang`, 0 à 5) |

« Vos chances réelles : X % » : `article`, `etouffer`, `demander_parler_loge`, `corrompre_journaliste`,
`fabriquer_scandale` (pastille des boutons, `plateau-chances-reelles.js`, lecture `ordres_chances_lire`). Filature et
enquête dépendent de la cible : pas de pastille avant le choix. Article : la pastille donne la chance sans étouffement (la
cible n'est pas encore choisie) ; la description l'annonce.

Descriptions (`data.js`) : plus aucun pourcentage écrit en dur pour ces cinq ordres ; l'article et l'étouffement annoncent
« 1 PA est pris même si la rédaction refuse » ; la corruption annonce la dénonciation possible et la tentative unique par
affaire.

Défaut réparé au passage : après une filature réussie, le journal citait une variable `taux` inexistante (erreur dans le
navigateur à chaque réussite) ; il cite désormais la chance rendue par le serveur.

## Lignes de suivi prêtes

| Date | Décision | État | En ligne le | Commit | Source |
|---|---|---|---|---|---|
| 25/11/2026 | 1.2 Article favorable et contrer une campagne de presse : jet, PA, prix, versement à la rédaction et effet au serveur, même formule (migration 20261125500000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.2 |
| 25/11/2026 | 1.2 Demander à parler à quelqu'un (loge) : PA et réponse à 95 % au serveur (migration 20261125500000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.2 |
| 25/11/2026 | 1.2 Corrompre un journaliste et fabriquer un scandale : malus de sécurité lu au serveur, accord payé dans la transaction du jet (migration 20261125500000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.2 |
| 25/11/2026 | 1.2 Filature et enquête du commissaire : caisse et PA pris avant le jet, une fois par requête ; enquête sans trace conclue au serveur (migration 20261125500000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.2 |
| 25/11/2026 | 1.2 Censure (−8 indice social) et consultation des dossiers (tirage) décidées au serveur (migration 20261125500000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.2 |

## Migration à valider

1. `20261125500000_jets_navigateur_serveur.sql` (après 20261125130000, appliquée). Contrôles en lecture (en tête du fichier) :
   - `has_function_privilege('authenticated', …)` vrai pour `presse_lobbying_tenter(uuid,text,text,text,text,text)`,
     `loge_frapper(uuid)`, `commissaire_enquete_mener(uuid,text,boolean)`, `filature_mener(uuid,text,boolean)` ;
   - faux pour `jets_pa_prelever_interne(text,text,integer)` ;
   - marques présentes : `jets_b1b_paie_v1` et `jets_b1b_isn_v1` dans `corruption_presse_tenter` et `scandale_tenter`,
     `jets_b1b_jauges_v1` dans `jauges_ordre_executer`, `jets_b1b_chances_v1` dans `ordres_chances_lire`.
   **Coordination** : si le bloc 1A réécrit `ordres_chances_lire` en entier, l'appliquer AVANT celle-ci (son ancrage
   `ELSIF f = 'neutraliser' AND p_cible IS NOT NULL THEN` doit subsister), ou reprendre la branche `jets_b1b_chances_v1`.

## Bancs

- `outils/bancs/banc-jets-serveur-b1b-pglite-20261125.cjs` (12 tests, PGlite avec les corps de production de
  `corruption_presse_tenter` et `scandale_tenter` recopiés mot pour mot) : issues réussite / échec et leur comptabilité,
  rejeu sans double prélèvement, étouffement de 7 jours puis base 10, rédaction sans caisse (argent rendu),
  excommunication, ISN du serveur (celui de l'écran ignoré), blocus avant le jet, caisse du commissariat avant le jet,
  hors juridiction, caisse vide sans PA pris, censure après paiement seulement, dossiers tirés au serveur, chances réelles,
  migration rejouable ; partie statique : portes appelées, repli PGRST202, descriptions sans pourcentage.
- Bancs existants rejoués verts : `banc-chances-reelles-pglite-20261125`, `banc-jauges-ordres-379`,
  `banc-groupes-interieurs-client` (et les bancs liés de `controler-client.py --modifies-depuis origin/main`, voir le rapport).

## Pour Codex (français nouveau ou changé)

- `data.js` : descriptions de `article` (trois copies, dont celle « article intégré à une prochaine édition »),
  `etouffer` (trois), `demander_parler_loge`, `corrompre_journaliste` (trois), `fabriquer_scandale` (trois) — clés de
  `i18n/infobulles-communes-resources.js` à remplacer (texte français exact).
- `plateau-pnj.js` `rendreIssueLobbyingPresse` : « Ce journal n'a pas de caisse éditoriale : rien ne vous a été prélevé, à
  part le PA. », « -1 PA, aucun argent prélevé. », journaux « Article favorable obtenu pour … », « … refusée par la
  rédaction pour … -1 PA. ».
- `plateau-actions-illegales-rumeurs.js` : « Un blocus syndical paralyse ce lieu : la rédaction ne reçoit personne. »
- `plateau-justice-economie.js` : titres « Enquête impossible », « Filature impossible ».

## Questions de game design

- La bénédiction (+5 aux jets du commissaire) reste DÉCLARÉE par l'écran (`p_benediction`), comme avant : faut-il la
  tenir au serveur (elle vit dans la fiche, `benediction.actif`) ?
- CHA effectif : l'écran faisait la moyenne du groupe et ajoutait les bonus temporaires (Estadine +2 CHA) ; le serveur
  reprend la caractéristique de base moins l'excommunication, comme les autres jets déjà passés au serveur. Garder ainsi ?
- L'indice social des empires autres que la Républia n'est tenu par aucune table serveur : la censure n'y change rien
  (avant, seulement l'affichage du moment).
