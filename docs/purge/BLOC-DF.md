# Mission « Purge » du 24/11/2026 — blocs D (climat) et F (images de fontaines)

Branche `claude/purge-df-20261124`. Migrations dans la plage 20261124130000 à 20261124139999. Seule `20261124130000` est
appliquée (par l'agent principal) ; les six migrations du bloc D sont **à appliquer, dans l'ordre**.
Décisions consignées à la source : `GAME-DESIGN-CLIMAT-20261121.md`, section « Décisions de Fred du 24/11/2026 ».

## Suivi

| Date | Point et décision | État | Commit | Source |
|---|---|---|---|---|
| 24/11/2026 | F.1 Fontaine de Luthécia déplacée du parvis de l'Hôtel de Ville vers la place du Formulaire de la Liberté (lieu où l'on entre : « Puiser de l'eau » est un ordre de la pièce « place ») ; ancien point d'eau désactivé et redirigé (`remplace_par`) ; consigne de canicule : cite la place ; image `images/fontaines/luthecia-fontaine-place-formulaire-liberte.webp` (PNG « Fontaine de la Liberté à Paris ») | en ligne | 219e5475 | consigne de Fred, bloc F |
| 24/11/2026 | F.2 Images de Montrouge (place du Rail, PNG « Fontaine historique et locomotive sous la pluie ») et de Port-Sainte-Marie (place d'Armes, PNG « Fontaine historique sur la place pavée au coucher du soleil ») : chemins déjà en base, fichiers déposés | en ligne | 219e5475 | consigne de Fred, bloc F |
| 24/11/2026 | F.3 Fontaine de Novomirsk (place du Peuple) : **image en attente** ; rien créé (`images/fontaines/novomirsk-fontaine-place-peuple.webp` reste absent, la fenêtre s'en passe) | en attente d'image | | consigne de Fred, bloc F |
| 24/11/2026 | D.1 La canicule commence à 12 h (heure de Paris) et dure 6 h ; reports et canicules déjà planifiées ramenés à 12 h (correction publiée si l'alerte était sortie : Montrouge 25/11 21 h → 12 h) | en cours (migration 131000) | 9a860f4f | consigne de Fred, bloc D |
| 24/11/2026 | D.2 Seules canicule et crue arrêtent les chantiers (`bloque_chantiers` faux pour orage et blizzard) ; consigne de l'orage : « … mais les chantiers continuent » ; blizzard seulement à Starovka (`climat_villes_exclues`), blizzards de Novomirsk (28/11) et Krasnov (01/12) annulés | en cours (migration 132000) | 6725bb99 | consigne de Fred, bloc D |
| 24/11/2026 | D.3 L'arrêt de canicule s'applique réellement : nuit suivante sans avance (ligne « canicule » au journal), travail refusé jusqu'à minuit ; décision lue sur la date de l'événement, plus sur la pose des effets ; `api/cron-minuit.js` non modifié | en cours (migration 133000) | 562bb204 | consigne de Fred, bloc D |
| 24/11/2026 | D.4 Zone canicule de la fenêtre du chantier : image `images/chantier-alea-canicule.webp`, bouton « Offrir 20 bouteilles d'eau aux ouvriers » (tout joueur présent, une fois par canicule, 0 PA) avec « ? », ligne au journal du chantier ; l'eau lève l'arrêt de ce chantier (réglage MJ, à confirmer) | en cours (migration 134000) | 0cc32a56 | consigne de Fred, bloc D |
| 24/11/2026 | D.5 Starovka exclue des canicules (déjà vrai en pratique : aucune canicule réglée en Sovarka ; désormais écrit) ; fontaine de Starovka retirée, aucun renvoi dans le vide | en cours (migration 135000) | 7ed16ccc | consigne de Fred, bloc D |
| 24/11/2026 | D.6 Bouteille d'eau à 4 PSK dans les trois boutiques « Équipements contre les intempéries » de Sovarka (Pharmanov et garage à Novomirsk, station-service de Krasnov) | en cours (migration 136000) | f0bf7531 | consigne de Fred, bloc D |

## Migrations à appliquer (dans l'ordre), et contrôle en lecture après

1. `20261124131000_canicule_en_journee.sql` : `climat_canicule_debut_interne`, raccords `climat_creer_interne` et
   `climat_espacer_interne` (marques `canicule_journee_v1`, `canicule_journee_v1a`), réglage `canicule_heure_debut` = 12,
   canicules à venir ramenées à 12 h. Contrôle : `SELECT id, ville, debut AT TIME ZONE 'Europe/Paris' FROM climat_evenements
   WHERE type='canicule' AND NOT annule AND debut > now()` → toutes à 12:00 ; une ligne « Prévisions corrigées : la canicule… »
   dans `evenements_globaux` (Montrouge, alerte déjà publiée).
2. `20261124132000_climat_chantiers_canicule_crue_blizzard_starovka.sql` : `bloque_chantiers` faux (orage, blizzard), consigne de
   l'orage, table `climat_villes_exclues`, `climat_ville_exclue_interne`, raccords `climat_creer_interne` et `admin_climat_creer`
   (`climat_ville_exclue_v1`), blizzards hors Starovka annulés. Contrôle : `SELECT type, pays, bloque_chantiers FROM
   climat_parametres` ; `SELECT climat_consigne_interne('orage','republic','capitale')` contient « mais les chantiers continuent » ;
   `SELECT id, ville, annule FROM climat_evenements WHERE type='blizzard' AND debut > now()` → seul Starovka (ville_a) non annulé.
3. `20261124133000_climat_arret_chantier_nuit.sql` : `climat_chantiers_bloques_interne` et `chantier_crue_jour_interne` réécrites
   (fonctions propres au climat ; marque `climat_arret_journee_v1`). Contrôle : `pg_get_functiondef` des deux contient
   `climat_arret_journee_v1` ; `chantier_jour_traiter` garde sa ligne `crue_chantier_jour_v1`.
4. `20261124134000_chantier_canicule_eau_ouvriers.sql` : RPC `chantier_canicule_offrir_eau`, `chantier_climat_etat` (authenticated),
   internes `climat_canicule_arret_interne`, `chantier_eau_offerte_interne`, `chantier_de_terrain_interne`,
   `climat_chantier_bloque_interne` ; raccords `chantier_crue_jour_interne` et `chantier_travailler` (`canicule_eau_ouvriers_v1`) ;
   réglages `canicule_eau_ouvriers_bouteilles` = 20, `canicule_eau_leve_arret` = 1. Contrôle : les deux marques présentes ;
   `SELECT has_function_privilege('authenticated','public.chantier_canicule_offrir_eau(uuid,text)','execute')` → vrai.
5. `20261124135000_starovka_sans_canicule_ni_fontaine.sql` : ligne canicule/Starovka dans `climat_villes_exclues`, fontaine
   `starovka-fontaine-mairie` désactivée. Contrôle : `SELECT id, actif FROM climat_points_eau` → 5 actives, Starovka inactive.
6. `20261124136000_bouteille_eau_sovarka.sql` : réglage `prix_bouteille_eau_sovarka` = 4, `climat_prix_pays_interne`
   (`bouteille_eau_sovarka_v1`), `bouteille_eau` dans les trois boutiques climat de Sovarka. Contrôle : `SELECT id, cles FROM
   climat_boutiques WHERE pays='soviet'` ; `SELECT climat_prix_pays_interne('bouteille_eau','soviet')` → 4.

Aucune ne touche le goulag, `api/cron-minuit.js` ni `chantier_jour_traiter`. Ordre payant : aucun ajouté ni retiré
(l'offre d'eau est gratuite et ne passe pas par `payer_ordre`).

## Bancs (tous verts en local)

- `outils/bancs/banc-purge-fontaines-20261124.cjs` (statique + PGlite) : F.1, F.2, D.5.
- `outils/bancs/banc-purge-climat-pglite-20261124.cjs` (PGlite, socles chantier et crue-chantier + complément
  `fixtures/purge-climat-pglite-complement.sql.txt` en définitions de production) : D.1 à D.6, avant / après, rejouabilité.
- `outils/bancs/banc-purge-canicule-chantier-navigateur-20261124.cjs` (Chromium réel, 390 et 1280 px) : zone canicule, « ? », don, journal.
- Workflow `.github/workflows/purge-climat-fontaines-20261124.yml` (les trois bancs).
- Rejoués sans régression : bancs climat (`test-climat-*`, `banc-climat-*-navigateur`, `banc-texte-meteo-navigateur`),
  `banc-point-eau-pglite`, `banc-crue-chantier-pglite`, `test-krasnov-lot-suite`, bancs du bloc C (`banc-purge-c-chantier*`,
  `banc-chantier-vue-navigateur`).

## Pour Codex (textes français nouveaux ou changés, à traduire)

- `plateau-climat.js`, `EAU_TXT.ailleurs` : « Il n’y a pas de point d’eau ici : chaque ville a sa fontaine, sur sa place principale
  (à Krasnov, la place de l’Ours ; à Luthécia, la place du Formulaire de la Liberté), sauf Starovka, qui n’en a pas. »
- `plateau-climat.js`, ordre de pièce « Puiser de l’eau » : `desc` « Eau gratuite : 1 PA par puisage, jusqu’à 10 bouteilles toutes les 6 heures. »
- `plateau-climat.js`, `EXPLIC.fr.chantiers_canicule` : « Tous les chantiers de la ville sont à l’arrêt jusqu’à minuit : ils prennent
  un jour de retard, sauf ceux où un joueur offre de l’eau aux ouvriers. »
- `plateau-climat.js`, `CHANTIER_CANICULE_TXT` (toutes les clés : titre, arret, offrir, aide, aide_sans_levee, possede, offerte,
  offerte_sans_levee, merci, r_bouteilles_insuffisantes, r_deja_offerte, r_pas_de_canicule, r_pas_sur_le_chantier,
  r_pas_de_chantier, aide_label, j_canicule, j_eau_offerte).
- Serveur, `climat_consigne_interne` (orage) : « … ni de piratage, mais les chantiers continuent. Débranchez… ».
- Serveur, `climat_points_eau.nom` : « la fontaine de la place du Formulaire de la Liberté, à Luthécia ».
- Serveur, `evenements_globaux` (corrections) : « ⚠️ Prévisions corrigées : la canicule annoncée à {ville}, {quand}, commencera
  {quand} : la canicule ne frappe qu'en journée, de 12 h à 18 h. » ; « ⚠️ Prévisions corrigées : l'alerte « {type} » à {ville},
  {quand}, est levée. »
- Le catalogue i18n n'a pas été modifié.

## Questions de game design (non tranchées)

- D.4 : effet du don de 20 bouteilles — Claude l'a fait **lever l'arrêt de canicule pour ce chantier** (réglage MJ
  `canicule_eau_leve_arret`, 0 = simple geste inscrit au journal). À confirmer.
- D.4 : coût du don (aujourd'hui 0 PA, 0 argent, seulement les 20 bouteilles) ; le maître d'ouvrage est-il averti par courrier ?
- D.4 : l'achat en boutique est plafonné à 10 bouteilles par achat : il faut deux achats (ou puiser 10 + 10 à la fontaine en
  deux tranches de 6 h) pour réunir 20 bouteilles.
- D.2 : le blizzard ne frappe plus qu'une ville : sa fréquence (une fois par mandat présidentiel) reste-t-elle la bonne ?
- D.5 / D.6 : Starovka n'a ni fontaine ni boutique climat : l'eau n'y est disponible qu'apportée d'une autre ville (sans effet
  aujourd'hui, Starovka n'ayant pas de canicule).
- F : image « Fontaine baroque au crépuscule à Paris » (Downloads, 23/11 18:16) non branchée : aucune correspondance évidente.
- Place du Formulaire de la Liberté : le point d'eau est le lieu entier (pièce « place ») ; si la place reçoit d'autres pièces,
  préciser la pièce de la fontaine.
- Blocus syndical : un blocus de la place du Formulaire de la Liberté ne bloque pas « Puiser de l'eau » (ordre absent de
  `blocus_ordres_batiments`), comme les fontaines de rue.

## Ce qui reste

- Appliquer les migrations 131000 à 136000 (agent principal), puis les contrôles ci-dessus.
- F.3 : image de la fontaine de Novomirsk à fournir par Fred.
- Traductions (Codex, 27/11).
