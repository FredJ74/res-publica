-- =====================================================================
-- ASSEMBLEE NATIONALE DE REPUBLIA — schema complet + RPC transactionnelles
-- 10 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
--
-- Tout le moteur parlementaire cote client est FAIL-CLOSED : tant que ces objets n'existent
-- pas, aucune proposition ne peut etre deposee, aucun vote enregistre, aucun marchandage
-- facture, aucune indemnite versee. Jamais de repli non atomique, jamais de mouvement d'argent
-- sur un schema incomplet. Meme doctrine que migration_loyers_unifies_lot14.sql.
--
-- POURQUOI DES RPC ET PAS DES ECRITURES REST
-- L'audit du 9 septembre 2026 a etabli que TOUTES les primitives de caisse du projet
-- (crediterCaisseBatiment, debiterCaisseBatimentPlafonne, et meme debiterCaisseBatimentAtomique
-- malgre son nom) sont des lire-modifier-ecrire : deux versements simultanes en perdent un.
-- Le marchandage de vote est concu pour etre utilise par plusieurs joueurs le meme soir, sur la
-- meme caisse, dans les dernieres minutes d'un scrutin. Le lire-modifier-ecrire est donc
-- structurellement inacceptable ici. Les fonctions ci-dessous font le travail en une seule
-- instruction SQL par ligne touchee, sous verrou de ligne Postgres.
--
-- Le nom 'Atomique' de l'ancienne primitive designe le tout-ou-rien SUR LE MONTANT, jamais la
-- surete concurrentielle. Aucune des fonctions de ce fichier ne l'appelle.
--
-- PERIMETRE : ce fichier cree des objets nouveaux, et fait UN SEUL DDL sur une table existante --
-- personnages.bonus_lobbyiste (partie 15 bis), additif, avec DEFAULT, sans reprise de donnees.
-- caisses_batiments est seulement lue et ecrite en DONNEES, jamais alteree. Les caisses du reste
-- du jeu ne sont pas refactorees -- hors perimetre explicite du chantier (§50).
--
-- VILLES DE REPUBLIA (WORLD.republic, data.js) :
--   capitale = Luthecia · ville_a = Port-Sainte-Marie · ville_b = Montrouge
-- =====================================================================


-- =====================================================================
-- PARTIE 1 — LES 9 SIEGES ET LEURS PNJ PERMANENTS
-- =====================================================================
-- Un siege = une ligne, definitivement. L'etat 'endormi' vit ICI, sur la ligne du siege, et
-- nulle part ailleurs : c'est ce qui permet un UPDATE conditionnel atomique (voir
-- assemblee_endormir/assemblee_reveiller). Le blob batiments_etat a ete ecarte volontairement,
-- l'audit ayant montre que sbSetBatimentEtat est un lire-modifier-ecrire.
--
-- pnj_id est un identifiant technique STABLE, independant du nom d'affichage : renommer un
-- depute PNJ ne doit jamais orpheliner ses intentions ni ses archives de scrutin.

