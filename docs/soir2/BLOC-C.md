# Mission de fin de soirée du 25/11/2026 — bloc C (points 1.5 et 3.1)

Branche `claude/soir2-c-20261125`, issue de main 50b6f162. Aucune écriture en production (lectures de catalogue seulement,
pour vérifier les ancrages et le schéma).

## 1.5 — Ticket du cinéma de Montrouge

- L'image du hall (`images/montrouge/montrouge-cinema-accueil.jpg`) montre une jeune femme au guichet « CAISSE » : le PNJ suit
  l'image. **Simone Aiguillard** (chignon, chemisier noir de l'uniforme, badge ; fille et petite-fille d'aiguilleurs du dépôt,
  cinéphile, vive et malicieuse ; « Ici, même les séances sont à l'heure »), placée au hall du cinéma (data.js, `cinema-montrouge`,
  pièce `salle`), portrait recadré de l'image
  (`images/Republia/Montrouge/montrouge-cinema-caissiere-simone-aiguillard.webp`), fiche DeepSeek `simone_aiguillard`
  (api/_pnj-personnalites.js), scène du hall à jour (api/_pnj-scenes-generes.js, identique à la sortie du générateur).
- La fiche ne parle ni de souvenir ni de ticket à vendre : le jeu ne dit toujours pas où trouver un souvenir.
- Défaut évité : une fiche placée avant la définition de `PAS_INVENTER` faisait planter tout le module des personnalités
  (« Cannot access before initialization ») ; la fiche est rangée après, comme celle de Grigori Toporkov.
- Migration `20261125850000_cinema_montrouge_caissiere.sql` : miroir serveur du casting (pnj_lieux_metiers) et lieu de vente du
  ticket (souvenirs_objets : cinéma, hall, Simone Aiguillard ; prix inchangé, 10). Sans elle, le ticket reste chez Josette
  Betterave et la caissière parle déjà.

## 3.1 — La rumeur en toutes lettres dans la chronique

- Constat : `rumeur_lancer` n'enregistrait le texte nulle part dans l'affaire ; il ne vivait que dans l'annonce publique
  (`evenements_globaux`, préfixe « 🗯 », 600 caractères).
- Migration `20261125860000_chronique_rumeur_texte.sql` (deux remplacements contrôlés, marque `chronique_rumeur_texte_v1`, ancrages
  trouvés une fois chacun en production) :
  - `rumeur_lancer` : quand la rumeur circule, la même annonce publique est écrite, et son texte (600 caractères) et son id sont
    rangés dans `crim_affaires.details` (`rumeur_texte`, `rumeur_annonce`). Une rumeur ratée ne circule pas : pas de texte.
  - `chronique_empire_lire` : le fait d'une rumeur rend `params.texte` et `params.annonce`. Anonymat inchangé (auteur seulement
    s'il est identifié, ou arrêté ou jugé pour cet acte).
  - Les rumeurs lancées avant la migration restent citées sans texte.
- Écran (`plateau-chronique-empire.js`) : « Une rumeur circule à Marché, Novomirsk : « … » » (« {auteur} fait circuler une
  rumeur … » si l'auteur est connu). Texte échappé, puis confié à `RPPlayerText` (i18n/texte-joueur.js) avec le bouton « Voir
  l'original » / « Voir la traduction ».
- Traduction : la source est l'**annonce publique** de la rumeur (nouvelle source `annonce_publique` dans
  `api/_traduction-sources.js`, table lisible par tous sous RLS, colonne `texte`) ; l'écran ne fournit jamais le texte au service.
  **Le service de traduction des textes de joueurs n'est exposé par aucune route aujourd'hui** (api/_traduction*.js : « non activé
  publiquement ») : l'écran appelle `window.RPTraductionTexteJoueur.traduire(...)` s'il existe ; sinon l'original s'affiche et le
  lien reste caché. Le jour où le service est branché, la traduction s'affiche sans autre changement.

## Bancs

- `outils/bancs/banc-cinema-caissiere-20261125.cjs` (statique + PGlite) : PNJ au hall, portrait, fiche sans mention de
  souvenir, scène ; migration rejouable, ticket déplacé, autres souvenirs inchangés.
- `outils/bancs/banc-chronique-rumeur-texte-20261125.cjs` (écran + PGlite) : citation échappée, 600 caractères, anonymat,
  traduction demandée sur l'annonce publique, bascule « Voir l'original » (un seul écouteur), repli sans service ; serveur : texte
  et annonce rangés seulement pour la rumeur qui circule, annonce publique identique, migration rejouable.
- `outils/bancs/banc-i18n-traduction-sources.mjs` : quatrième source admise, colonne unique `texte`.

## Lignes de suivi (prêtes pour docs/suivi-decisions.md)

| 25/11/2026 | 1.5 Ticket du cinéma de Montrouge vendu au cinéma par Simone Aiguillard, caissière visible au guichet sur l'image du hall (portrait recadré, fiche DeepSeek) (migration 20261125850000 écrite, non appliquée). | en cours |  |  | Mission de fin de soirée 1.5 |
| 25/11/2026 | 3.1 Chronique de l'empire : la rumeur est citée avec son texte (600 caractères), auteur anonyme tant qu'il n'est pas identifié ; texte de joueur traduit par le service des textes de joueurs (source : l'annonce publique de la rumeur), lien « Voir l'original » (migration 20261125860000 écrite, non appliquée ; service de traduction pas encore exposé). | en cours |  |  | Mission de fin de soirée 3.1 |

## Migrations à valider (dans l'ordre)

1. `20261125850000_cinema_montrouge_caissiere.sql` — contrôles :
   `SELECT nom, job FROM public.pnj_lieux_metiers WHERE pays='republic' AND ville='ville_b' AND building_id='cinema-montrouge' AND room_id='salle';` → Simone Aiguillard, commercant ;
   `SELECT batiment, piece, pnj FROM public.souvenirs_objets WHERE cle='souv_montrouge_ticket_cinema';` → cinema-montrouge, salle, Simone Aiguillard.
2. `20261125860000_chronique_rumeur_texte.sql` — contrôles : marque `chronique_rumeur_texte_v1` dans `rumeur_lancer(text,text,text,text,integer,integer)`
   et dans `chronique_empire_lire(timestamptz,integer)` → vrai, vrai ; `has_function_privilege('authenticated', 'public.chronique_empire_lire(timestamptz,integer)', 'EXECUTE')` → vrai.

## Pour Codex (français nouveau)

- `plateau-chronique-empire.js`, objet `TXT` : `acte_rumeur_texte` (« Une rumeur circule {lieu} : « {texte} » » ; « {auteur} fait
  circuler une rumeur {lieu} : « {texte} » »), `original` (« Voir l’original »), `traduction` (« Voir la traduction »).
- `data.js` : rôle « Caissière du cinéma » (Simone Aiguillard).
- `api/_pnj-personnalites.js` : fiche `simone_aiguillard`.

## Questions de game design

- Le service de traduction des textes de joueurs (api/_traduction*.js) n'a aucune route : faut-il l'ouvrir maintenant (quota,
  coût DeepSeek) pour les rumeurs de la chronique, ou attendre son lancement général (forums, chat) ?
- Une rumeur ratée reste mentionnée dans la chronique (règle du 25/11 : « une rumeur circule par nature »), mais sans texte.
  Faut-il plutôt ne citer que les rumeurs qui circulent ?
