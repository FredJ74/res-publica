-- Migration requise avant que la memoire commerciale de l'agence Roxanne Velours (chantier
-- "Phase 5", 22 aout 2026) ne soit persistee. Cree UNIQUEMENT la table de stockage generique
-- -- aucun producteur (INSERT reel a l'embauche/a une prestation) ni aucun consommateur
-- (Secret contre secret, interrogatoire) n'est branche dans ce lot. Aucune ligne de code
-- applicatif ecrite avant cette migration.
--
-- Contexte / decision de game design validee : les escorts de l'agence connaissent
-- professionnellement l'activite commerciale REELLE et RECENTE de leurs clients (qui embauche
-- qui, qui a recemment travaille avec qui), sans jamais connaitre le contenu des echanges ni
-- les details intimes -- cette table ne stocke QUE l'existence et la date d'un evenement
-- commercial, jamais un contenu. Sert de piste d'enquete, jamais de preuve.
--
-- personnages.escort_active reste la SEULE source de verite pour "qui est actuellement
-- embauche" -- non duplique, non modifie par cette migration. Cette nouvelle table sert
-- exclusivement a retrouver l'activite commerciale RECENTE/PASSEE (y compris apres un renvoi
-- ou une prestation ponctuelle), qu'escort_active ne conserve pas : un renvoi
-- (confirmerRenvoyerEscort, plateau-multijoueur.js) supprime purement et simplement l'entree,
-- sans laisser de trace.
--
-- Architecture "journal d'evenements append-only" (et non une ligne cumulative par couple
-- client/escort) : chaque evenement commercial qualifiant (embauche, prestation) insere sa
-- PROPRE ligne avec sa propre expiration a +90 jours -- exactement la meme philosophie que
-- renseignements_connus (chaque ligne vieillit independamment, filtree a la lecture par
-- jour_expiration >= aujourd'hui, jamais recalculee retroactivement). Un evenement vieux de
-- plus de 90 jours sort naturellement du calcul de recence des qu'un lecteur filtre sur
-- jour_expiration -- aucune purge, aucun recalcul necessaire. C'est un correctif deliberement
-- choisi apres revue : une premiere version envisageait une seule ligne par couple avec un
-- compteur cumulatif (nb_occurrences += 1 a chaque evenement), rejetee car elle aurait compte
-- indefiniment des evenements anciens (ex. deux prestations il y a un an + une aujourd'hui
-- aurait donne "3", et ete lue a tort comme une relation soutenue).
--
-- INSERT uniquement, jamais d'upsert : plusieurs evenements pour le meme couple sont normaux
-- et attendus (chaque prestation reelle cree sa propre ligne), pas une anomalie a empecher --
-- contrairement a d'autres tables de ce projet ou un upsert (lecture puis update/insert) est
-- necessaire, aucune fenetre de course n'existe ici : chaque ecriture est independante, aucun
-- index unique necessaire.
--
-- "type_evenement" recoit un CHECK -- meme principe que "mode_acquisition" sur
-- renseignements_connus (colonne texte + CHECK, jamais un enum Postgres dedie) : un petit
-- ensemble ferme et structurel au modele (embauche/prestation), pas une taxonomie ouverte.
--
-- Semantique future des producteurs (non codee dans ce lot, documentee ici pour memoire) :
--   'embauche'   -- cree lors d'une embauche reelle d'un escort (confirmerRecrutementEscort,
--                   plateau-multijoueur.js), jour = state.day au moment de l'embauche.
--   'prestation' -- cree lors d'un "Faire l'amour" reussi AVEC un escort deja embauche
--                   (confirmerFaireLAmour, plateau-pnj.js -- cette fonction exige desormais
--                   TOUJOURS une embauche prealable, correctif du meme lot), jour = state.day
--                   au moment de la prestation.
-- Dans les deux cas : jour_expiration = jour + 90. Une ligne = un evenement reel, jamais un
-- compteur ni un resume.
--
-- Qualification "relation soutenue" (future, non codee ici) : calculee A LA LECTURE, jamais
-- stockee -- COUNT(lignes WHERE client=X AND escort=Y AND jour_expiration >= aujourd'hui) >= 3.
-- En dessous, "relation connue/recente". Critere deterministe, jamais laisse a l'IA.
--
-- Index : (client, escort, jour_expiration) pour les recherches sur un couple precis (Secret
-- contre secret, futur) ; (escort, jour_expiration) pour les recherches sur un escort donne
-- independamment du client (interrogatoire cible, futur -- "que sait cet escort sur les
-- clients recents"). Deux acces reellement prevus par la conception validee, aucun index
-- superflu (meme discipline que migration_tournees_boissons.sql : pas d'index sans usage
-- reel demontre).
--
-- RLS / policies : ACTIVEE, AUCUNE policy anon -- meme doctrine que renseignements_connus
-- (migration_renseignements_connus.sql) : cette table est encore plus directement
-- revelatrice si elle etait lisible en clair (elle donnerait la carte complete clients/
-- escorts d'un coup d'oeil via un simple SELECT anon). Seul un futur endpoint serveur
-- (SUPABASE_SERVICE_ROLE_KEY, jamais exposee au client -- meme patron que
-- api/renseignements.js) pourra y acceder. Aucun acces cote navigateur, ni en lecture ni en
-- ecriture, avec la cle anon.
--
-- Aucune cle etrangere sur "client"/"escort" : simple texte, coherent avec le reste du
-- projet ou aucune table de personnages/PNJ n'est referencee par cle etrangere (les PNJ
-- escorts n'ont d'ailleurs aucune ligne "personnages" propre -- voir audit dedie).
--
-- La cle anon (utilisee par le client via l'API REST) n'a pas les privileges DDL necessaires
-- pour executer ceci elle-meme -- comme pour toutes les migrations precedentes de ce projet,
-- a executer manuellement par Fred dans l'editeur SQL Supabase. Sans cette migration : aucune
-- fonctionnalite existante n'est affectee -- aucun code applicatif de ce chantier n'ecrit
-- encore dans cette table (Phase 5, lot SQL uniquement).

CREATE TABLE IF NOT EXISTS escort_evenements_commerciaux (
  id text PRIMARY KEY,
  client text NOT NULL,
  escort text NOT NULL,
  type_evenement text NOT NULL
    CHECK (type_evenement IN ('embauche', 'prestation')),
  jour integer NOT NULL,
  jour_expiration integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_escort_evenements_client_escort_expiration
  ON escort_evenements_commerciaux (client, escort, jour_expiration);

CREATE INDEX IF NOT EXISTS idx_escort_evenements_escort_expiration
  ON escort_evenements_commerciaux (escort, jour_expiration);

ALTER TABLE escort_evenements_commerciaux ENABLE ROW LEVEL SECURITY;