CREATE TABLE IF NOT EXISTS public.assemblee_sieges (
  id          text PRIMARY KEY,                       -- 'republic:capitale:1'
  country     text        NOT NULL DEFAULT 'republic',
  city        text        NOT NULL,
  rang        integer     NOT NULL,                   -- 1..3 dans la ville
  pnj_id      text        NOT NULL UNIQUE,            -- identifiant technique stable
  pnj_nom     text        NOT NULL,                   -- nom d'affichage, modifiable
  endormi     boolean     NOT NULL DEFAULT false,
  endormi_ts  timestamptz,
  endormi_par text,                                   -- jamais expose au client (§15 : secret)
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Les neuf PNJ parlementaires permanents. ON CONFLICT DO NOTHING : rejouer ce fichier ne
-- reinitialise jamais un etat 'endormi' en cours ni un nom deja corrige.
INSERT INTO public.assemblee_sieges (id, country, city, rang, pnj_id, pnj_nom) VALUES
  ('republic:capitale:1', 'republic', 'capitale', 1, 'dep_vauclerc', 'Étienne Vauclerc'),
  ('republic:capitale:2', 'republic', 'capitale', 2, 'dep_marechal', 'Sophie Maréchal'),
  ('republic:capitale:3', 'republic', 'capitale', 3, 'dep_delorme',  'Benoît Delorme'),
  ('republic:ville_b:1',  'republic', 'ville_b',  1, 'dep_charron',  'Nathalie Charron'),
  ('republic:ville_b:2',  'republic', 'ville_b',  2, 'dep_pichon',   'Gérard Pichon'),
  ('republic:ville_b:3',  'republic', 'ville_b',  3, 'dep_vasseur',  'Élodie Vasseur'),
  ('republic:ville_a:1',  'republic', 'ville_a',  1, 'dep_legall',   'Yann Legall'),
  ('republic:ville_a:2',  'republic', 'ville_a',  2, 'dep_leroux',   'Maëlle Leroux'),
  ('republic:ville_a:3',  'republic', 'ville_a',  3, 'dep_kermeur',  'Loïc Kermeur')
ON CONFLICT (id) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_assemblee_sieges_pays_ville
  ON public.assemblee_sieges (country, city, rang);


-- =====================================================================
-- PARTIE 2 — LES PROPOSITIONS DE LOI
-- =====================================================================
-- texte_original est IMMUABLE (§6). Aucune fonction de ce fichier ne le reecrit, et le trigger
-- de la partie 8 l'interdit physiquement -- un amendement ne doit jamais pouvoir ecraser le
-- texte depose, meme par erreur de programmation cote client.
--
-- categorie est VERROUILLEE au depot (§9) : meme protection par trigger.

CREATE TABLE IF NOT EXISTS public.assemblee_propositions (
  id                  text PRIMARY KEY,               -- 'prop-<epoch>'
  country             text        NOT NULL DEFAULT 'republic',
  auteur              text        NOT NULL,
  titre               text        NOT NULL,
  type                text        NOT NULL,           -- 'rp' | 'mecanique' | 'abrogation'
  categorie           text,                           -- famille technique (type='mecanique')
  loi_cible_id        text,                           -- proposition adoptee visee (type='abrogation')
  texte_original      text        NOT NULL,           -- IMMUABLE
  amendements         jsonb       NOT NULL DEFAULT '[]'::jsonb,
  statut              text        NOT NULL DEFAULT 'debat',
  session_num         integer     NOT NULL DEFAULT 0,
  forum_topic_id      text,
  depose_ts           timestamptz NOT NULL DEFAULT now(),
  eligible_session_ts timestamptz NOT NULL,           -- depose_ts + 7 jours (§10)
  session_ouverte_ts  timestamptz,
  cloture_ts          timestamptz,                    -- mercredi 22:00 Europe/Paris vise
  adoptee_ts          timestamptz,
  abrogee_ts          timestamptz,
  data                jsonb       NOT NULL DEFAULT '{}'::jsonb,
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assemblee_prop_type_valide
    CHECK (type IN ('rp', 'mecanique', 'abrogation')),
  CONSTRAINT assemblee_prop_statut_valide
    CHECK (statut IN ('debat', 'session', 'adoptee', 'rejetee', 'renvoyee', 'retiree', 'abrogee')),
  -- Une loi mecanique DOIT porter une categorie ; les autres n'en portent jamais.
  CONSTRAINT assemblee_prop_categorie_coherente
    CHECK ((type = 'mecanique' AND categorie IS NOT NULL)
        OR (type <> 'mecanique' AND categorie IS NULL)),
  CONSTRAINT assemblee_prop_abrogation_coherente
    CHECK ((type = 'abrogation' AND loi_cible_id IS NOT NULL)
        OR (type <> 'abrogation' AND loi_cible_id IS NULL))
);

CREATE INDEX IF NOT EXISTS idx_assemblee_prop_statut
  ON public.assemblee_propositions (country, statut);
CREATE INDEX IF NOT EXISTS idx_assemblee_prop_cloture
  ON public.assemblee_propositions (statut, cloture_ts)
  WHERE statut = 'session';
-- Interdictions mecaniques en vigueur : requete la plus chaude du jeu une fois les lois
-- branchees sur le commerce (chaque achat/vente la consulte). Index partiel dedie.
CREATE INDEX IF NOT EXISTS idx_assemblee_prop_interdictions_actives
  ON public.assemblee_propositions (country, categorie)
  WHERE type = 'mecanique' AND statut = 'adoptee';


-- =====================================================================
-- PARTIE 3 — INTENTIONS DES DEPUTES PNJ
-- =====================================================================
-- Une ligne par (proposition, session, siege). Le marchandage fait un UPDATE d'UNE SEULE LIGNE :
-- deux joueurs qui retournent le meme depute a la meme seconde sont serialises par Postgres, le
-- dernier gagne, et aucun des deux ne perd son debit (§15 : le cout est du dans tous les cas).
--
-- session_num dans la cle : une egalite (§27) rerolle les intentions en creant une nouvelle
-- generation de lignes, sans jamais ecraser l'historique de la session precedente.

CREATE TABLE IF NOT EXISTS public.assemblee_intentions (
  id             text PRIMARY KEY,                    -- prop_id:session_num:siege_id
  proposition_id text        NOT NULL REFERENCES public.assemblee_propositions(id) ON DELETE CASCADE,
  session_num    integer     NOT NULL,
  siege_id       text        NOT NULL REFERENCES public.assemblee_sieges(id),
  intention      text        NOT NULL,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assemblee_intention_valide CHECK (intention IN ('POUR', 'CONTRE'))
);

CREATE INDEX IF NOT EXISTS idx_assemblee_intentions_prop
  ON public.assemblee_intentions (proposition_id, session_num);


-- =====================================================================
-- PARTIE 4 — VOTES DES DEPUTES PJ
-- =====================================================================
-- Une ligne par (proposition, session, votant). Un changement de vote est un UPDATE de cette
-- seule ligne (§14 : gratuit et illimite jusqu'a 22:00).
--
-- ABSTENTION est un choix ENREGISTRE. "N'A PAS VOTE" est l'ABSENCE de ligne (§14 : deux etats
-- distincts). C'est la seule modelisation qui les distingue sans valeur sentinelle ambigue.

CREATE TABLE IF NOT EXISTS public.assemblee_votes (
  id             text PRIMARY KEY,                    -- prop_id:session_num:votant
  proposition_id text        NOT NULL REFERENCES public.assemblee_propositions(id) ON DELETE CASCADE,
  session_num    integer     NOT NULL,
  votant         text        NOT NULL,
  city           text        NOT NULL,                -- ville du mandat au moment du vote
  choix          text        NOT NULL,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assemblee_vote_valide CHECK (choix IN ('POUR', 'CONTRE', 'ABSTENTION'))
);

CREATE INDEX IF NOT EXISTS idx_assemblee_votes_prop
  ON public.assemblee_votes (proposition_id, session_num);


-- =====================================================================
-- PARTIE 5 — ARCHIVE NOMINATIVE DES SCRUTINS
-- =====================================================================
-- §28 : memoire permanente et exploitable politiquement. On archive des LISTES NOMINATIVES,
-- jamais de simples compteurs. Une ligne par (proposition, session) : un projet renvoye pour
-- egalite conserve donc autant de lignes que de batailles parlementaires livrees.

CREATE TABLE IF NOT EXISTS public.assemblee_scrutins (
  id             text PRIMARY KEY,                    -- prop_id:session_num
  proposition_id text        NOT NULL REFERENCES public.assemblee_propositions(id) ON DELETE CASCADE,
  session_num    integer     NOT NULL,
  country        text        NOT NULL DEFAULT 'republic',
  titre          text        NOT NULL,
  resultat       text        NOT NULL,                -- ADOPTEE | REJETEE | RENVOYEE
  score_pour     integer     NOT NULL DEFAULT 0,
  score_contre   integer     NOT NULL DEFAULT 0,
  pour           jsonb       NOT NULL DEFAULT '[]'::jsonb,
  contre         jsonb       NOT NULL DEFAULT '[]'::jsonb,
  abstention     jsonb       NOT NULL DEFAULT '[]'::jsonb,
  non_votants    jsonb       NOT NULL DEFAULT '[]'::jsonb,
  endormis       jsonb       NOT NULL DEFAULT '[]'::jsonb,
  cloture_ts     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assemblee_scrutin_resultat_valide
    CHECK (resultat IN ('ADOPTEE', 'REJETEE', 'RENVOYEE'))
);

CREATE INDEX IF NOT EXISTS idx_assemblee_scrutins_prop
  ON public.assemblee_scrutins (proposition_id);


-- =====================================================================
-- PARTIE 6 — HELPER : QUI OCCUPE REELLEMENT LES SIEGES
-- =====================================================================
-- Regle d'attribution (§2). Un PJ depute porte personnages.poste_depute = {id:'depute', city:X}
-- mais AUCUN numero de siege : le mandat de depute n'a jamais stocke de rang. Les rangs sont
-- donc attribues de facon DETERMINISTE et STABLE : les PJ deputes d'une ville, tries par nom,
-- occupent les rangs 1, 2, 3 dans cet ordre ; les rangs restants demeurent aux PNJ.
--
-- Consequence assumee et documentee : l'arrivee d'un PJ dont le nom se classe avant un depute PJ
-- deja en place peut deplacer d'un rang le PNJ devenu assistant. Cela ne change rien pour le
-- joueur (le nombre de PNJ deputes et d'assistants est identique) et evite d'inventer un
-- stockage de siege qui n'existe pas dans le modele electoral existant.
--
-- Renvoie une ligne par siege avec son occupant reel.

CREATE OR REPLACE FUNCTION public.assemblee_occupation_sieges(p_country text DEFAULT 'republic')
RETURNS TABLE (
  siege_id  text,
  city      text,
  rang      integer,
  pnj_id    text,
  pnj_nom   text,
  endormi   boolean,
  pj_nom    text,          -- NULL si le siege est tenu par le PNJ
  est_pnj   boolean
)
LANGUAGE sql
STABLE
AS $$
  WITH deputes_pj AS (
    SELECT
      p.name AS pj_nom,
      p.poste_depute->>'city' AS city,
      -- COLLATE "C" : tri par point de code, PAS par collation locale. Le client doit reproduire
      -- ce classement a l'identique (assembleeCalculerOccupation, plateau-assemblee.js) pour
      -- afficher le bon PNJ en assistant parlementaire. Une collation locale (en_US.utf8) classe
      -- "Émile" avant "Fabien", un tri par point de code le classe apres : les deux moteurs
      -- attribueraient alors des rangs differents sur des noms accentues, tres frequents en
      -- francais. COLLATE "C" cote SQL et le tri par defaut de Array.prototype.sort() cote JS
      -- (ordre des unites de code UTF-16) coincident sur tout le plan multilingue de base.
      row_number() OVER (
        PARTITION BY p.poste_depute->>'city'
        ORDER BY p.name COLLATE "C"
      ) AS rang
    FROM public.personnages p
    WHERE p.country = p_country
      AND p.poste_depute IS NOT NULL
      AND p.poste_depute->>'id' = 'depute'
      AND p.poste_depute->>'city' IS NOT NULL
  )
  SELECT
    s.id, s.city, s.rang, s.pnj_id, s.pnj_nom, s.endormi,
    d.pj_nom,
    (d.pj_nom IS NULL) AS est_pnj
  FROM public.assemblee_sieges s
  LEFT JOIN deputes_pj d
    ON d.city = s.city AND d.rang = s.rang
  WHERE s.country = p_country
  ORDER BY s.city, s.rang;
$$;


-- =====================================================================
-- PARTIE 7 — CAISSE DE L'ASSEMBLEE : CREDIT / DEBIT REELLEMENT ATOMIQUES
-- =====================================================================
-- §45 : la caisse existe deja, cle 'republic_assemblee' dans caisses_batiments. On ne cree PAS
-- de seconde caisse. On ne refactore PAS les caisses du reste du jeu (§50, hors perimetre).
--
-- caisses_batiments.data est un jsonb {solde:int}. L'increment se fait en UNE instruction, donc
-- sous verrou de ligne : deux marchandages simultanes creditent bien 200 FR au total, jamais 100.
--
-- L'UPSERT gere le cas ou la ligne n'existerait pas encore (caisse jamais creditee).

CREATE OR REPLACE FUNCTION public.assemblee_crediter_caisse(
  p_key     text,
  p_montant integer
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_solde integer;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RAISE EXCEPTION 'montant_invalide';
  END IF;

  -- Increment en une seule instruction : le verrou de ligne pris par l'UPSERT serialise deux
  -- marchandages simultanes, qui creditent donc bien 200 FR au total, jamais 100.
  -- L'alias c designe la ligne EXISTANTE dans la clause DO UPDATE ; le RETURNING, lui, voit la
  -- ligne finale -- c'est bien le nouveau solde qui est renvoye.
  INSERT INTO public.caisses_batiments AS c (id, data, updated_at)
  VALUES (p_key, jsonb_build_object('solde', p_montant), now())
  ON CONFLICT (id) DO UPDATE
    SET data = jsonb_set(
          COALESCE(c.data::jsonb, '{}'::jsonb),
          '{solde}',
          to_jsonb(
            GREATEST(0, COALESCE((c.data::jsonb->>'solde')::integer, 0) + p_montant)
          )
        ),
        updated_at = now()
  RETURNING (c.data::jsonb->>'solde')::integer INTO v_solde;

  RETURN COALESCE(v_solde, p_montant);
END;
$$;

-- Debit PLAFONNE par le solde reel (§49 : paiement partiel sans dette, jamais de caisse
-- negative, jamais de creation monetaire). Renvoie le montant REELLEMENT verse, qui peut etre
-- inferieur au montant demande, ou 0.
--
-- BUG CORRIGE A LA RELECTURE DU 10 SEPTEMBRE 2026. La premiere version calculait le montant
-- verse dans la clause RETURNING d'un UPDATE, en relisant data->>'solde'. Or RETURNING voit la
-- ligne APRES mise a jour, jamais avant : le montant renvoye etait donc le solde RESTANT, pas
-- le montant verse. Concretement, avec 200 FR en caisse et une indemnite de 250 :
--   - le solde tombait bien a 0 (correct),
--   - mais la fonction renvoyait 0 au lieu de 200.
-- Le depute etait donc debite... de rien, et l'Assemblee vidait sa caisse sans que personne ne
-- touche l'argent. Le defaut ne se voyait QUE dans le cas de paiement partiel -- precisement le
-- cas que le §49 decrit.
--
-- Version corrigee : SELECT ... FOR UPDATE d'abord (le verrou de ligne est pris et tenu jusqu'a
-- la fin de la transaction), calcul, puis UPDATE. Deux deputes qui dorment a la meme seconde
-- sont serialises par ce verrou et ne peuvent pas se partager deux fois les memes 80 FR.
CREATE OR REPLACE FUNCTION public.assemblee_debiter_caisse_plafonne(
  p_key     text,
  p_montant integer
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_solde integer;
  v_verse integer;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN 0;
  END IF;

  SELECT GREATEST(0, COALESCE((data::jsonb->>'solde')::integer, 0))
    INTO v_solde
    FROM public.caisses_batiments
   WHERE id = p_key
     FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 0;                       -- caisse inexistante : rien a verser, jamais d'erreur
  END IF;

  v_verse := LEAST(v_solde, p_montant);
  IF v_verse <= 0 THEN
    RETURN 0;
  END IF;

  UPDATE public.caisses_batiments
     SET data = jsonb_set(COALESCE(data::jsonb, '{}'::jsonb), '{solde}', to_jsonb(v_solde - v_verse)),
         updated_at = now()
   WHERE id = p_key;

  RETURN v_verse;
END;
$$;


-- =====================================================================
-- PARTIE 8 — IMMUTABILITE DU TEXTE ORIGINAL ET DE LA CATEGORIE
-- =====================================================================
-- §6 : le texte original ne doit JAMAIS etre ecrase par une modification ulterieure.
-- §9 : la categorie mecanique ne peut plus etre modifiee une fois le projet depose.
-- Garanti au niveau du schema, pas seulement dans le handler : une erreur cote client ne doit
-- pas pouvoir detruire le texte depose.

CREATE OR REPLACE FUNCTION public.assemblee_proposition_immuable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.texte_original IS DISTINCT FROM OLD.texte_original THEN
    RAISE EXCEPTION 'texte_original_immuable';
  END IF;
  IF NEW.categorie IS DISTINCT FROM OLD.categorie THEN
    RAISE EXCEPTION 'categorie_verrouillee';
  END IF;
  IF NEW.type IS DISTINCT FROM OLD.type THEN
    RAISE EXCEPTION 'type_verrouille';
  END IF;
  IF NEW.auteur IS DISTINCT FROM OLD.auteur THEN
    RAISE EXCEPTION 'auteur_immuable';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assemblee_proposition_immuable ON public.assemblee_propositions;
CREATE TRIGGER trg_assemblee_proposition_immuable
  BEFORE UPDATE ON public.assemblee_propositions
  FOR EACH ROW EXECUTE FUNCTION public.assemblee_proposition_immuable();


-- =====================================================================
-- PARTIE 9 — DEPOT, AMENDEMENT, RETRAIT
-- =====================================================================
-- §5 : peuvent deposer les PJ deputes, le PM et les ministres. L'eligibilite est verifiee ICI,
-- cote serveur, a partir de personnages.poste / personnages.poste_depute -- jamais sur la seule
-- foi de l'UI (§52).
--
-- §5 : "Un projet valablement depose continue son cycle meme si son auteur perd ensuite son
-- mandat" -- l'eligibilite n'est donc verifiee QU'AU DEPOT, jamais ensuite.

CREATE OR REPLACE FUNCTION public.assemblee_peut_deposer(
  p_nom     text,
  p_country text DEFAULT 'republic'
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages p
    WHERE p.name = p_nom
      AND p.country = p_country
      AND (
        (p.poste_depute IS NOT NULL AND p.poste_depute->>'id' = 'depute')
        OR (p.poste IS NOT NULL AND p.poste->>'id' IN
              ('pm','min_int','min_fin','min_just','min_def','min_info','min_ae'))
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.assemblee_deposer(
  p_id           text,
  p_auteur       text,
  p_titre        text,
  p_type         text,
  p_texte        text,
  p_categorie    text DEFAULT NULL,
  p_loi_cible_id text DEFAULT NULL,
  p_country      text DEFAULT 'republic'
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row public.assemblee_propositions%ROWTYPE;
BEGIN
  IF NOT public.assemblee_peut_deposer(p_auteur, p_country) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ineligible');
  END IF;

  IF p_titre IS NULL OR btrim(p_titre) = '' OR p_texte IS NULL OR btrim(p_texte) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'champs_requis');
  END IF;

  -- Une abrogation doit viser une loi REELLEMENT en vigueur (§32).
  IF p_type = 'abrogation' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.assemblee_propositions
      WHERE id = p_loi_cible_id AND statut = 'adoptee'
    ) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'loi_cible_introuvable');
    END IF;
  END IF;

  INSERT INTO public.assemblee_propositions
    (id, country, auteur, titre, type, categorie, loi_cible_id, texte_original,
     eligible_session_ts)
  VALUES
    (p_id, p_country, p_auteur, p_titre, p_type, p_categorie, p_loi_cible_id, p_texte,
     now() + interval '7 days')
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row));
END;
$$;

-- §7 : seul l'auteur amende, 0 PA, l'amendement s'ajoute sans jamais remplacer.
-- Refuse des que la session est ouverte : le texte soumis au vote est fige a l'ouverture.
CREATE OR REPLACE FUNCTION public.assemblee_amender(
  p_id     text,
  p_auteur text,
  p_texte  text
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row public.assemblee_propositions%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.auteur <> p_auteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
  END IF;
  IF v_row.statut <> 'debat' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_phase_debat');
  END IF;
  IF p_texte IS NULL OR btrim(p_texte) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'champs_requis');
  END IF;

  UPDATE public.assemblee_propositions
  SET amendements = amendements || jsonb_build_object(
        'num',   jsonb_array_length(amendements) + 1,
        'texte', p_texte,
        'ts',    to_jsonb(now())
      )
  WHERE id = p_id
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row));
END;
$$;

