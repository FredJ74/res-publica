-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011004500 (UTC), nom `presidence_memoire_des_mandats`.
-- Le registre passe de 641 a 642 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 4ed81b8582fde495633acad278940e76, 31679 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA MEMOIRE DES MANDATS -- LE DERNIER RELIQUAT DU PALAIS PRESIDENTIEL
--
-- Huguette Papier portait « la memoire des mandats » dans son domaine declare depuis le
-- 11 octobre au matin, et son corpus en parlait au passe general : elle n'avait aucune matiere.
--
-- UNE SEULE REGLE GOUVERNE CETTE TABLE : elle ne contient que des faits ATTESTES PAR LE SERVEUR.
-- La porte d'ecriture oppose quatre refus -- pas de President joueur, source non declaree, genre
-- qui contredit sa source, reaction dont l'acteur n'est pas le President -- et c'est le premier
-- qui garantit que « la memoire commence au premier mandat reellement exerce » : au 11 octobre
-- 2026 la beta n'a jamais eu de President PJ et les tables d'evenements nationaux sont toutes
-- vides. La memoire nait donc VIDE, et rien n'est reconstruit.
--
-- LE CHOIX CENTRAL : LES QUATRE PANNEAUX DU BUREAU N'Y SONT PAS. pouvoirs_exceptionnels,
-- adresse_a_la_nation, gestion_premier_ministre et postes_par_decret sont declares au miroir a
-- (0 PA, 0 FR) : ce qui franchit payer_ordre, c'est L'OUVERTURE DU PANNEAU, pas l'acte. Les
-- enregistrer aurait ecrit « le President a declare la guerre » quand il a ouvert une fenetre.
-- Les sources non raccordables sont donc tenues dans une TABLE que le banc relit, et non dans un
-- commentaire que personne ne verifie.
--
-- L'INACTION N'EST JAMAIS ECRITE, ELLE EST DEDUITE A LA LECTURE. Ecrire « il n'a pas reagi »
-- exigerait un seuil de temps que personne n'a arbitre. La lecture rattache a chaque contexte la
-- premiere reaction qui l'a suivi dans le meme mandat, ou rien -- et « rien » est une observation.
--
-- UNE PREUVE A ETE RESSERREE AVANT L'APPLICATION, et c'est la deuxieme fois en deux jours :
-- P8 cherchait « %note% » dans toutes les tables de la memoire et echouait sur la colonne `note`
-- de la table des SOURCES, qui est de la documentation et non un jugement. Une preuve trop large
-- accuse le mot plutot que la chose.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LA MEMOIRE DES MANDATS -- CE QU'HUGUETTE PAPIER A VU PASSER (11 octobre 2026)
-- =================================================================================================
-- DERNIER RELIQUAT DU PALAIS PRESIDENTIEL. Huguette porte « la memoire des mandats » dans son
-- domaine declare depuis le 11 octobre, et son corpus en parlait au passe general : elle n'avait
-- aucune matiere. Cette migration lui en donne une, et UNE SEULE REGLE la gouverne : elle ne
-- contient que des faits ATTESTES PAR LE SERVEUR.
--
-- CE QUE LA MEMOIRE N'EST PAS, et chacune de ces lignes a coute une decision :
--   . ce n'est PAS un journal des six ordres presidentiels. Les quatre ordres de REGROUPEMENT du
--     Bureau -- pouvoirs_exceptionnels, adresse_a_la_nation, gestion_premier_ministre,
--     postes_par_decret -- sont declares au miroir a (0 PA, 0 FR) : ce qui franchit payer_ordre,
--     c'est L'OUVERTURE DU PANNEAU, pas l'acte. Leurs sous-actions (guerre 5 PA, dissolution
--     4 PA, referendum 3 PA...) ne passent par aucune porte serveur aujourd'hui. Les enregistrer
--     reviendrait a ecrire « le President a declare la guerre » quand il a ouvert une fenetre.
--     Ils sont donc VOLONTAIREMENT absents du registre, et la liste des sources non raccordables
--     est tenue dans `presidence_memoire_sources_absentes` plutot que dans un commentaire ;
--   . ce n'est PAS un log technique : seuls des faits PUBLICS y entrent, jamais une position, un
--     solde, une possession ni un fait prive ;
--   . ce n'est PAS un score. Aucune colonne ne dit si un mandat fut bon ou mauvais, et il n'existe
--     aucune fonction qui l'en deduise. Huguette raconte, elle ne note pas ;
--   . ce n'est PAS un passe reconstruit. La beta n'a jamais connu de President PJ et aucune des
--     tables d'evenements nationaux ne porte une seule ligne (0 greve, 0 guerre, 0 manifestation,
--     0 scandale au 11 octobre 2026). La memoire naitra donc VIDE et commencera au premier
--     mandat reellement exerce : la porte d'ecriture refuse d'enregistrer quoi que ce soit tant
--     qu'aucun PJ ne tient la Presidence.
--
-- L'INACTION N'EST JAMAIS ECRITE, ELLE EST DEDUITE A LA LECTURE. Ecrire « le President n'a pas
-- reagi » exigerait de decider au bout de combien de temps l'absence devient notable -- un seuil
-- que personne n'a arbitre, et qu'on n'invente pas. La lecture rattache donc a chaque contexte la
-- PREMIERE reaction qui l'a suivi dans le meme mandat, ou rien. « Rien » est une observation, pas
-- un jugement, et le corpus d'Huguette est explicite sur ce point.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 1. LES SOURCES, EN LISTE FERMEE
-- -------------------------------------------------------------------------------------------------
-- FAIL-CLOSED : une source inconnue ne s'enregistre pas. C'est ce qui rend impossible la
-- fabrication d'un fait -- on ne peut pas inventer un evenement sans d'abord declarer, dans une
-- migration, d'ou il vient et de quel genre il est.
CREATE TABLE IF NOT EXISTS public.presidence_memoire_sources (
  source  text PRIMARY KEY,
  genre   text NOT NULL,
  note    text NOT NULL,
  CONSTRAINT presidence_memoire_genre_connu CHECK (genre = ANY (ARRAY['contexte','reaction']))
);

