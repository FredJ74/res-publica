# Goulag de Sovarka — ordres internes des cinq pièces (décisions du 17 novembre 2026)

Complète [`GAME-DESIGN-GOULAG-SOVARKA.md`](GAME-DESIGN-GOULAG-SOVARKA.md), sans le remplacer. Périmètre : le
**fonctionnement intérieur du camp**. La traversée de la toundra, le refuge et l'arrivée en ville relèvent
du moteur préparé par Codex (PR #1020) et ne sont pas modifiés ici.

**Statut : codé et testé sous verrou, non activé.** Branche `claude/goulag-ordres-internes-20261117`. Toutes
les fonctions serveur refusent (`goulag_non_active`) tant que le moteur #1020 n'est pas installé puis activé
sur autorisation explicite de Fred.

## Décisions de Fred (17/11/2026)

### Entrée du camp — « Consulter la liste des détenus »
- Personnes habilitées présentes à l'entrée. Fenêtre : nom, jours de peine restants, statut
  **Détenu**, **Libération en attente** ou **En fuite**.
- La liste est actualisée par le **contrôle de minuit** (cron serveur quotidien, idempotent). Une évasion à 14 h
  laisse le statut précédent jusqu'à minuit, puis l'absence est constatée : **En fuite**.
- « En fuite » ne diminue ni n'efface le reliquat. « Libération en attente » : peine arrivée à terme, libération
  effective encore à finaliser. L'état administratif est distinct de la présence physique.

### Dortoir des prisonniers
- **Dormir** : +1 PA ; un sommeil valide purge une journée de peine ; le temps écoulé sans sommeil ne réduit
  jamais la peine ; limite quotidienne de sommeil du jeu ; quand le sommeil achève la peine, libération
  automatique et déplacement **devant l'entrée du goulag**.
- **Manger** : +1 PA, au dortoir seulement, fréquence alimentaire du jeu (pas de PA infinis par répétition).
- **Grève de la faim** supprimée du goulag, sans toucher aux prisons de Républia.

### Cachot disciplinaire — « Dormir »
- 0 PA. Chaque sommeil valide purge une journée de peine **et** une nuit de sanction. Deux nuits au plus.
- Dernière nuit : retour automatique au dortoir, sauf si la peine s'achève (libération).
- Motifs : **échec d'évasion** (deux nuits) ou **décision du juge** (une ou deux nuits). Jamais d'enfermement
  indéfini par un compteur incohérent.

### Bureau du chef administratif
- **Consulter le registre** (habilités présents) : nom, tribunal ayant prononcé l'envoi, date d'entrée, date de
  sortie effective, nombre total d'interrogatoires. Historique conservé ; **une évasion n'est jamais une
  libération**. Références judiciaires réelles uniquement, rien de reconstitué.
- **Interroger un détenu** (visiteur habilité présent) : refus si le détenu a 1 PA ou moins ; −7 PA au détenu,
  plancher strict 1 PA ; compteur +1 ; jet de révélation **50 % + 5 points par point de VOL d'écart**
  (interrogateur − détenu), borné **5–95 %**. En cas de réussite, une trace réelle **non encore découverte**,
  tirée au hasard, est envoyée par courrier interne **au seul juge qui a condamné** le détenu. Sans trace
  inconnue : perte de PA et enregistrement conservés, aucun secret. Jamais publique, jamais à tous les juges.
- **Prononcer une sanction disciplinaire** : juge habilité **physiquement présent dans le bureau**, une ou deux
  nuits. Aucune sanction à distance ; aucun pouvoir pour le ministre de la Justice du seul fait de sa fonction.

### Mirador
- **Corrompre le gardien** (détenus) : objet facultatif pris parmi ceux réellement disponibles après
  l'admission (objets transmis par un visiteur via les interactions existantes). Pas d'ordre de remise d'objet.
  Une corruption réussie donne un bonus à la **prochaine** tentative d'évasion, sans garantir la réussite.
- **Consulter les incidents du camp** (habilités présents) : historique daté des tentatives d'évasion et de leur
  résultat, des sanctions disciplinaires et des absences constatées à minuit ; rien d'étranger au goulag.

### Tentative d'évasion depuis le camp
- Jet de **sortie du camp**, distinct de la survie : **80 %**, **95 %** après corruption d'un gardien ;
  **une tentative par jour** ; jet serveur non rejouable.
- Réussite : la traversée démarre (Starovka 7 PA / 7 jours, Krasnov 10 PA / 10 jours), gel du reliquat et départ
  irréversible inchangés. Échec : aucun départ, **deux nuits de cachot**, peine principale conservée, incident.

## Ce qui est codé

| Pièce | Ordre | Fonction serveur |
|---|---|---|
| Entrée | Consulter la liste des détenus | `sovarka_goulag_liste_detenus()` |
| Dortoir | Dormir / Manger | `sovarka_goulag_dormir()` / `sovarka_goulag_manger()` |
| Cachot | Dormir | `sovarka_goulag_dormir()` (même règle quotidienne, 0 PA, nuit de sanction) |
| Bureau | Consulter le registre | `sovarka_goulag_registre_consulter()` |
| Bureau | Interroger un détenu | `sovarka_goulag_detenus_choisir()`, `sovarka_goulag_interroger(détenu, requête)` |
| Bureau | Prononcer une sanction disciplinaire | `sovarka_goulag_sanctionner(détenu, nuits, requête)` |
| Mirador | Corrompre le gardien | `sovarka_goulag_corrompre(requête, index, signature)` |
| Mirador | Consulter les incidents du camp | `sovarka_goulag_incidents_consulter()` |
| Entrée | S'enfuir à pied (jet de sortie) | `goulag_toundra_demarrer` de #1020, complétée par `sovarka_goulag_sortie_jet_interne` |
| Minuit | Contrôle de la liste | `sovarka_goulag_controle_minuit(jour)` (rôle service, cron `controle_goulag_sovarka`) |

Circulation d'un détenu (le moteur général refuse tout déplacement aux détenus) : `sovarka_goulag_detenu_aller`
entre dortoir, entrée et mirador ; jamais le bureau ; aucune sortie du cachot pendant une sanction.

**Choix techniques à connaître :**
- Le **registre** (`sovarka_goulag_registre`) s'ouvre automatiquement à l'admission, à la validation de la
  transaction de condamnation. Il reprend le jugement réel rendu dans cette transaction (tribunal, juge) ; à
  défaut, ces champs restent vides (« Inconnu »). Une réincarcération après évasion reprend le reliquat figé
  et les références de la condamnation initiale.
- **Un seul sommeil par jour de Paris**, marqueur partagé avec le repos général (`pa_repos_le`) : le « Dormir »
  de la fiche est refusé au détenu du goulag (`sommeil_goulag_dortoir`), aucune double récupération.
- La libération au calendrier (`detention_clore_purgee`) est refusée pour une peine du goulag.
- La libération par le sommeil restitue le dépôt (moteur #1020), place le libéré **devant l'entrée** et
  l'enregistre comme présent, pour qu'il reparte par le retour régulier des visiteurs prévu par #1020.
- Le **reliquat figé** au départ d'une évasion est désormais le compteur de jours du registre (sommeil),
  et non plus un calcul calendaire.
- Écritures protégées : verrous de ligne, clé de requête rejouable (interrogatoire, sanction, corruption),
  clé (détention, jour) pour la tentative d'évasion, clé d'idempotence par incident, une ligne par jour de contrôle.

## Points réellement à arbitrer (Fred)

1. **Corruption du gardien** — bloquée (`corruption_a_arbitrer`) tant que ces quatre valeurs ne sont pas
   décidées (table `sovarka_goulag_parametres`, aucune valeur inventée) : chance de base sans objet ; bonus
   apporté par un objet proposé ; l'objet est-il perdu en cas d'échec ; nombre de tentatives par jour.
   Le reste du camp fonctionne sans elles.
2. **Coût en PA de l'interrogateur et du juge** : non précisé ; codé à **0 PA** pour eux (le détenu perd 7 PA).
3. **Détenu hors du camp sans évasion** (par exemple hospitalisé) au contrôle de minuit : codé comme absence
   enregistrée dans les incidents, statut administratif laissé à « Détenu ». À confirmer.
4. **Transfert au goulag d'une détention déjà en cours** (prolongation) : le compteur démarre au reste calendaire
   à l'instant du transfert, puis ne baisse plus qu'au sommeil. À confirmer.

## Dépendances avec la PR #1020

- Ces migrations exigent le moteur #1020 (`goulag_moteur_1020_requis`). Ordre d'installation : migrations #1020,
  puis les quatre migrations `20261117*_goulag_ordres_internes_*`.
- Raccord isolé `20261117171500_goulag_ordres_internes_raccord_evasion.sql` : remplace deux passages exacts de
  `goulag_toundra_demarrer` (jet de sortie ; reliquat issu du sommeil). Échoue explicitement si Codex modifie ces
  passages avant intégration.
- La libération place désormais le libéré devant l'entrée (décision du 17/11) au lieu du centre multimodal prévu
  par #1020 au 16/11.
- Trois assertions des épreuves PostgreSQL de #1020 encodent l'ancienne règle (départ sans jet, reliquat
  calendaire) : adaptation prête dans `outils/integration/goulag-1020-adaptation-tests-ordres-internes.diff`
  (31/31 avec ce chantier).
- Écran : « S'enfuir à pied » de #1020 ouvre le choix de ce chantier (même RPC de départ) ; le routeur partagé
  n'est pas modifié (`doOrder` enveloppé par `plateau-goulag-ordres.js`).