-- §8 : retrait possible pendant le debat uniquement, 0 PA.
CREATE OR REPLACE FUNCTION public.assemblee_retirer(
  p_id     text,
  p_auteur text
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row public.assemblee_propositions%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.auteur <> p_auteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
  END IF;
  IF v_row.statut <> 'debat' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'session_ouverte');
  END IF;

  UPDATE public.assemblee_propositions SET statut = 'retiree' WHERE id = p_id
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row));
END;
$$;


-- =====================================================================
-- PARTIE 10 — OUVERTURE DE SESSION ET GENERATION DES INTENTIONS
-- =====================================================================
-- §11 : a l'ouverture, chaque depute PNJ actif recoit une intention POUR/CONTRE 50/50, persistee,
-- stable pendant toute la session, commune a tous les joueurs. Jamais rerollee a l'affichage.
--
-- §27 : en cas d'egalite, la session suivante rerolle TOUTES les intentions et efface les votes
-- PJ. session_num est incremente, ce qui cree une nouvelle generation de lignes sans toucher aux
-- precedentes.
--
-- ON CONFLICT DO NOTHING sur les intentions : deux appels concurrents ne produisent qu'un seul
-- tirage. C'est le point exact ou un reroll accidentel serait le plus dommageable.

CREATE OR REPLACE FUNCTION public.assemblee_ouvrir_session(
  p_id         text,
  p_cloture_ts timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row public.assemblee_propositions%ROWTYPE;
  v_num integer;
BEGIN
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.statut NOT IN ('debat', 'renvoyee') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible');
  END IF;
  IF now() < v_row.eligible_session_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'semaine_de_debat_non_ecoulee');
  END IF;

  v_num := v_row.session_num + 1;

  UPDATE public.assemblee_propositions
  SET statut = 'session',
      session_num = v_num,
      session_ouverte_ts = now(),
      cloture_ts = p_cloture_ts
  WHERE id = p_id
  RETURNING * INTO v_row;

  -- §27 : repartir de zero cote PJ. Les votes de la session precedente restent archives dans
  -- assemblee_scrutins ; ce sont les lignes de vote VIVES qui sont supprimees.
  DELETE FROM public.assemblee_votes
  WHERE proposition_id = p_id AND session_num < v_num;

  -- Intention 50/50 pour chaque siege actuellement tenu par son PNJ.
  INSERT INTO public.assemblee_intentions (id, proposition_id, session_num, siege_id, intention)
  SELECT
    p_id || ':' || v_num || ':' || o.siege_id,
    p_id, v_num, o.siege_id,
    CASE WHEN random() < 0.5 THEN 'POUR' ELSE 'CONTRE' END
  FROM public.assemblee_occupation_sieges(v_row.country) o
  WHERE o.est_pnj
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'proposition', to_jsonb(v_row), 'session_num', v_num);
END;
$$;