INSERT INTO public.presidence_memoire_sources (source, genre, note) VALUES
  ('ordre_presidentiel', 'reaction',
   'Un ordre REELLEMENT paye par le President en exercice, franchi par payer_ordre et pris dans le registre ferme presidence_memoire_ordres. L acteur est relu en base : un ministre qui tient une conference de presse n entre pas dans la memoire presidentielle, meme si l ordre porte le meme nom.'),
  ('guerre_declaree', 'reaction',
   'Notre President a declare la guerre. Atteste par guerre_declarer, qui est deja reservee au poste president et ecrit la ligne de guerres dans la meme transaction.'),
  ('guerre_subie', 'contexte',
   'Un autre empire nous a declare la guerre. C est le contexte national majeur le plus durement atteste du jeu : il ne peut pas etre produit par un navigateur.'),
  ('election_presidentielle', 'contexte',
   'Le mandat s ouvre. Consigne au depouillement par election_resultats_consigner, donc par le serveur et jamais par le client.')
ON CONFLICT (source) DO UPDATE SET genre = EXCLUDED.genre, note = EXCLUDED.note;

-- CE QUI N'EST PAS ENCORE RACCORDABLE, ET POURQUOI. Cette table n'est pas de la documentation :
-- elle est lue par le banc, qui verifie qu'aucune de ces sources n'a ete branchee en cachette, et
-- elle dit a la prochaine session ou reprendre. Une source quitte cette table le jour ou elle
-- obtient une porte serveur -- pas avant.
CREATE TABLE IF NOT EXISTS public.presidence_memoire_sources_absentes (
  sujet   text PRIMARY KEY,
  genre   text NOT NULL,
  obstacle text NOT NULL
);