-- Ouvre TOUTES les propositions eligibles. Appelee par le cron du mercredi, juste apres la
-- cloture des scrutins echus : les projets renvoyes pour egalite repartent ainsi immediatement
-- pour une nouvelle bataille, sans attendre une semaine de plus.
CREATE OR REPLACE FUNCTION public.assemblee_ouvrir_sessions_eligibles(
  p_cloture_ts timestamptz,
  p_country    text DEFAULT 'republic'
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_res  jsonb := '[]'::jsonb;
  v_prop record;
BEGIN
  FOR v_prop IN
    SELECT id FROM public.assemblee_propositions
    WHERE country = p_country
      AND statut IN ('debat', 'renvoyee')
      AND now() >= eligible_session_ts
    ORDER BY depose_ts
  LOOP
    v_res := v_res || jsonb_build_array(
      public.assemblee_ouvrir_session(v_prop.id, p_cloture_ts) || jsonb_build_object('id', v_prop.id)
    );
  END LOOP;
  RETURN v_res;
END;
$$;


-- =====================================================================
-- PARTIE 11 — VOTE D'UN DEPUTE PJ
-- =====================================================================
-- §14 : POUR/CONTRE/ABSTENTION, 0 PA, modifiable a volonte jusqu'a 22:00, dernier etat retenu.
-- §53 : une action tardive ne doit jamais pouvoir alterer un scrutin clos. La garde temporelle
-- et la garde de statut sont evaluees ICI, sur l'horloge du SERVEUR, jamais sur celle du
-- navigateur.
-- §52 : le mandat du votant est revalide cote serveur a chaque vote.

CREATE OR REPLACE FUNCTION public.assemblee_voter(
  p_id     text,
  p_votant text,
  p_choix  text
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row  public.assemblee_propositions%ROWTYPE;
  v_city text;
BEGIN
  IF p_choix NOT IN ('POUR', 'CONTRE', 'ABSTENTION') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide');
  END IF;

  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.statut <> 'session' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_session');
  END IF;
  IF v_row.cloture_ts IS NOT NULL AND now() >= v_row.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos');
  END IF;

  -- Le votant doit occuper reellement l'un des neuf sieges MAINTENANT.
  SELECT o.city INTO v_city
  FROM public.assemblee_occupation_sieges(v_row.country) o
  WHERE o.pj_nom = p_votant
  LIMIT 1;

  IF v_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute');
  END IF;

  INSERT INTO public.assemblee_votes
    (id, proposition_id, session_num, votant, city, choix)
  VALUES
    (p_id || ':' || v_row.session_num || ':' || p_votant,
     p_id, v_row.session_num, p_votant, v_city, p_choix)
  ON CONFLICT (id) DO UPDATE
    SET choix = EXCLUDED.choix, updated_at = now();

  RETURN jsonb_build_object('ok', true, 'choix', p_choix);
END;
$$;


-- =====================================================================
-- PARTIE 12 — MARCHANDER UN VOTE
-- =====================================================================
-- §15 : 1 PA + 100 FR a CHAQUE TENTATIVE, consommes meme en cas d'echec. Les 100 FR ne sont pas
-- detruits : ils vont a la caisse de l'Assemblee. Le marchandage est LEGAL -- cette fonction
-- n'ecrit donc aucune trace criminelle et n'expose jamais l'identite du marchandeur.
--
-- Le jet est fait cote client (il depend de CHA/ENT et du bonus lobbyiste, deja en memoire) et
-- son resultat est passe en parametre. C'est le credit de caisse et le changement d'intention
-- qui doivent etre transactionnels, pas le tirage aleatoire.
--
-- INVARIANT CENTRAL : le credit de la caisse a lieu QUE LA TENTATIVE REUSSISSE OU NON, et dans
-- la meme transaction que le changement d'intention. Un echec de mise a jour d'intention ne peut
-- donc jamais laisser un joueur debite sans que l'Assemblee soit creditee, ni l'inverse.
--
-- Un depute ENDORMI reste marchandable : le cahier des charges ne l'interdit pas, et son
-- intention (qu'il emportera a son reveil) a une valeur politique reelle. Simplement, endormi a
-- 22:00, il ne votera pas (§20).

CREATE OR REPLACE FUNCTION public.assemblee_marchander(
  p_id         text,
  p_siege_id   text,
  p_intention  text,
  p_reussi     boolean,
  p_montant    integer DEFAULT 100,
  p_caisse_key text    DEFAULT 'republic_assemblee'
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row      public.assemblee_propositions%ROWTYPE;
  v_est_pnj  boolean;
  v_solde    integer;
  v_applique boolean := false;
BEGIN
  IF p_intention NOT IN ('POUR', 'CONTRE') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'intention_invalide');
  END IF;

  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.statut <> 'session' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_session');
  END IF;
  IF v_row.cloture_ts IS NOT NULL AND now() >= v_row.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos');
  END IF;

  -- La cible doit etre un siege REELLEMENT tenu par son PNJ (§2 : un assistant parlementaire
  -- n'est pas marchandable).
  SELECT o.est_pnj INTO v_est_pnj
  FROM public.assemblee_occupation_sieges(v_row.country) o
  WHERE o.siege_id = p_siege_id;

  IF v_est_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'siege_introuvable');
  END IF;
  IF NOT v_est_pnj THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'siege_tenu_par_pj');
  END IF;

  -- Credit inconditionnel de la caisse -- meme transaction, meme en cas d'echec du jet.
  v_solde := public.assemblee_crediter_caisse(p_caisse_key, p_montant);

  IF p_reussi THEN
    UPDATE public.assemblee_intentions
    SET intention = p_intention, updated_at = now()
    WHERE proposition_id = p_id
      AND session_num = v_row.session_num
      AND siege_id = p_siege_id;
    v_applique := FOUND;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'reussi', p_reussi,
    'applique', v_applique,
    'solde_caisse', v_solde
  );
END;
$$;


-- =====================================================================
-- PARTIE 13 — ENDORMI / REVEIL
-- =====================================================================
-- §21 : etat partage serveur, plusieurs PJ peuvent agir presque simultanement. Chaque fonction
-- est un UPDATE CONDITIONNEL sur une seule ligne : le premier arrive gagne, le second recoit
-- false et sait que son action n'a rien change. Le PA et l'objet restent consommes cote client,
-- conformement au principe general du projet -- la tentative se paie.

CREATE OR REPLACE FUNCTION public.assemblee_endormir(
  p_siege_id text,
  p_par      text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_n integer;
BEGIN
  UPDATE public.assemblee_sieges
  SET endormi = true, endormi_ts = now(), endormi_par = p_par, updated_at = now()
  WHERE id = p_siege_id AND endormi = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n > 0;
END;
$$;

CREATE OR REPLACE FUNCTION public.assemblee_reveiller(p_siege_id text)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_n integer;
BEGIN
  UPDATE public.assemblee_sieges
  SET endormi = false, endormi_ts = NULL, endormi_par = NULL, updated_at = now()
  WHERE id = p_siege_id AND endormi = true;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n > 0;
END;
$$;

-- §24 : reveil automatique de TOUS les deputes endormis a minuit. Appele par le cron serveur.
CREATE OR REPLACE FUNCTION public.assemblee_reveil_minuit(p_country text DEFAULT 'republic')
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_n integer;
BEGIN
  UPDATE public.assemblee_sieges
  SET endormi = false, endormi_ts = NULL, endormi_par = NULL, updated_at = now()
  WHERE country = p_country AND endormi = true;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;


-- =====================================================================
-- PARTIE 14 — CLOTURE DU SCRUTIN (MERCREDI 22:00)
-- =====================================================================
-- §26 : ne comptent que les POUR/CONTRE des PJ et des PNJ EVEILLES. Abstention, non-votants et
-- PNJ endormis comptent pour zero, mais sont archives nominativement (§28).
--
-- §33 : une loi adoptee entre en vigueur immediatement a la cloture ; une abrogation adoptee
-- eteint sa cible dans la meme transaction.
--
-- §53 : l'autorite est ici et nulle part ailleurs. La fonction est idempotente -- un second appel
-- sur une session deja close ne fait rien et renvoie le scrutin deja arrete.

CREATE OR REPLACE FUNCTION public.assemblee_cloturer(p_id text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row        public.assemblee_propositions%ROWTYPE;
  v_pour       text[]  := '{}';
  v_contre     text[]  := '{}';
  v_abst       text[]  := '{}';
  v_non_vot    text[]  := '{}';
  v_endormis   text[]  := '{}';
  v_pnj_pour   text[]  := '{}';
  v_pnj_contre text[]  := '{}';
  v_score_p    integer := 0;
  v_score_c    integer := 0;
  v_resultat   text;
  v_scrutin_id text;
BEGIN
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;

  v_scrutin_id := p_id || ':' || v_row.session_num;

  -- Idempotence : cette session est deja close.
  IF EXISTS (SELECT 1 FROM public.assemblee_scrutins WHERE id = v_scrutin_id) THEN
    RETURN jsonb_build_object('ok', true, 'deja_cloture', true,
      'scrutin', (SELECT to_jsonb(s) FROM public.assemblee_scrutins s WHERE s.id = v_scrutin_id));
  END IF;

  IF v_row.statut <> 'session' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_session');
  END IF;

  -- ---- Cote PJ : les sieges reellement tenus par un joueur
  SELECT
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix = 'POUR'),       '{}'),
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix = 'CONTRE'),     '{}'),
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix = 'ABSTENTION'), '{}'),
    COALESCE(array_agg(o.pj_nom) FILTER (WHERE v.choix IS NULL),        '{}')
  INTO v_pour, v_contre, v_abst, v_non_vot
  FROM public.assemblee_occupation_sieges(v_row.country) o
  LEFT JOIN public.assemblee_votes v
    ON v.proposition_id = p_id
   AND v.session_num = v_row.session_num
   AND v.votant = o.pj_nom
  WHERE NOT o.est_pnj;

  -- ---- Cote PNJ : intention comptee UNIQUEMENT si le depute est eveille
  SELECT
    COALESCE(array_agg(o.pnj_nom) FILTER (WHERE NOT o.endormi AND i.intention = 'POUR'),   '{}'),
    COALESCE(array_agg(o.pnj_nom) FILTER (WHERE NOT o.endormi AND i.intention = 'CONTRE'), '{}'),
    COALESCE(array_agg(o.pnj_nom) FILTER (WHERE o.endormi), '{}')
  INTO v_pnj_pour, v_pnj_contre, v_endormis
  FROM public.assemblee_occupation_sieges(v_row.country) o
  LEFT JOIN public.assemblee_intentions i
    ON i.proposition_id = p_id
   AND i.session_num = v_row.session_num
   AND i.siege_id = o.siege_id
  WHERE o.est_pnj;

  v_pour   := v_pour   || v_pnj_pour;
  v_contre := v_contre || v_pnj_contre;

  v_score_p := COALESCE(array_length(v_pour, 1), 0);
  v_score_c := COALESCE(array_length(v_contre, 1), 0);

  -- §26/§27
  IF v_score_p > v_score_c THEN
    v_resultat := 'ADOPTEE';
  ELSIF v_score_c > v_score_p THEN
    v_resultat := 'REJETEE';
  ELSE
    v_resultat := 'RENVOYEE';
  END IF;

  INSERT INTO public.assemblee_scrutins
    (id, proposition_id, session_num, country, titre, resultat,
     score_pour, score_contre, pour, contre, abstention, non_votants, endormis)
  VALUES
    (v_scrutin_id, p_id, v_row.session_num, v_row.country, v_row.titre, v_resultat,
     v_score_p, v_score_c,
     to_jsonb(v_pour), to_jsonb(v_contre), to_jsonb(v_abst),
     to_jsonb(v_non_vot), to_jsonb(v_endormis));

  -- Statut de la proposition
  IF v_resultat = 'ADOPTEE' THEN
    UPDATE public.assemblee_propositions
    SET statut = 'adoptee', adoptee_ts = now()
    WHERE id = p_id;

    -- §32/§33 : une abrogation adoptee eteint sa cible IMMEDIATEMENT, meme transaction.
    IF v_row.type = 'abrogation' THEN
      UPDATE public.assemblee_propositions
      SET statut = 'abrogee', abrogee_ts = now()
      WHERE id = v_row.loi_cible_id AND statut = 'adoptee';
    END IF;

  ELSIF v_resultat = 'REJETEE' THEN
    UPDATE public.assemblee_propositions SET statut = 'rejetee' WHERE id = p_id;
  ELSE
    -- §27 : renvoi. Le projet reste vivant ; ses votes PJ seront effaces et les intentions
    -- rerollees a l'ouverture de la session suivante (assemblee_ouvrir_session). eligible_
    -- session_ts n'est pas repousse : la semaine de debat a deja ete purgee une fois.
    UPDATE public.assemblee_propositions
    SET statut = 'renvoyee', cloture_ts = NULL, session_ouverte_ts = NULL
    WHERE id = p_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'resultat', v_resultat,
    'score_pour', v_score_p,
    'score_contre', v_score_c,
    'pour', to_jsonb(v_pour),
    'contre', to_jsonb(v_contre),
    'abstention', to_jsonb(v_abst),
    'non_votants', to_jsonb(v_non_vot),
    'endormis', to_jsonb(v_endormis),
    'titre', v_row.titre,
    'type', v_row.type,
    'categorie', v_row.categorie,
    'auteur', v_row.auteur,
    'forum_topic_id', v_row.forum_topic_id,
    'loi_cible_id', v_row.loi_cible_id
  );
END;
$$;

-- Cloture de TOUTES les propositions echues. Appelee par le cron du mercredi 22:00.
CREATE OR REPLACE FUNCTION public.assemblee_cloturer_echues(p_country text DEFAULT 'republic')
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_res  jsonb := '[]'::jsonb;
  v_prop record;
BEGIN
  FOR v_prop IN
    SELECT id FROM public.assemblee_propositions
    WHERE country = p_country
      AND statut = 'session'
      AND cloture_ts IS NOT NULL
      AND now() >= cloture_ts
    ORDER BY cloture_ts
  LOOP
    v_res := v_res || jsonb_build_array(
      public.assemblee_cloturer(v_prop.id) || jsonb_build_object('id', v_prop.id)
    );
  END LOOP;
  RETURN v_res;
END;
$$;


-- =====================================================================
-- PARTIE 15 — INDEMNITE PARLEMENTAIRE (§47/§48/§49)
-- =====================================================================
-- 250 FR/jour, uniquement pour les deputes PJ, uniquement a l'ordre Dormir, jamais de rattrapage,
-- paiement partiel si la caisse ne suit pas, jamais de dette.
--
-- La garde anti-double-paiement est portee par une LIGNE DEDIEE plutot que par un champ de
-- state : l'audit a montre que plusieurs plafonds quotidiens du projet ne sont pas persistes et
-- sont donc contournables au rafraichissement. Ici la garde est cote serveur, et la journee de
-- reference est une DATE REELLE Europe/Paris, jamais state.day (propre a chaque joueur).