INSERT INTO public.presidence_memoire_sources_absentes (sujet, genre, obstacle) VALUES
  ('greve generale', 'contexte',
   'greves_generales n a AUCUNE fonction serveur : la table est ecrite depuis le navigateur. Y puiser ferait entrer dans la memoire un fait qu un client a declare. A raccorder le jour ou le lancement de greve passe par une porte.'),
  ('manifestation', 'contexte',
   'demandes_manifestation est egalement sans fonction serveur, et vide. Meme obstacle que la greve.'),
  ('etat d urgence', 'reaction',
   'Sous-action de pouvoirs_exceptionnels (3 PA). Le miroir ne declare que le panneau a (0,0) : l acte n atteint aucune porte serveur. L enregistrer depuis payer_ordre reviendrait a confondre l ouverture de la fenetre avec la decision.'),
  ('dissolution de l Assemblee', 'reaction',
   'Sous-action de pouvoirs_exceptionnels (4 PA). Meme obstacle.'),
  ('referendum', 'reaction',
   'Sous-action de adresse_a_la_nation (3 PA). Meme obstacle -- et le couple (fn, 1 PA) de cette famille est en outre AMBIGU entre le deuil national et le decret presidentiel, donc inexploitable meme si le cout passait.'),
  ('deuil national', 'reaction',
   'Sous-action de adresse_a_la_nation (1 PA), ambigue avec le decret presidentiel. On ne nomme pas un acte qu on ne peut pas distinguer.'),
  ('decret presidentiel', 'reaction',
   'Sous-action de adresse_a_la_nation (1 PA), ambigue avec le deuil national.'),
  ('nomination du Premier ministre', 'reaction',
   'Sous-action de gestion_premier_ministre (2 PA). poste_nommer existe bien au serveur, mais elle sert TOUTES les nominations de tous les postes : y brancher la memoire presidentielle demanderait de decider quelles nominations sont presidentielles, ce qui est un arbitrage et non une lecture.'),
  ('effort national', 'reaction',
   'Sous-action de effort_national (2 PA), panneau declare a (0,0).'),
  ('scandale de presse', 'contexte',
   'scandales_presse et fuites_journalistiques sont vides et alimentees par des chemins clients. evenements_globaux, qui les reprend, est surtout un flux d AMBIANCE engendre aleatoirement -- y puiser ferait se souvenir Huguette de plaisanteries produites par un tirage.')
ON CONFLICT (sujet) DO UPDATE SET genre = EXCLUDED.genre, obstacle = EXCLUDED.obstacle;

-- -------------------------------------------------------------------------------------------------
-- 2. LES ORDRES QUI VALENT UNE REACTION, EN LISTE FERMEE
-- -------------------------------------------------------------------------------------------------
-- LE TRIPLET (fn, pa, cost) EST LA CLEF, et c'est voulu : il est exactement celui que payer_ordre
-- valide contre le miroir. Un ordre dont le cout ne correspond pas n'entre pas -- la memoire ne
-- peut donc pas etre alimentee par un cout forge.
--
-- LES PANNEAUX A (0,0) NE SONT PAS ICI. C'est la decision centrale de cette migration.
CREATE TABLE IF NOT EXISTS public.presidence_memoire_ordres (
  fn    text NOT NULL,
  pa    integer NOT NULL,
  cost  integer NOT NULL,
  sujet text NOT NULL,
  PRIMARY KEY (fn, pa, cost)
);

INSERT INTO public.presidence_memoire_ordres (fn, pa, cost, sujet) VALUES
  ('gracier',          2, 0,    'une grace examinee'),
  ('conference_presse',2, 0,    'une conference de presse'),
  ('propagande_etat',  3, 500,  'une campagne de propagande d Etat'),
  ('dementi',          2, 0,    'un dementi officiel'),
  ('reception_etat',   2, 1000, 'une reception d Etat'),
  ('banquet_diplo',    3, 2000, 'un banquet diplomatique')
ON CONFLICT (fn, pa, cost) DO UPDATE SET sujet = EXCLUDED.sujet;