CREATE TABLE IF NOT EXISTS public.assemblee_indemnites (
  id         text PRIMARY KEY,                        -- '<nom>:<YYYY-MM-DD>'
  personnage text        NOT NULL,
  jour       date        NOT NULL,
  montant    integer     NOT NULL,
  versee_ts  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_assemblee_indemnites_perso
  ON public.assemblee_indemnites (personnage, jour);

CREATE OR REPLACE FUNCTION public.assemblee_verser_indemnite(
  p_nom     text,
  p_country text    DEFAULT 'republic',
  p_montant integer DEFAULT 250
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_jour  date;
  v_id    text;
  v_verse integer;
BEGIN
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := p_nom || ':' || v_jour::text;

  -- Le depute doit tenir un siege MAINTENANT (§48 : au moment du versement).
  IF NOT EXISTS (
    SELECT 1 FROM public.assemblee_occupation_sieges(p_country) o
    WHERE o.pj_nom = p_nom
  ) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute', 'montant', 0);
  END IF;

  -- Garde anti-doublon : l'insertion EST la garde, pas un test suivi d'une ecriture -- donc sans
  -- fenetre de course entre deux onglets du meme joueur.
  BEGIN
    INSERT INTO public.assemblee_indemnites (id, personnage, jour, montant)
    VALUES (v_id, p_nom, v_jour, 0);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_verse_aujourdhui', 'montant', 0);
  END;

  -- §49 : plafonne par la caisse, paiement partiel accepte, jamais de dette.
  v_verse := public.assemblee_debiter_caisse_plafonne('republic_assemblee', p_montant);

  UPDATE public.assemblee_indemnites SET montant = v_verse WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'montant', v_verse, 'vise', p_montant);
END;
$$;


-- =====================================================================
-- PARTIE 14 bis — TRACE INDEPENDANTE DU VENDEUR (§35, §38)
-- =====================================================================
-- Lors d'une vente portant sur un produit interdit, l'acheteur ET le vendeur commettent chacun
-- un acte illegal DISTINCT, avec son propre jet de detection. Le cahier des charges est explicite :
-- la detection de l'un n'entraine jamais celle de l'autre.
--
-- POURQUOI UNE RPC ET PAS UNE ECRITURE DEPUIS LE CLIENT DE L'ACHETEUR
-- Le precedent existe dans le projet (le controle de fret ecrit une convocation chez un tiers via
-- sbUpdate('personnages', ...)), mais il est inacceptable ici : la cle anon est publique, donc
-- n'importe qui pourrait fabriquer une trace judiciaire contre un joueur de son choix. Quatre
-- exigences imposent le passage par une fonction serveur :
--
--   1. AUTORITE      -- le jet du vendeur ne doit pas dependre du navigateur de l'acheteur ;
--   2. NON-FALSIFIABILITE -- le client ne NOMME PAS le vendeur : il transmet l'identifiant du
--                      commerce, et la fonction resout elle-meme le proprietaire dans
--                      'entreprises'. Il ne peut donc viser personne d'autre que le vendeur reel ;
--   3. VENDEUR HORS LIGNE -- aucune session requise, l'ecriture est directe ;
--   4. CONCURRENCE   -- SELECT ... FOR UPDATE sur la ligne du vendeur, pas de lire-modifier-ecrire
--                      expose a une perte d'ecriture.
--
-- La legalite elle-meme n'est pas crue sur parole : la fonction relit assemblee_propositions pour
-- verifier que l'interdiction est REELLEMENT en vigueur au moment de la vente.
--
-- Un commerce tenu par un PNJ ne poursuit personne : il n'y a pas de vendeur joueur a incriminer.

CREATE OR REPLACE FUNCTION public.assemblee_tracer_vente_interdite(
  p_commerce_id text,
  p_categorie   text,
  p_libelle     text,
  p_country     text DEFAULT 'republic'
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_vendeur    text;
  v_loi        record;
  v_dis        integer;
  v_taux       integer;
  v_roll       integer;
  v_convs      jsonb;
  v_hist       jsonb;
  v_detecte    boolean := false;
  v_deja       boolean := false;
  v_limite     timestamptz;
BEGIN
  -- 1. Le vendeur est DERIVE du commerce, jamais fourni par l'appelant.
  SELECT NULLIF(e.data->>'proprietaire', 'PNJ')
    INTO v_vendeur
    FROM public.entreprises e
   WHERE e.id = p_commerce_id;

  IF v_vendeur IS NULL OR btrim(v_vendeur) = '' THEN
    RETURN jsonb_build_object('ok', true, 'vendeur', null, 'raison', 'commerce_pnj_ou_introuvable');
  END IF;

  -- 2. L'interdiction doit etre reellement en vigueur MAINTENANT. On ne croit pas le client.
  SELECT id, titre INTO v_loi
    FROM public.assemblee_propositions
   WHERE country = p_country
     AND type = 'mecanique'
     AND statut = 'adoptee'
     AND categorie = p_categorie
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_non_interdite');
  END IF;

  -- 3. Jet PROPRE au vendeur, sur SA discretion. Independant de celui de l'acheteur : meme base
  --    de 50 % (§38), mais module par une valeur qui n'appartient qu'a lui.
  SELECT COALESCE((p.resources->>'dis')::integer, 0),
         COALESCE(p.convocations, '[]'::jsonb),
         COALESCE(p.historique_crimes, '[]'::jsonb)
    INTO v_dis, v_convs, v_hist
    FROM public.personnages p
   WHERE p.name = v_vendeur
     FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'vendeur', null, 'raison', 'vendeur_introuvable');
  END IF;

  v_taux := GREATEST(5, 50 - (v_dis / 10));
  v_roll := floor(random() * 100)::integer + 1;
  v_detecte := (v_roll <= v_taux);

  -- 4. La trace differee est TOUJOURS ecrite, detectee ou non -- exactement comme cote acheteur.
  --    origine = 'serveur' + id stable : c'est ce qui la place sous la protection du trigger
  --    personnages_preserver_judiciaire (partie 14 ter). Sans ces deux champs, la sauvegarde
  --    suivante d'un vendeur connecte pourrait l'effacer.
  --    expireTs = 8 jours reels : equivalent temporel des 8 jours de jeu (expireJour) portes par les
  --    traces creees cote client. Le serveur ne peut pas utiliser expireJour -- state.day est propre
  --    a chaque joueur et il ne le connait pas. Passe cette date, le trigger cesse de la reinjecter
  --    et la purge client normale peut la retirer.
  v_hist := v_hist || jsonb_build_array(jsonb_build_object(
    'id', 'trace-' || md5(random()::text || clock_timestamp()::text),
    'origine', 'serveur',
    'acte', 'transaction_interdite',
    'cible', COALESCE(p_libelle, p_categorie),
    'role', 'vente',
    'categorie', p_categorie,
    'quantite', 1,
    'loiId', v_loi.id,
    'loiTitre', v_loi.titre,
    'ts', to_jsonb(now()),
    'expireTs', to_jsonb(now() + interval '8 days')
  ));

  -- 5. Convocation UNIQUEMENT si detecte, et jamais en double sur le meme motif (§40).
  IF v_detecte THEN
    SELECT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_convs) c
      WHERE c.value->>'motif' = 'transaction_interdite'
        AND COALESCE((c.value->>'traitee')::boolean, false) = false
    ) INTO v_deja;

    IF NOT v_deja THEN
      v_limite := now() + interval '36 hours';
      v_convs := v_convs || jsonb_build_array(jsonb_build_object(
        'id', 'conv-' || md5(random()::text || clock_timestamp()::text),
        'origine', 'serveur',
        'motif', 'transaction_interdite',
        'limiteTs', to_jsonb(v_limite),
        'role', 'vente',
        'categorie', p_categorie,
        'loiId', v_loi.id,
        'loiTitre', v_loi.titre,
        'traitee', false
      ));
    END IF;
  END IF;

  -- 6. Le FAIT judiciaire d'abord. Le trigger de preservation s'applique aussi a cette ecriture.
  UPDATE public.personnages
     SET convocations = v_convs,
         historique_crimes = v_hist
   WHERE name = v_vendeur;

  -- 7. La notification ensuite, ISOLEE dans son propre bloc.
  --
  -- Le schema exact de la table mails n'est PAS etabli par le depot : aucun CREATE TABLE mails
  -- n'y figure (la table est anterieure aux fichiers de migration). Ce que le depot etablit, par
  -- ses ecrivains et lecteurs en production :
  --   - sbSendMail (supabase.js), point d'ecriture declare unique de la table, insere exactement
  --     (id, from_player, to_player, subject, body, time, read), avec un id TEXTE 'mail-<ms>' ;
  --   - les lecteurs filtrent sur to_player / from_player et trient sur created_at (defaut serveur) ;
  --   - le cron filtre sur archived (defaut serveur, jamais ecrit par sbSendMail).
  -- Cet INSERT reprend donc le jeu de colonnes EXACT du seul ecrivain canonique.
  --
  -- Deux precautions pour ne reposer sur aucune hypothese fragile :
  --   - id non predictible et sans collision (md5 d'un aleatoire et de l'horloge, fonctions du
  --     noyau PostgreSQL, aucune extension requise) -- la premiere version derivait l'id du
  --     commerce et de la seconde courante, ce qui aurait pu collisionner ;
  --   - le bloc BEGIN/EXCEPTION pose un point de sauvegarde : si l'insertion echoue pour une raison
  --     imprevue (contrainte inconnue, colonne manquante), SEUL le courrier est annule. La trace et
  --     la convocation, deja ecrites a l'etape 6, restent acquises. Le joueur verra de toute facon
  --     la convocation dans son ecran « Se justifier » : le courrier n'en est qu'un avis.
  IF v_detecte AND NOT v_deja THEN
    BEGIN
      INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
      VALUES (
        'mail-' || md5(random()::text || clock_timestamp()::text),
        'Commissariat', v_vendeur, 'Convocation officielle',
        'Une vente portant sur une marchandise interdite (« ' || v_loi.titre || ' ») a été constatée '
        || 'dans votre commerce. Présentez-vous au commissariat sous 36 heures pour vous justifier. '
        || 'Passé ce délai sans vous présenter, vous serez arrêté(e) et détenu(e) deux jours.',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'), false
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'detecte', v_detecte,
    'convocation_creee', (v_detecte AND NOT v_deja),
    'loi', v_loi.titre
  );
END;
$$;