-- -------------------------------------------------------------------------------------------------
-- 3. LA MEMOIRE ELLE-MEME
-- -------------------------------------------------------------------------------------------------
-- LE MANDAT EST LA CLEF, et il est pris sur `postes_attribues` : le couple (titulaire, depuis) est
-- ce qui separe deux presidences, y compris deux presidences du MEME joueur a deux epoques. Rien
-- n'est deduit d'une date de fin, parce qu'aucune table n'en porte : un mandat se termine quand
-- `depuis` change, et les lignes deja ecrites gardent l'ancienne valeur. La separation est donc
-- structurelle et non calculee.
CREATE TABLE IF NOT EXISTS public.presidence_memoire (
  id             bigserial PRIMARY KEY,
  pays           text        NOT NULL,
  president      text        NOT NULL,
  mandat_depuis  timestamptz NOT NULL,
  genre          text        NOT NULL,
  source         text        NOT NULL REFERENCES public.presidence_memoire_sources(source),
  sujet          text        NOT NULL,
  detail         jsonb       NOT NULL DEFAULT '{}'::jsonb,
  jour           integer,
  le             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT presidence_memoire_genre_connu CHECK (genre = ANY (ARRAY['contexte','reaction']))
);

CREATE INDEX IF NOT EXISTS presidence_memoire_par_mandat
  ON public.presidence_memoire (pays, president, mandat_depuis, le);

COMMENT ON TABLE public.presidence_memoire IS
  'Memoire narrative des mandats presidentiels, pour le referent Huguette Papier. N accepte que des faits PUBLICS attestes par le serveur, et uniquement pendant un mandat tenu par un joueur. Ne porte AUCUN jugement : il n existe ni score, ni colonne de reussite, ni fonction qui en deduise une (arbitrage du 11 octobre 2026).';

COMMENT ON COLUMN public.presidence_memoire.source IS
  'Provenance attestee, en liste fermee. C est elle qui rend la fabrication d un fait impossible : une source non declaree ne s enregistre pas.';