-- =====================================================================
-- PARTIE 14 ter — UNE SAUVEGARDE CLIENT NE PEUT PLUS EFFACER UN ETAT JUDICIAIRE SERVEUR
-- =====================================================================
-- CAUSE DU RISQUE
-- sbSavePersonnage (supabase.js) republie a chaque sauvegarde l'INTEGRALITE du personnage par un
-- PATCH, dont les colonnes convocations et historique_crimes, copiees telles quelles depuis la
-- memoire du navigateur. Un joueur connecte dont l'etat a ete charge AVANT qu'une fonction
-- serveur n'ecrive chez lui (trace de vente interdite, verdict d'echeance du cron) republie donc,
-- a sa prochaine sauvegarde, une version anterieure de ces tableaux -- et fait disparaitre
-- l'evenement serveur sans le moindre signal. Le filet sbVerifierEtSauvegarderPersonnage ne
-- couvre que le minuteur de 30 s, pas les dizaines de sauvegardes explicites.
--
-- POURQUOI NI RETIRER LES COLONNES DU PAYLOAD, NI UNE RPC DE SAUVEGARDE
-- Le projet a deja un precedent : blessure_sportive a ete retiree du payload generique pour ce
-- motif exact. Mais ici le client ECRIT LEGITIMEMENT ces deux colonnes a une quinzaine d'endroits
-- (vol, achat d'arme, explosifs, neutralisation, douane, fouille, fret, justification...). Les
-- retirer du payload rendrait toutes ces ecritures volatiles : regression massive.
--
-- ARCHITECTURE RETENUE : FUSION CONTROLEE COTE SERVEUR, AU MOMENT DE L'ECRITURE
-- Un trigger BEFORE UPDATE sur personnages recompose ces deux colonnes a partir de l'ancienne
-- valeur (OLD) et de la nouvelle (NEW). Il s'execute pour TOUT ecrivain -- client, cron, RPC --
-- sans que le client ait a y penser, et sans aucune lecture-modification-ecriture cote navigateur.
-- La fusion est dictee par la semantique REELLE de chaque colonne, verifiee dans le code :
--
-- convocations : APPEND-ONLY. Recherche exhaustive faite le 10 septembre 2026 : aucun chemin du
--   jeu ne retire jamais une convocation (ni splice, ni filter, ni pop, ni shift, ni remise a []).
--   Une convocation ne fait que passer de traitee=false a traitee=true. La fusion est donc exacte :
--     - toute convocation presente dans OLD et absente de NEW est REINJECTEE ;
--     - traitee et echue sont MONOTONES (OLD OR NEW) : un etat client ancien ne peut ni annuler un
--       verdict serveur, ni rendre « non traitee » une convocation deja sanctionnee -- ce qui
--       interdit aussi une double sanction.
--
-- historique_crimes : PAS append-only. Le client retire legitimement des entrees (decouverte d'un
--   crime passe, verifierDecouverteCrimesPasses ; purge des entrees expirees). Une union aveugle
--   ressusciterait des crimes deja punis. On ne protege donc QUE les entrees d'origine serveur
--   (origine = 'serveur', id stable), et seulement tant qu'elles ne sont pas expirees (expireTs).
--   Les entrees creees par le client gardent exactement leur semantique actuelle.
--
-- Identite d'une convocation : son id quand il existe (toutes les convocations creees depuis ce
-- chantier en portent un), sinon une cle derivee de son contenu pour les convocations anterieures.

CREATE OR REPLACE FUNCTION public.assemblee_cle_convocation(e jsonb)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(
    e->>'id',
    'legacy|' || COALESCE(e->>'motif', '') || '|' || COALESCE(e->>'jourEmission', '')
      || '|' || COALESCE(e->>'heureEmission', '') || '|' || COALESCE(e->>'limiteTs', '')
  );
$$;

CREATE OR REPLACE FUNCTION public.personnages_preserver_judiciaire()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_elem   jsonb;
  v_old    jsonb;
  v_convs  jsonb;
  v_hist   jsonb;
BEGIN
  -- ---------------------------------------------------------------- CONVOCATIONS
  IF NEW.convocations IS DISTINCT FROM OLD.convocations THEN
    v_convs := '[]'::jsonb;

    -- 1. On part de la version entrante, en y reportant les drapeaux monotones de l'ancienne.
    FOR v_elem IN SELECT value FROM jsonb_array_elements(COALESCE(NEW.convocations, '[]'::jsonb)) LOOP
      SELECT o.value INTO v_old
        FROM jsonb_array_elements(COALESCE(OLD.convocations, '[]'::jsonb)) o
       WHERE public.assemblee_cle_convocation(o.value) = public.assemblee_cle_convocation(v_elem)
       LIMIT 1;

      IF v_old IS NOT NULL THEN
        IF COALESCE((v_old->>'traitee')::boolean, false) THEN
          v_elem := v_elem || jsonb_build_object('traitee', true);
        END IF;
        IF COALESCE((v_old->>'echue')::boolean, false) THEN
          v_elem := v_elem || jsonb_build_object('echue', true, 'echueTs', v_old->'echueTs');
        END IF;
      END IF;

      v_convs := v_convs || jsonb_build_array(v_elem);
      v_old := NULL;
    END LOOP;

    -- 2. Toute convocation connue de la base mais absente de la version entrante est reinjectee.
    FOR v_old IN SELECT value FROM jsonb_array_elements(COALESCE(OLD.convocations, '[]'::jsonb)) LOOP
      IF NOT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_convs) n
         WHERE public.assemblee_cle_convocation(n.value) = public.assemblee_cle_convocation(v_old)
      ) THEN
        v_convs := v_convs || jsonb_build_array(v_old);
      END IF;
    END LOOP;

    NEW.convocations := v_convs;
  END IF;

  -- ---------------------------------------------------------------- HISTORIQUE DES CRIMES
  IF NEW.historique_crimes IS DISTINCT FROM OLD.historique_crimes THEN
    v_hist := COALESCE(NEW.historique_crimes, '[]'::jsonb);

    FOR v_old IN SELECT value FROM jsonb_array_elements(COALESCE(OLD.historique_crimes, '[]'::jsonb)) LOOP
      IF v_old->>'origine' = 'serveur'
         AND v_old ? 'id'
         AND (v_old->>'expireTs' IS NULL OR now() < (v_old->>'expireTs')::timestamptz)
         AND NOT EXISTS (
           SELECT 1 FROM jsonb_array_elements(v_hist) n WHERE n.value->>'id' = v_old->>'id'
         )
      THEN
        v_hist := v_hist || jsonb_build_array(v_old);
      END IF;
    END LOOP;

    NEW.historique_crimes := v_hist;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_personnages_preserver_judiciaire ON public.personnages;
CREATE TRIGGER trg_personnages_preserver_judiciaire
  BEFORE UPDATE ON public.personnages
  FOR EACH ROW EXECUTE FUNCTION public.personnages_preserver_judiciaire();


-- =====================================================================
-- PARTIE 14 quater — VERDICT D'ECHEANCE DES CONVOCATIONS (§41)
-- =====================================================================
-- BUG CORRIGE (defaut introduit a la passe precedente de ce meme chantier). Le cron ecrivait
-- lui-meme est_emprisonne = {jours:2, raison, origine}, SANS jourFin. Or la liberation cote client
-- (verifierLiberationPrisonniers) teste state.day >= estEmprisonne.jourFin : avec jourFin
-- undefined, le test n'est jamais vrai -- le joueur n'aurait JAMAIS ete libere. Aucune ligne
-- n'etait non plus ecrite au registre 'detentions'. Et l'ecriture d'est_emprisonne par le serveur
-- aurait ete effacee par la sauvegarde suivante d'un client connecte (est_emprisonne y figure).
--
-- Le serveur ne peut d'ailleurs pas calculer correctement une peine : la duree s'exprime en jours
-- de jeu, et state.day est propre a chaque joueur.
--
-- Nouvelle repartition, la meme que pour les agressions (impacts_indices_attente) :
--   - LE SERVEUR TRANCHE : il pose sur la convocation un verdict irrevocable, echue = true. Le
--     trigger ci-dessus rend ce drapeau monotone : aucun client ne peut l'effacer.
--   - LE CLIENT DU JOUEUR APPLIQUE : a sa prochaine connexion, traiterConvocations voit le verdict
--     et appelle procederArrestation('non_presentation_convocation') -- qui calcule jourFin sur SON
--     jour, ecrit le registre detentions, et le conduit en cellule. Une seule fois, garantie par
--     traitee (lui aussi monotone).
--
-- Mise a jour ENSEMBLISTE en une instruction par joueur, sans lecture-modification-ecriture.
-- Le courrier est envoye UNIQUEMENT pour les convocations marquees par CET appel : rejouer le cron
-- ne renvoie jamais de doublon.

CREATE OR REPLACE FUNCTION public.assemblee_marquer_convocations_echues(p_country text DEFAULT 'republic')
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_perso   record;
  v_convs   jsonb;
  v_elem    jsonb;
  v_marque  boolean;
  v_noms    jsonb := '[]'::jsonb;
BEGIN
  FOR v_perso IN
    SELECT name, convocations
      FROM public.personnages
     WHERE country = p_country
       AND convocations IS NOT NULL
       AND EXISTS (
         SELECT 1 FROM jsonb_array_elements(convocations) c
          WHERE c.value ? 'limiteTs'
            AND COALESCE((c.value->>'traitee')::boolean, false) = false
            AND COALESCE((c.value->>'echue')::boolean, false) = false
            AND now() >= (c.value->>'limiteTs')::timestamptz
       )
     FOR UPDATE
  LOOP
    v_convs  := '[]'::jsonb;
    v_marque := false;

    FOR v_elem IN SELECT value FROM jsonb_array_elements(v_perso.convocations) LOOP
      IF v_elem ? 'limiteTs'
         AND COALESCE((v_elem->>'traitee')::boolean, false) = false
         AND COALESCE((v_elem->>'echue')::boolean, false) = false
         AND now() >= (v_elem->>'limiteTs')::timestamptz
      THEN
        v_elem := v_elem || jsonb_build_object('echue', true, 'echueTs', to_jsonb(now()));
        v_marque := true;
      END IF;
      v_convs := v_convs || jsonb_build_array(v_elem);
    END LOOP;

    IF v_marque THEN
      UPDATE public.personnages SET convocations = v_convs WHERE name = v_perso.name;
      v_noms := v_noms || jsonb_build_array(v_perso.name);

      -- Notification isolee : un echec d'envoi ne doit JAMAIS annuler le verdict (voir la RPC
      -- vendeur ci-dessus pour la meme justification).
      BEGIN
        INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
        VALUES (
          'mail-' || md5(random()::text || clock_timestamp()::text),
          'Commissariat', v_perso.name, 'Non-présentation à convocation',
          'Vous ne vous êtes pas présenté(e) dans le délai de 36 heures qui vous était imparti. '
          || 'Vous serez placé(e) en détention pour deux jours à votre prochaine présence.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'), false
        );
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'marques', v_noms);
END;
$$;


-- =====================================================================
-- PARTIE 15 bis — BONUS LOBBYISTE PERSISTE (§16)
-- =====================================================================
-- SEUL DDL de ce fichier portant sur une table existante. Meme precedent que
-- migration_etats_personnage_lot43.sql (requisition) et migration_carte_postale.sql
-- (carte_postale_moral_jour) : un etat de joueur qui doit survivre au rafraichissement prend une
-- COLONNE DEDIEE, jamais une cle ajoutee a un state.* implicitement suppose persiste.
--
-- L'audit du 9 septembre a etabli que state.bonusLobbyisteMarchandage n'existait qu'en memoire :
-- le joueur payait 1 PA + 300 FR pour un bonus perdu au premier F5. §16 impose desormais qu'il
-- survive a reload/reconnexion.
--
-- Valeur en POINTS DE POURCENTAGE, additionnee au taux de marchandage. DEFAULT 0 : les
-- personnages existants sont corrects sans reprise de donnees.

ALTER TABLE public.personnages
  ADD COLUMN IF NOT EXISTS bonus_lobbyiste integer NOT NULL DEFAULT 0;


-- =====================================================================
-- PARTIE 15 ter — PERSISTANCE DES SUITES D'UNE NEUTRALISATION (§19)
-- =====================================================================
-- BUG CORRIGE. L'audit du 9 septembre 2026 a etabli que state.hospitalisation,
-- state.statsAffaiblies et state.regenJour ont ZERO occurrence dans supabase.js : seuls les PV
-- etaient persistes. Un simple F5 sortait donc instantanement la victime de convalescence, lui
-- rendait ses PA et ses deux statistiques affaiblies -- c'est-a-dire toute la sanction reelle
-- d'une agression.
--
-- §19 impose que les consequences survivent au reload, a la reconnexion et au changement de
-- session. Trois colonnes dediees, meme doctrine que ci-dessus.
--
--   hospitalisation : {jourDebut, palier, lieu, jourFin} ou NULL
--   stats_affaiblies: {INT:true, VOL:true, ...} ou {} -- 2 stats tirees a l'agression
--   regen_jour      : jour de jeu du dernier declenchement de regeneration, ou NULL
--
-- Toutes NULLABLE avec defaut sur : un personnage jamais agresse est correct sans reprise.
ALTER TABLE public.personnages
  ADD COLUMN IF NOT EXISTS hospitalisation  jsonb,
  ADD COLUMN IF NOT EXISTS stats_affaiblies jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS regen_jour       integer;


-- =====================================================================
-- PARTIE 16 — RLS
-- =====================================================================
-- Meme doctrine que journal_editions / interviews_jodie : lecture publique (le parlement est
-- public), ecriture EXCLUSIVEMENT par les RPC ci-dessus, qui sont SECURITY DEFINER.
--
-- Consequence voulue : un joueur ne peut pas s'ajouter un POUR en tapant directement l'API REST,
-- ni crediter une caisse, ni retourner une intention sans passer par le marchandage et son debit.

ALTER TABLE public.assemblee_sieges        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_propositions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_intentions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_votes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_scrutins      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_indemnites    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS assemblee_sieges_lecture       ON public.assemblee_sieges;
DROP POLICY IF EXISTS assemblee_propositions_lecture ON public.assemblee_propositions;
DROP POLICY IF EXISTS assemblee_intentions_lecture   ON public.assemblee_intentions;
DROP POLICY IF EXISTS assemblee_votes_lecture        ON public.assemblee_votes;
DROP POLICY IF EXISTS assemblee_scrutins_lecture     ON public.assemblee_scrutins;

CREATE POLICY assemblee_sieges_lecture       ON public.assemblee_sieges       FOR SELECT USING (true);
CREATE POLICY assemblee_propositions_lecture ON public.assemblee_propositions FOR SELECT USING (true);
CREATE POLICY assemblee_intentions_lecture   ON public.assemblee_intentions   FOR SELECT USING (true);
CREATE POLICY assemblee_votes_lecture        ON public.assemblee_votes        FOR SELECT USING (true);
CREATE POLICY assemblee_scrutins_lecture     ON public.assemblee_scrutins     FOR SELECT USING (true);

-- assemblee_indemnites : AUCUNE policy de lecture. Le detail des versements n'a pas a etre
-- public, et le client n'en a jamais besoin (la RPC lui renvoie le montant verse).
-- assemblee_sieges.endormi_par est lisible : accepte, car la colonne n'est jamais renseignee par
-- le chemin de neutralisation (voir plateau-assemblee.js, appel avec p_par = NULL) -- §15/§25
-- imposent le secret de l'auteur.

-- SECURITY DEFINER : les RPC ecrivent malgre la RLS. C'est le seul chemin d'ecriture.
ALTER FUNCTION public.assemblee_deposer(text,text,text,text,text,text,text,text)   SECURITY DEFINER;
ALTER FUNCTION public.assemblee_amender(text,text,text)                            SECURITY DEFINER;
ALTER FUNCTION public.assemblee_retirer(text,text)                                 SECURITY DEFINER;
ALTER FUNCTION public.assemblee_ouvrir_session(text,timestamptz)                   SECURITY DEFINER;
ALTER FUNCTION public.assemblee_ouvrir_sessions_eligibles(timestamptz,text)        SECURITY DEFINER;
ALTER FUNCTION public.assemblee_voter(text,text,text)                              SECURITY DEFINER;
ALTER FUNCTION public.assemblee_marchander(text,text,text,boolean,integer,text)    SECURITY DEFINER;
ALTER FUNCTION public.assemblee_endormir(text,text)                                SECURITY DEFINER;
ALTER FUNCTION public.assemblee_reveiller(text)                                    SECURITY DEFINER;
ALTER FUNCTION public.assemblee_reveil_minuit(text)                                SECURITY DEFINER;
ALTER FUNCTION public.assemblee_cloturer(text)                                     SECURITY DEFINER;
ALTER FUNCTION public.assemblee_cloturer_echues(text)                              SECURITY DEFINER;
ALTER FUNCTION public.assemblee_verser_indemnite(text,text,integer)                SECURITY DEFINER;
-- Ecrit dans la ligne d'un TIERS (le vendeur) : SECURITY DEFINER est ici la condition meme de la
-- non-falsifiabilite -- c'est la fonction, et elle seule, qui decide qui est incrimine.
ALTER FUNCTION public.assemblee_tracer_vente_interdite(text,text,text,text)        SECURITY DEFINER;
-- Verdict d'echeance : ecrit dans la ligne de joueurs potentiellement hors ligne.
ALTER FUNCTION public.assemblee_marquer_convocations_echues(text)                  SECURITY DEFINER;
-- Le trigger de preservation (personnages_preserver_judiciaire) n'est PAS en SECURITY DEFINER :
-- il n'ecrit dans aucune autre table et s'execute avec les droits de l'ecrivain qui l'a declenche.
-- Il n'y a donc aucune elevation de privilege a lui accorder.
ALTER FUNCTION public.assemblee_crediter_caisse(text,integer)                      SECURITY DEFINER;
ALTER FUNCTION public.assemblee_debiter_caisse_plafonne(text,integer)              SECURITY DEFINER;


-- =====================================================================
-- FIN
-- =====================================================================
-- RESUME DES OBJETS CREES
--   Tables    : assemblee_sieges (9 lignes seedees), assemblee_propositions,
--               assemblee_intentions, assemblee_votes, assemblee_scrutins,
--               assemblee_indemnites
--   Colonne   : personnages.bonus_lobbyiste (integer, DEFAULT 0) -- seul DDL sur une table
--               existante, additif et sans reprise de donnees
--   Fonctions : assemblee_occupation_sieges, assemblee_peut_deposer, assemblee_deposer,
--               assemblee_amender, assemblee_retirer, assemblee_ouvrir_session,
--               assemblee_ouvrir_sessions_eligibles, assemblee_voter, assemblee_marchander,
--               assemblee_endormir, assemblee_reveiller, assemblee_reveil_minuit,
--               assemblee_cloturer, assemblee_cloturer_echues, assemblee_verser_indemnite,
--               assemblee_crediter_caisse, assemblee_debiter_caisse_plafonne,
--               assemblee_tracer_vente_interdite, assemblee_marquer_convocations_echues,
--               assemblee_cle_convocation, assemblee_proposition_immuable (trigger),
--               personnages_preserver_judiciaire (trigger BEFORE UPDATE sur personnages)
--
-- Une seule table existante est alteree : personnages (ajout additif de bonus_lobbyiste).
-- caisses_batiments est seulement lue/ecrite en donnees, jamais alteree.