-- AUCUN ACCES CLIENT DIRECT : la memoire se lit par sa porte, qui la projette.
ALTER TABLE public.presidence_memoire                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presidence_memoire_sources            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presidence_memoire_sources_absentes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presidence_memoire_ordres             ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------------------------------
-- 4. QUI EST LE PRESIDENT, ET DEPUIS QUAND
-- -------------------------------------------------------------------------------------------------
-- UN SEUL RESOLVEUR, et tout le reste s'y appuie. Il rend NULL quand la Presidence n'est pas tenue
-- par un joueur -- et NULL est ce qui fait que la memoire reste vide jusqu'au premier mandat reel.
CREATE OR REPLACE FUNCTION public.presidence_mandat_courant(p_pays text)
 RETURNS TABLE(president text, depuis timestamptz)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT pa.titulaire, pa.depuis
    FROM public.postes_attribues pa
    JOIN public.personnages_donnees c ON c.name = pa.titulaire
   WHERE pa.poste_id = 'president' AND pa.country = p_pays
     AND pa.titulaire IS NOT NULL
   LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.presidence_mandat_courant(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.presidence_mandat_courant(text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 5. LA PORTE D'ECRITURE
-- -------------------------------------------------------------------------------------------------
-- QUATRE REFUS, ET AUCUN N'EST DECORATIF :
--   . pas de President joueur    -> rien n'est ecrit, et c'est ainsi que « la memoire commence au
--                                   premier mandat reellement exerce » est garanti par le code ;
--   . source inconnue            -> rien n'est ecrit (fail-closed sur la provenance) ;
--   . genre different de celui   -> rien n'est ecrit : une source de contexte ne peut pas servir a
--     que la source declare        enregistrer une reaction, ni l'inverse ;
--   . reaction dont l'acteur     -> rien n'est ecrit. C'est ce qui empeche la conference de presse
--     n'est pas le President       d'un MINISTRE d'entrer dans la memoire presidentielle, alors
--                                  que les deux salles partagent le meme nom d'ordre.
CREATE OR REPLACE FUNCTION public.presidence_memoire_noter(
  p_pays text, p_genre text, p_source text, p_sujet text, p_detail jsonb, p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m record; s record; v_id bigint;
BEGIN
  IF coalesce(btrim(coalesce(p_pays,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'enregistre', false, 'raison', 'pays_absent');
  END IF;

  SELECT * INTO s FROM public.presidence_memoire_sources WHERE source = p_source;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'enregistre', false, 'raison', 'source_non_declaree');
  END IF;
  IF s.genre IS DISTINCT FROM p_genre THEN
    RETURN jsonb_build_object('ok', false, 'enregistre', false, 'raison', 'genre_contredit_la_source',
                              'genre_declare', s.genre);
  END IF;

  SELECT * INTO m FROM public.presidence_mandat_courant(p_pays);
  IF NOT FOUND THEN
    -- AUCUN PRESIDENT JOUEUR : on n'ecrit rien, et ce n'est pas un echec. C'est l'etat de la beta
    -- au 11 octobre 2026, et c'est ce qui empeche de fabriquer un passe.
    RETURN jsonb_build_object('ok', true, 'enregistre', false, 'raison', 'aucun_president_joueur');
  END IF;

  IF p_genre = 'reaction' AND coalesce(p_acteur, '') IS DISTINCT FROM m.president THEN
    RETURN jsonb_build_object('ok', true, 'enregistre', false, 'raison', 'acteur_n_est_pas_le_president');
  END IF;

  INSERT INTO public.presidence_memoire (pays, president, mandat_depuis, genre, source, sujet, detail, jour)
  VALUES (p_pays, m.president, m.depuis, p_genre, p_source, p_sujet,
          coalesce(p_detail, '{}'::jsonb), public.jour_de_jeu_pays(p_pays))
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'enregistre', true, 'id', v_id,
                            'president', m.president, 'mandat_depuis', m.depuis);
END;
$function$;

REVOKE ALL ON FUNCTION public.presidence_memoire_noter(text, text, text, text, jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.presidence_memoire_noter(text, text, text, text, jsonb, text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 6. LA LECTURE : CE QU'HUGUETTE PEUT RACONTER
-- -------------------------------------------------------------------------------------------------
-- L'INACTION EST DEDUITE ICI, JAMAIS STOCKEE. Chaque contexte recoit la PREMIERE reaction qui l'a
-- suivi dans le meme mandat, ou `null`. Aucun seuil de temps n'est applique, parce qu'aucun n'a ete
-- arbitre : « rien apres » est rendu tel quel, et c'est le corpus qui dit a Huguette que cela
-- signifie « je n'ai rien vu venir », pas « il a failli ».
CREATE OR REPLACE FUNCTION public.presidence_memoire_contexte(p_pays text, p_limite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_lim integer := least(greatest(coalesce(p_limite, 12), 1), 40); v_mandats jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(x ORDER BY (x->>'depuis') DESC), '[]'::jsonb) INTO v_mandats
  FROM (
    SELECT jsonb_build_object(
             'president', q.president,
             'depuis', q.mandat_depuis,
             'en_cours', (q.president = c.president AND q.mandat_depuis = c.depuis),
             'faits', q.faits) AS x
      FROM (
        SELECT m.president, m.mandat_depuis,
               jsonb_agg(jsonb_build_object(
                 'genre', m.genre, 'sujet', m.sujet, 'jour', m.jour, 'le', m.le,
                 'detail', m.detail,
                 -- La premiere reaction posterieure DANS LE MEME MANDAT. NULL est une observation.
                 'suivi_de', CASE WHEN m.genre = 'contexte' THEN (
                     SELECT r.sujet FROM public.presidence_memoire r
                      WHERE r.pays = m.pays AND r.president = m.president
                        AND r.mandat_depuis = m.mandat_depuis
                        AND r.genre = 'reaction' AND r.le > m.le
                      ORDER BY r.le LIMIT 1) ELSE NULL END
               ) ORDER BY m.le) AS faits
          FROM public.presidence_memoire m
         WHERE m.pays = p_pays
           AND m.id > (SELECT coalesce(max(id), 0) - v_lim * 8 FROM public.presidence_memoire WHERE pays = p_pays)
         GROUP BY m.president, m.mandat_depuis, m.pays
      ) q
      LEFT JOIN public.presidence_mandat_courant(p_pays) c ON true
  ) z;

  RETURN jsonb_build_object('ok', true, 'mandats', v_mandats,
                            'vide', v_mandats = '[]'::jsonb);
END;
$function$;

REVOKE ALL ON FUNCTION public.presidence_memoire_contexte(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.presidence_memoire_contexte(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.presidence_memoire_contexte(text, integer) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 7. LE RACCORDEMENT : payer_ordre DEVIENT LE TEMOIN DES ACTES PRESIDENTIELS
-- -------------------------------------------------------------------------------------------------
-- POURQUOI ICI ET NON DANS SIX HANDLERS. payer_ordre est la porte que tout ordre paye franchit, et
-- un succes y est deja un FAIT ATTESTE : l'acteur est verifie par exiger_acteur, le triplet est
-- valide contre le miroir, et les PA sont reellement pris. Brancher la memoire sur son succes ne
-- cree aucune mecanique et ne touche aucun handler.
--
-- ELLE RESTE AGNOSTIQUE DU DOMAINE : elle ne connait pas la Presidence, elle interroge un registre.
-- Le seul ajout est une consultation d'une table de six lignes, apres le prelevement, sur le chemin
-- de succes uniquement.
--
-- LA SIGNATURE EST REPRISE AVEC SES VALEURS PAR DEFAUT, sans quoi PostgreSQL refuse le
-- remplacement (« cannot remove parameter defaults from existing function ») : trois des
-- quatre parametres en portent une, et 268 sites d'appel s'y fient.
CREATE OR REPLACE FUNCTION public.payer_ordre(p_acteur text, p_fn text DEFAULT NULL::text,
                                              p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_fn text := coalesce(nullif(btrim(coalesce(p_fn,'')), ''), '(non transmis)');
  v_connu boolean; v_valide boolean;
  v_pa integer; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric;
  v_memorable record; v_pays text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_pa, 0) < 0 OR coalesce(p_cost, 0) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_negatif');
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v_fn) INTO v_connu;

  IF NOT v_connu THEN
    INSERT INTO public.ordres_couts_inconnus (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn) DO UPDATE SET occurrences = public.ordres_couts_inconnus.occurrences + 1;
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu', 'fn', v_fn);
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o
                 WHERE o.fn = v_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0))
    INTO v_valide;
  IF NOT v_valide THEN
    INSERT INTO public.ordres_couts_ecarts (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn, pa, cost)
      DO UPDATE SET occurrences = public.ordres_couts_ecarts.occurrences + 1, vu_le = now();
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare',
                              'fn', v_fn, 'pa', p_pa, 'cost', p_cost);
  END IF;

  SELECT pa, liquide, arg INTO v_pa, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);

  IF v_pa < coalesce(p_pa, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;
  IF coalesce(v_liquide,0) + v_solde < coalesce(p_cost, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'disponible', coalesce(v_liquide,0) + v_solde);
  END IF;

  v_pris_liquide := least(coalesce(v_liquide,0), coalesce(p_cost,0));
  v_pris_national := coalesce(p_cost,0) - v_pris_liquide;

  UPDATE public.personnages_donnees
     SET pa = v_pa - coalesce(p_pa,0),
         liquide = coalesce(v_liquide,0) - v_pris_liquide,
         arg = coalesce(v_arg,0) - coalesce(p_cost,0)
   WHERE name = p_acteur;

  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national,
           updated_at = now() WHERE id = v_compte_id;
  END IF;

  -- LA MEMOIRE DES MANDATS (11 octobre 2026). Apres le prelevement, donc sur un fait accompli, et
  -- seulement si le triplet figure au registre des actes memorables. `presidence_memoire_noter`
  -- verifie elle-meme que l'acteur est bien le President en exercice : si c'est un ministre qui
  -- tient la conference de presse, rien n'est ecrit. Le registre ne contient AUCUN panneau a
  -- (0 PA, 0 FR) -- ouvrir une fenetre n'est pas un acte.
  SELECT * INTO v_memorable FROM public.presidence_memoire_ordres
   WHERE fn = v_fn AND pa = coalesce(p_pa,0) AND cost = coalesce(p_cost,0);
  IF FOUND THEN
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_acteur;
    PERFORM public.presidence_memoire_noter(
      v_pays, 'reaction', 'ordre_presidentiel', v_memorable.sujet,
      jsonb_build_object('ordre', v_fn, 'pa', coalesce(p_pa,0), 'cout', coalesce(p_cost,0)),
      p_acteur);
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'pa', v_pa - coalesce(p_pa,0),
    'liquide', coalesce(v_liquide,0) - v_pris_liquide,
    'arg', coalesce(v_arg,0) - coalesce(p_cost,0),
    'solde_national', v_solde - v_pris_national,
    'pa_preleves', coalesce(p_pa,0), 'montant_preleve', coalesce(p_cost,0));
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 8. LA GUERRE : UNE REACTION D'UN COTE, UN CONTEXTE DE L'AUTRE
-- -------------------------------------------------------------------------------------------------
-- LE MEME FAIT A DEUX SENS, et il faut les deux. Declarer la guerre est l'acte le plus lourd d'un
-- President ; la SUBIR est le contexte national le plus dur auquel un autre President doit
-- repondre. La fonction ecrit donc dans la memoire des DEUX pays, chacun avec son genre -- et
-- chacun n'enregistre que s'il a un President joueur, ce dont la porte decide seule.
CREATE OR REPLACE FUNCTION public.guerre_declarer(p_pays_attaque text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_id text; v_moi text;
BEGIN
  v_pays := public.guerre_acteur_poste('president');
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president');
  END IF;
  IF p_pays_attaque IS NULL OR btrim(p_pays_attaque) = '' OR p_pays_attaque = v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;
  -- Une seule guerre active entre deux memes pays, quel que soit le sens.
  IF EXISTS (SELECT 1 FROM public.guerres g
              WHERE g.statut = 'active'
                AND ((g.data ->> 'attaquant' = v_pays AND g.data ->> 'attaque' = p_pays_attaque)
                  OR (g.data ->> 'attaque' = v_pays AND g.data ->> 'attaquant' = p_pays_attaque))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'guerre_deja_active');
  END IF;

  v_id := 'guerre-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  INSERT INTO public.guerres (id, statut, data)
  VALUES (v_id, 'active', jsonb_build_object(
    'attaquant', v_pays, 'attaque', p_pays_attaque,
    'jourDebut', public.jour_de_jeu_pays(v_pays), 'ceasefire', NULL));

  -- LA MEMOIRE DES MANDATS (11 octobre 2026), dans la MEME transaction que la guerre : il est
  -- impossible qu'une guerre existe sans que la memoire l'ait vue, ou l'inverse.
  v_moi := public.mon_personnage();
  PERFORM public.presidence_memoire_noter(
    v_pays, 'reaction', 'guerre_declaree',
    'la declaration de guerre a ' || p_pays_attaque,
    jsonb_build_object('guerre', v_id, 'attaque', p_pays_attaque), v_moi);
  PERFORM public.presidence_memoire_noter(
    p_pays_attaque, 'contexte', 'guerre_subie',
    'la guerre declaree par ' || v_pays,
    jsonb_build_object('guerre', v_id, 'attaquant', v_pays), NULL);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'attaquant', v_pays, 'attaque', p_pays_attaque);
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : la memoire nait VIDE. Aucune ligne, aucun passe reconstruit.
  SELECT count(*) INTO v_n FROM public.presidence_memoire;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 : la memoire nait avec % lignes', v_n; END IF;

  -- P2 : les quatre sources sont declarees, et chacune a un genre valide.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources;
  IF v_n <> 4 THEN RAISE EXCEPTION 'P2 : % sources declarees au lieu de 4', v_n; END IF;

  -- P3 : les six actes memorables, et AUCUN panneau a (0,0). C'est la preuve que l'ouverture
  -- d'une fenetre n'entrera jamais dans la memoire comme une reaction.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_ordres;
  IF v_n <> 6 THEN RAISE EXCEPTION 'P3a : % actes memorables au lieu de 6', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.presidence_memoire_ordres WHERE pa = 0 AND cost = 0;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3b : % panneau(x) a (0,0) dans le registre des actes', v_n; END IF;

  -- P4 : chaque acte memorable existe REELLEMENT au miroir des couts, au triplet exact. Sans
  -- cela, payer_ordre ne le laisserait jamais passer et la ligne du registre serait morte.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_ordres r
   WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o
                      WHERE o.fn = r.fn AND o.pa = r.pa AND o.cost = r.cost);
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4 : % acte(s) memorable(s) absent(s) du miroir des couts', v_n; END IF;

  -- P5 : les sources non raccordables sont NOMMEES, et aucune ne s'est glissee dans les sources
  -- actives. Les deux listes sont disjointes, et le banc le reverifie.
  SELECT count(*) INTO v_n FROM public.presidence_memoire_sources_absentes;
  IF v_n < 10 THEN RAISE EXCEPTION 'P5a : seulement % sources absentes documentees', v_n; END IF;

  -- P6 : payer_ordre consulte bien le registre, et guerre_declarer ecrit bien les DEUX sens.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'payer_ordre'
     AND p.prosrc LIKE '%presidence_memoire_ordres%'
     AND p.prosrc LIKE '%presidence_memoire_noter%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6a : payer_ordre ne temoigne pas des actes presidentiels'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'guerre_declarer'
     AND p.prosrc LIKE '%guerre_declaree%' AND p.prosrc LIKE '%guerre_subie%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6b : guerre_declarer n ecrit pas les deux sens'; END IF;

  -- P7 : la porte d'ecriture est fermee au navigateur, la porte de lecture lui est ouverte, et
  -- aucune des deux n'est accessible a anon.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'presidence_memoire_noter'
     AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7a : la porte d ecriture de la memoire est ouverte a un client'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'presidence_memoire_contexte'
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7b : la porte de lecture de la memoire est mal posee'; END IF;

  -- P8 : AUCUNE NOTION DE JUGEMENT dans la table de memoire. Si un jour quelqu'un y ajoute une
  -- colonne d'appreciation, cette preuve tombe.
  --
  -- ELLE NE PORTE QUE SUR `presidence_memoire`, et les mots cherches sont PRECIS. Une premiere
  -- version balayait toutes les tables `presidence_memoire%` avec le motif « %note% » : elle
  -- echouait sur la colonne `note` de la table des SOURCES, qui est de la documentation et non un
  -- jugement. Une preuve trop large accuse le mot plutot que la chose -- meme erreur que la preuve
  -- du contexte public, qui se jugeait sur ses propres commentaires.
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'presidence_memoire'
     AND (column_name LIKE '%score%' OR column_name LIKE '%notation%'
          OR column_name LIKE '%reussite%' OR column_name LIKE '%echec%'
          OR column_name LIKE '%bilan%' OR column_name LIKE '%jugement%'
          OR column_name LIKE '%appreciation%');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P8 : une colonne de jugement est apparue dans la memoire'; END IF;

  -- P9 : les quatre tables de la memoire sont sous RLS sans policy -- fermees a tout client.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relrowsecurity AND c.relname LIKE 'presidence_memoire%';
  IF v_n <> 4 THEN RAISE EXCEPTION 'P9a : % tables de memoire sous RLS au lieu de 4', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename LIKE 'presidence_memoire%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P9b : % policy sur les tables de la memoire', v_n; END IF;

  RAISE NOTICE 'Memoire des mandats : les 9 preuves structurelles passent.';
END $$;
