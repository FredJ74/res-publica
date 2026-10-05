-- ======================================================================
-- MOTEUR DE COMBAT V2 — LOT COMPLET
-- 21 septembre 2026
-- ======================================================================
--
-- Moteur de combat serveur V2 : primitives du jet, groupe comme unite de
-- decision, ciblage et application des pertes, boucle de round, repli par
-- groupe, etat de bataille par groupe, et fermeture des droits anon.
--
-- AVERTISSEMENT — FICHIER DE VERSIONNEMENT, PAS DE DEVELOPPEMENT.
-- Ce fichier ne fait que reproduire, a l'identique et DANS L'ORDRE
-- CHRONOLOGIQUE REELLEMENT APPLIQUE, les migrations deja passees en
-- production. Le SQL n'a ete ni corrige, ni reformate, ni consolide :
-- certaines migrations REDEFINISSENT un objet pose par une migration
-- anterieure du meme lot (avec DROP et changement de signature), et un
-- rejeu sequentiel fidele est plus sur qu'un etat final reconstruit.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES, dans cet ordre :
--   20260920224857  militaire_combat_primitives_v2
--   20260920225121  militaire_batailles_groupes
--   20260920225218  militaire_combat_moteur_v2
--   20260920225330  militaire_combat_round_et_repli_par_groupe
--   20260920225508  militaire_combat_boucle_v2
--   20260920225758  militaire_repli_defaut_groupe_pnj
--   20260920230054  militaire_bataille_etat_par_groupe
--   20260920230517  militaire_revoquer_anon_primitives_v2
--
-- REDEFINITIONS EN COURS DE FICHIER (attendues) :
--   militaire_bataille_appliquer : creee par 20260920225218 (RETURNS void),
--     puis REDEFINIE par 20260920225508 avec DROP FUNCTION explicite et un
--     nouveau type de retour (RETURNS jsonb).
--   militaire_bataille_groupes_constituer : creee par 20260920225330, puis
--     REDEFINIE par 20260920225758 (repli par defaut des groupes PNJ).
-- ======================================================================


-- ######################################################################
-- MIGRATION 20260920224857  militaire_combat_primitives_v2
-- ######################################################################

-- =====================================================================
-- MOTEUR DE COMBAT V2 — PRIMITIVES DU JET (21 septembre 2026)
-- =====================================================================
-- Arbitrages GD appliques a la lettre. Fonctions PURES, sans acces aux
-- tables sauf le miroir des armes : testables isolement.
--
-- CE QUI CHANGE PAR RAPPORT A LA V1
--   * T n'est plus un differentiel a coefficients 0,7 / 0,5 / 0,5. La base
--     est 50, l'entrainement offensif vaut +comp/3 et la competence de la
--     cible -comp/5. La caracteristique defensive ne compte plus que par son
--     ECART a 8.
--   * le de est oriente HAUT = BON ;
--   * cinq degres sur des bandes absolues de score ;
--   * les degats sont PROPORTIONNELS aux PA courants, plus des points fixes ;
--   * l'arme porte enfin un bonus, repris du catalogue civil existant.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. DEFENSE DES SOLDATS PNJ — desormais neutre
-- ---------------------------------------------------------------------
-- Les constantes historiques PER=10 / DUP=3 sont abandonnees : elles
-- rendaient le corps-a-corps structurellement plus facile que le tir contre
-- un PNJ. A 8, l'ecart a la valeur neutre est nul : la qualite defensive
-- d'un soldat vient desormais de son ENTRAINEMENT, et de lui seul.
CREATE OR REPLACE FUNCTION public.militaire_defense_pnj(p_cle text)
RETURNS numeric LANGUAGE sql IMMUTABLE AS $function$
  SELECT 8::numeric;
$function$;


-- ---------------------------------------------------------------------
-- 2. LE TAUX T
-- ---------------------------------------------------------------------
--   T = clamp(10, 85, 50 + comp_off/3 - comp_cible/5 - (stat_cible - 8) + bonus_arme)
--
-- Progression offensive intrinseque : 0 -> +0, 30 -> +10, 60 -> +20,
-- 100 -> +33,33. La competence de la cible retire jusqu'a -20 a 100.
-- Chaque point de caracteristique au-dessus de 8 coute 1 point de T a
-- l'attaquant ; chaque point en dessous lui en rend 1.
DROP FUNCTION IF EXISTS public.militaire_taux_combat(numeric, numeric, numeric);

CREATE FUNCTION public.militaire_taux_combat(
  p_comp_off numeric, p_comp_cible numeric, p_stat_cible numeric,
  p_bonus_arme integer DEFAULT 0)
RETURNS integer LANGUAGE sql IMMUTABLE AS $function$
  SELECT greatest(10, least(85, round(
      50 + coalesce(p_comp_off, 0) / 3.0
         - coalesce(p_comp_cible, 0) / 5.0
         - (coalesce(p_stat_cible, 8) - 8)
         + coalesce(p_bonus_arme, 0)
    )::integer));
$function$;

REVOKE ALL ON FUNCTION public.militaire_taux_combat(numeric, numeric, numeric, integer) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. LES CINQ DEGRES
-- ---------------------------------------------------------------------
--   score = d100 + (T - 50) / 2,  borne a [0, 100]
--     >= 95  critique      |  >= 70  partielle_1  |  >= 50  partielle_2
--     >= 10  echec         |  <  10  echec_critique
--
-- PLANCHER INCOMPRESSIBLE : le 1 NATUREL du de est un echec critique, quel
-- que soit T et quel que soit le bonus d'arme. Il est teste AVANT tout
-- modificateur, et aucun second tirage n'est necessaire : le meme de porte
-- le plancher et le resultat.
CREATE OR REPLACE FUNCTION public.militaire_degre_combat(p_taux integer, p_jet integer)
RETURNS text LANGUAGE sql IMMUTABLE AS $function$
  SELECT CASE
    WHEN p_jet = 1 THEN 'echec_critique'
    ELSE (SELECT CASE
            WHEN s >= 95 THEN 'critique'
            WHEN s >= 70 THEN 'partielle_1'
            WHEN s >= 50 THEN 'partielle_2'
            WHEN s >= 10 THEN 'echec'
            ELSE                'echec_critique'
          END
          FROM (SELECT least(100, greatest(0,
                  p_jet + (coalesce(p_taux, 50) - 50) / 2.0)) AS s) x)
  END;
$function$;


-- ---------------------------------------------------------------------
-- 4. ORDRE DES DEGRES — pour la surprise (+1) et le gilet (-1)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_degre_rang(p_degre text)
RETURNS integer LANGUAGE sql IMMUTABLE AS $function$
  SELECT CASE p_degre
    WHEN 'echec_critique' THEN 0
    WHEN 'echec'          THEN 1
    WHEN 'partielle_2'    THEN 2
    WHEN 'partielle_1'    THEN 3
    WHEN 'critique'       THEN 4
  END;
$function$;

CREATE OR REPLACE FUNCTION public.militaire_degre_par_rang(p_rang integer)
RETURNS text LANGUAGE sql IMMUTABLE AS $function$
  SELECT CASE greatest(0, least(4, coalesce(p_rang, 0)))
    WHEN 0 THEN 'echec_critique'
    WHEN 1 THEN 'echec'
    WHEN 2 THEN 'partielle_2'
    WHEN 3 THEN 'partielle_1'
    ELSE        'critique'
  END;
$function$;


-- ---------------------------------------------------------------------
-- 5. PERTE DE PA PAR DEGRE — proportionnelle aux PA COURANTS
-- ---------------------------------------------------------------------
-- Les PA restants sont arrondis a l'entier INFERIEUR (decision GD).
CREATE OR REPLACE FUNCTION public.militaire_degats_pct(p_degre text)
RETURNS numeric LANGUAGE sql IMMUTABLE AS $function$
  SELECT CASE p_degre
    WHEN 'critique'    THEN 1.00
    WHEN 'partielle_1' THEN 0.75
    WHEN 'partielle_2' THEN 0.50
    ELSE                    0.00
  END;
$function$;

CREATE OR REPLACE FUNCTION public.militaire_pa_restants(p_pa integer, p_degre text)
RETURNS integer LANGUAGE sql IMMUTABLE AS $function$
  SELECT greatest(0, floor(greatest(0, coalesce(p_pa, 0))
                           * (1 - public.militaire_degats_pct(p_degre)))::integer);
$function$;

DROP FUNCTION IF EXISTS public.militaire_degats_combat(text);


-- ---------------------------------------------------------------------
-- 6. MIROIR DECLARE DU BONUS D'ARME
-- ---------------------------------------------------------------------
-- Les valeurs sont celles DEJA presentes dans ARMES_CATALOGUE (data cote
-- client) : elles n'ont jamais ete inventees ici, elles etaient simplement
-- affichees sans etre lues. Le miroir est la source d'autorite : un objet
-- d'inventaire forge par un navigateur avec un nom inconnu vaut 0.
--
-- CLE : le `produitMilitaire` pour les deux armes de l'armee (ecrit par le
-- serveur dans militaire_retrait, donc infalsifiable), sinon le NOM de
-- l'arme civile. Les trois noms de la boutique de Port-Sainte-Marie sont
-- inclus : ce sont des habillages locaux des memes armes republiennes.
CREATE TABLE IF NOT EXISTS public.militaire_armes_bonus (
  cle   text PRIMARY KEY,
  mode  text NOT NULL CHECK (mode IN ('feu', 'cac')),
  bonus integer NOT NULL,
  note  text
);
ALTER TABLE public.militaire_armes_bonus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.militaire_armes_bonus FROM PUBLIC, anon, authenticated;

INSERT INTO public.militaire_armes_bonus (cle, mode, bonus, note) VALUES
  -- Corps a corps, catalogue civil
  ('Couteau de poche',       'cac',  5, 'republic'),
  ('Machette',               'cac',  5, 'narco'),
  ('Baïonnette',             'cac',  5, 'soviet'),
  ('Jambiya',                'cac',  6, 'khalija'),
  ('Couteau de plongée',     'cac',  5, 'republic — habillage Port-Sainte-Marie du couteau de poche'),
  -- Armes de poing, catalogue civil
  ('Revolver .38',           'feu',  8, 'republic'),
  ('Makarov',                'feu',  8, 'soviet'),
  ('Pistolet doré',          'feu',  9, 'khalija'),
  ('Desert Eagle',           'feu', 10, 'narco'),
  ('Fusil sous-marin',       'feu',  8, 'republic — habillage Port-Sainte-Marie du revolver'),
  -- Armes longues, catalogue civil
  ('Carabine de chasse',     'feu', 15, 'republic'),
  ('Kalachnikov',            'feu', 16, 'soviet'),
  ('Carabine de précision',  'feu', 17, 'khalija'),
  ('AK-47',                  'feu', 18, 'narco'),
  -- Armee : cle = produitMilitaire. Bonus aligne sur la recette civile de
  -- reference que le catalogue de production cite explicitement.
  ('arme_de_poing',          'feu',  8, 'armee — recette du revolver civil'),
  ('mitraillette',           'feu', 15, 'armee — recette de la carabine civile')
ON CONFLICT (cle) DO UPDATE
  SET mode = EXCLUDED.mode, bonus = EXCLUDED.bonus, note = EXCLUDED.note;


CREATE OR REPLACE FUNCTION public.militaire_bonus_arme(p_cle text, p_mode text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $function$
  SELECT coalesce((SELECT b.bonus FROM public.militaire_armes_bonus b
                    WHERE b.cle = p_cle AND b.mode = p_mode), 0);
$function$;

REVOKE ALL ON FUNCTION public.militaire_bonus_arme(text, text) FROM PUBLIC, anon, authenticated;


-- ######################################################################
-- MIGRATION 20260920225121  militaire_batailles_groupes
-- ######################################################################

-- =====================================================================
-- LE GROUPE DEVIENT L'UNITE DE DECISION (21 septembre 2026)
-- =====================================================================
-- Le modele camp_a / camp_b ne convient plus : une bataille peut compter
-- plus de deux pays, et le repli se decide DESORMAIS PAR GROUPE. Un groupe
-- allie peut donc decrocher pendant qu'un autre tient la position.
--
-- Le groupe est la SECTION (compagnie + section). Un PJ engage sans section
-- forme un groupe a lui seul : il commande ce qu'il commande, c'est-a-dire
-- lui-meme.

ALTER TABLE public.batailles_engagements
  ADD COLUMN IF NOT EXISTS groupe_id text;

-- Identifiant deterministe : meme compagnie + meme section = meme groupe.
UPDATE public.batailles_engagements
   SET groupe_id = coalesce(compagnie_id, 'solo') || ':' ||
                   coalesce(section_id, coalesce(personnage, matricule, id::text))
 WHERE groupe_id IS NULL;

CREATE TABLE IF NOT EXISTS public.batailles_groupes (
  bataille_id       bigint  NOT NULL,
  groupe_id         text    NOT NULL,
  camp              text    NOT NULL,
  compagnie_id      text,
  section_id        text,
  leader            text,              -- PJ qui commande, NULL = groupe mene par un PNJ
  effectif_initial  integer NOT NULL,
  -- Decision du round en cours : NULL tant que le chef n'a pas tranche.
  decision          text CHECK (decision IN ('tenir','replier')),
  -- Horodatage d'OUVERTURE de la fenetre de 90 secondes. NULL = pas de
  -- decision en attente.
  attente_depuis    timestamptz,
  repli             jsonb,
  sorti_round       integer,
  PRIMARY KEY (bataille_id, groupe_id)
);

CREATE INDEX IF NOT EXISTS batailles_groupes_bataille_idx
  ON public.batailles_groupes (bataille_id) WHERE sorti_round IS NULL;

ALTER TABLE public.batailles_groupes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.batailles_groupes FROM PUBLIC, anon, authenticated;

-- Lecture seule pour les joueurs : l'ecran de combat a besoin de savoir si
-- une decision est attendue de lui. Aucune ecriture directe : elle passe
-- par militaire_bataille_decider.
CREATE POLICY batailles_groupes_lecture ON public.batailles_groupes
  FOR SELECT TO authenticated USING (true);
GRANT SELECT ON public.batailles_groupes TO authenticated;


-- ---------------------------------------------------------------------
-- LE SEUIL DE REPLI, evalue GROUPE PAR GROUPE
-- ---------------------------------------------------------------------
-- 50 % de pertes sur l'effectif initial DU GROUPE, jamais sur celui du camp.
CREATE OR REPLACE FUNCTION public.militaire_groupe_sous_seuil(p_bataille_id bigint, p_groupe_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public' AS $function$
  SELECT (SELECT count(*) FROM public.batailles_engagements e
           WHERE e.bataille_id = p_bataille_id AND e.groupe_id = p_groupe_id
             AND e.sorti_round IS NULL) * 2
         <= coalesce((SELECT g.effectif_initial FROM public.batailles_groupes g
                       WHERE g.bataille_id = p_bataille_id AND g.groupe_id = p_groupe_id), 0);
$function$;

REVOKE ALL ON FUNCTION public.militaire_groupe_sous_seuil(bigint, text) FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.batailles_groupes IS
  'Unite de decision du combat : un groupe = une section engagee. Porte son effectif initial, son chef et sa decision de repli.';


-- ######################################################################
-- MIGRATION 20260920225218  militaire_combat_moteur_v2
-- ######################################################################

-- =====================================================================
-- MOTEUR DE COMBAT V2 — COMBATTANTS, CIBLAGE, APPLICATION (21 sept. 2026)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LES COMBATTANTS — avec leur arme reelle
-- ---------------------------------------------------------------------
-- CORRECTION DU BUG D'AUDIT : l'ancienne detection testait
-- `sousType IN ('poing','carabine')`, or militaire_retrait pose
-- `sousType = 'militaire'`. Un PJ arme d'une mitraillette de sa propre
-- caserne basculait donc en corps-a-corps. On ne teste plus le sousType :
-- l'arme est resolue par le MIROIR, avec `produitMilitaire` (ecrit par le
-- serveur, donc infalsifiable) en priorite et le nom du catalogue civil
-- sinon. Le type reel est conserve : la cle rendue distingue +8 de +15.
--
-- Un combattant qui porte plusieurs armes se bat avec la MEILLEURE. S'il a
-- une arme a feu il tire ; sinon il va au corps-a-corps, avec ou sans lame.
DROP FUNCTION IF EXISTS public.militaire_bataille_combattants(bigint, text);

CREATE FUNCTION public.militaire_bataille_combattants(p_bataille_id bigint, p_camp text)
RETURNS TABLE(eng_id bigint, est_pj boolean, nom text, compagnie_id text, section_id text,
              matricule text, pa integer, comp_tir numeric, comp_cac numeric,
              arme_feu boolean, arme_cle text, bonus_arme integer,
              def_per numeric, def_dup numeric, saute_round integer, groupe_id text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT e.id, true, e.personnage, e.compagnie_id, e.section_id, NULL::text,
         greatest(0, coalesce(pd.pa, 0)),
         coalesce((pd.competences_militaires->>'tir')::numeric, 0),
         coalesce((pd.competences_militaires->>'combat_rapproche')::numeric, 0),
         (af.cle IS NOT NULL),
         coalesce(af.cle, ac.cle),
         coalesce(af.bonus, ac.bonus, 0),
         public.assemblee_stat_base(pd.stats, 'PER'),
         public.assemblee_stat_base(pd.stats, 'DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.personnages_donnees pd ON pd.name = e.personnage
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'feu'
       ORDER BY b.bonus DESC LIMIT 1) af ON true
    LEFT JOIN LATERAL (
      SELECT b.cle, b.bonus FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(pd.inventory)='array' THEN pd.inventory ELSE '[]'::jsonb END) i
        JOIN public.militaire_armes_bonus b
          ON b.cle = coalesce(i->>'produitMilitaire', i->>'name')
       WHERE i->>'type' = 'arme' AND b.mode = 'cac'
       ORDER BY b.bonus DESC LIMIT 1) ac ON true
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.personnage IS NOT NULL AND e.sorti_round IS NULL

  UNION ALL

  SELECT e.id, false, sol->>'nom', e.compagnie_id, e.section_id, e.matricule,
         greatest(0, coalesce((sol->>'pa')::integer, 0)),
         coalesce((sol->'formation'->>'tir')::numeric, 0),
         coalesce((sol->'formation'->>'combat_rapproche')::numeric, 0),
         coalesce(sol->>'arme','corps_a_corps') IN ('arme_de_poing','mitraillette'),
         coalesce(sol->>'arme','corps_a_corps'),
         public.militaire_bonus_arme(coalesce(sol->>'arme','corps_a_corps'),
           CASE WHEN coalesce(sol->>'arme','corps_a_corps') IN ('arme_de_poing','mitraillette')
                THEN 'feu' ELSE 'cac' END),
         public.militaire_defense_pnj('PER'),
         public.militaire_defense_pnj('DUP'),
         e.saute_round, e.groupe_id
    FROM public.batailles_engagements e
    JOIN public.compagnies_militaires c ON c.id = e.compagnie_id
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s
    CROSS JOIN LATERAL jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE e.bataille_id = p_bataille_id AND e.camp = p_camp
     AND e.matricule IS NOT NULL AND e.sorti_round IS NULL
     AND s->>'id' = e.section_id AND sol->>'matricule' = e.matricule;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_combattants(bigint, text) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. LES CAMPS HOSTILES — une bataille peut en compter plus de deux
-- ---------------------------------------------------------------------
-- L'hostilite est lue PAIRE PAR PAIRE dans `guerres`. On n'en deduit jamais
-- que l'ennemi de mon ennemi est mon allie : la seule question posee est
-- « ce camp-la est-il en guerre avec le mien ? ».
CREATE OR REPLACE FUNCTION public.militaire_camps_hostiles(p_bataille_id bigint, p_camp text)
RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public' AS $function$
  SELECT coalesce(array_agg(DISTINCT e.camp), '{}')
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
     AND e.sorti_round IS NULL
     AND e.camp IS DISTINCT FROM p_camp
     AND EXISTS (SELECT 1 FROM public.guerres g
                  WHERE g.statut = 'active'
                    AND ((g.data->>'attaquant' = p_camp AND g.data->>'attaque'  = e.camp)
                      OR (g.data->>'attaque'  = p_camp AND g.data->>'attaquant' = e.camp)));
$function$;

REVOKE ALL ON FUNCTION public.militaire_camps_hostiles(bigint, text) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. LE PASSAGE D'UN CAMP
-- ---------------------------------------------------------------------
-- CIBLAGE : le pool ennemi rassemble TOUS les combattants des camps
-- hostiles presents, sans repartition imposee entre eux, et le tirage reste
-- aleatoire.
--
-- CIBLE PRIVILEGIEE — modalite technique retenue : un combattant qui engage
-- le corps-a-corps (il n'a pas d'arme a feu) entre DEUX FOIS dans l'urne des
-- tireurs ennemis, une seule fois dans celle des combattants au corps-a-corps.
-- C'est une ponderation du meme tirage aleatoire : aucune grille, aucune
-- distance, aucun ordre de charge.
--
-- SURPRISE : au premier echange du camp surprenant seulement, le degre monte
-- d'un cran. Le 1 NATUREL reste un echec critique -- le plancher
-- incompressible n'est pas annulable par la surprise.
DROP FUNCTION IF EXISTS public.militaire_bataille_actions(bigint, text, text, integer);

CREATE FUNCTION public.militaire_bataille_actions(
  p_bataille_id bigint, p_camp_att text, p_round integer, p_surprise boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_res jsonb := '[]'::jsonb;
  a record; k integer; n integer; v_hostiles text[];
  d_eng bigint[]; d_pj boolean[]; d_nom text[]; d_cie text[]; d_sec text[]; d_mat text[];
  d_camp text[]; d_per numeric[]; d_dup numeric[]; d_tir numeric[]; d_cac numeric[];
  d_feu boolean[]; u_tir integer[]; u_cac integer[]; v_urne integer[];
  v_mode text; v_taux integer; v_jet integer; v_degre text;
BEGIN
  v_hostiles := public.militaire_camps_hostiles(p_bataille_id, p_camp_att);
  IF coalesce(array_length(v_hostiles, 1), 0) = 0 THEN RETURN v_res; END IF;

  SELECT array_agg(c.eng_id ORDER BY c.eng_id), array_agg(c.est_pj ORDER BY c.eng_id),
         array_agg(c.nom ORDER BY c.eng_id), array_agg(c.compagnie_id ORDER BY c.eng_id),
         array_agg(c.section_id ORDER BY c.eng_id), array_agg(c.matricule ORDER BY c.eng_id),
         array_agg(c.camp ORDER BY c.eng_id), array_agg(c.def_per ORDER BY c.eng_id),
         array_agg(c.def_dup ORDER BY c.eng_id), array_agg(c.comp_tir ORDER BY c.eng_id),
         array_agg(c.comp_cac ORDER BY c.eng_id), array_agg(c.arme_feu ORDER BY c.eng_id)
    INTO d_eng, d_pj, d_nom, d_cie, d_sec, d_mat, d_camp, d_per, d_dup, d_tir, d_cac, d_feu
    FROM (SELECT x.*, h.camp
            FROM unnest(v_hostiles) AS h(camp)
            CROSS JOIN LATERAL public.militaire_bataille_combattants(p_bataille_id, h.camp) x) c;
  n := coalesce(array_length(d_eng, 1), 0);
  IF n = 0 THEN RETURN v_res; END IF;

  -- Urne de base : un jeton par ennemi.
  SELECT coalesce(array_agg(i ORDER BY i), '{}') INTO u_cac FROM generate_series(1, n) AS g(i);
  -- Urne des tireurs : un second jeton pour chaque ennemi au corps-a-corps.
  SELECT u_cac || coalesce(array_agg(i ORDER BY i), '{}') INTO u_tir
    FROM generate_series(1, n) AS g(i) WHERE NOT coalesce(d_feu[g.i], false);

  FOR a IN
    SELECT * FROM public.militaire_bataille_combattants(p_bataille_id, p_camp_att)
     WHERE saute_round IS DISTINCT FROM p_round
  LOOP
    v_mode := CASE WHEN a.arme_feu THEN 'feu' ELSE 'cac' END;
    v_urne := CASE WHEN a.arme_feu THEN u_tir ELSE u_cac END;
    k := v_urne[1 + floor(random() * array_length(v_urne, 1))::integer];

    -- La competence qui DEFEND est celle du meme domaine que l'attaque subie.
    v_taux := public.militaire_taux_combat(
      CASE WHEN a.arme_feu THEN a.comp_tir ELSE a.comp_cac END,
      CASE WHEN a.arme_feu THEN d_tir[k]   ELSE d_cac[k]   END,
      CASE WHEN a.arme_feu THEN d_per[k]   ELSE d_dup[k]   END,
      a.bonus_arme);
    v_jet   := floor(random() * 100)::integer + 1;
    v_degre := public.militaire_degre_combat(v_taux, v_jet);

    IF coalesce(p_surprise, false) AND v_jet <> 1 THEN
      v_degre := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) + 1);
    END IF;

    v_res := v_res || jsonb_build_array(jsonb_build_object(
      'camp_attaquant', p_camp_att,
      'att_eng', a.eng_id, 'att_pj', a.est_pj, 'att_nom', a.nom, 'att_mat', a.matricule,
      'att_arme', a.arme_cle, 'att_bonus', a.bonus_arme, 'att_groupe', a.groupe_id,
      'cib_eng', d_eng[k], 'cib_pj', d_pj[k], 'cib_nom', d_nom[k], 'cib_mat', d_mat[k],
      'cib_cie', d_cie[k], 'cib_sec', d_sec[k], 'cib_camp', d_camp[k],
      'mode', v_mode, 'taux', v_taux, 'jet', v_jet, 'degre', v_degre,
      'surprise', coalesce(p_surprise, false)));
  END LOOP;
  RETURN v_res;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_actions(bigint, text, integer, boolean) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. APPLICATION — pertes proportionnelles et gilet
-- ---------------------------------------------------------------------
-- Les PA restants sont arrondis a l'entier INFERIEUR.
--
-- GILET : feu uniquement, jamais corps-a-corps, et SEULEMENT si le tir
-- devait faire tomber la cible a 0 PA. Un gilet intact donne 50 % de
-- protection ; en cas de succes le degre est ABAISSE D'UN CRAN et la cible
-- conserve au minimum 1 PA. En cas d'echec, le resultat initial s'applique
-- et le gilet reste intact.
CREATE OR REPLACE FUNCTION public.militaire_bataille_appliquer(
  p_bataille_id bigint, p_actions jsonb, p_round integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  act jsonb; v_pa integer; v_new integer; v_gilet jsonb; v_degre text; v_abaisse text;
BEGIN
  FOR act IN SELECT value FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb))
  LOOP
    v_degre := act->>'degre';

    IF v_degre = 'echec_critique' THEN
      UPDATE public.batailles_engagements SET saute_round = p_round + 1
       WHERE id = (act->>'att_eng')::bigint AND sorti_round IS NULL;
      CONTINUE;
    END IF;
    CONTINUE WHEN public.militaire_degats_pct(v_degre) = 0;

    CONTINUE WHEN NOT EXISTS (SELECT 1 FROM public.batailles_engagements
                               WHERE id = (act->>'cib_eng')::bigint AND sorti_round IS NULL);

    SELECT pa INTO v_pa FROM public.militaire_bataille_combattants(
      p_bataille_id, act->>'cib_camp') WHERE eng_id = (act->>'cib_eng')::bigint;
    CONTINUE WHEN v_pa IS NULL;

    v_new := public.militaire_pa_restants(v_pa, v_degre);

    IF v_new = 0 AND act->>'mode' = 'feu' THEN
      v_gilet := public.militaire_gilet_absorber(
        (act->>'cib_pj')::boolean, act->>'cib_nom',
        act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      IF coalesce((v_gilet->>'protege')::boolean, false) THEN
        v_abaisse := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) - 1);
        v_new := greatest(1, public.militaire_pa_restants(v_pa, v_abaisse));
      END IF;
    END IF;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';
    ELSE
      PERFORM public.militaire_soldat_pa_fixer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat', v_new);
    END IF;

    CONTINUE WHEN v_new > 0;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees
         SET current_city = 'caserne', current_building = 'caserne-militaire',
             current_room = 'infirmerie'
       WHERE name = act->>'cib_nom';
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'neutralise'
       WHERE id = (act->>'cib_eng')::bigint;
    ELSE
      PERFORM public.militaire_soldat_supprimer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'mort'
       WHERE id = (act->>'cib_eng')::bigint;
    END IF;
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_appliquer(bigint, jsonb, integer) FROM PUBLIC, anon, authenticated;


-- ######################################################################
-- MIGRATION 20260920225330  militaire_combat_round_et_repli_par_groupe
-- ######################################################################

-- =====================================================================
-- BOUCLE DE ROUND ET REPLI PAR GROUPE (21 septembre 2026)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ENGAGEMENT — tous les camps hostiles presents, plus de LIMIT 1
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(
  p_bataille_id bigint, p_camp text, p_ville text, p_bat text, p_piece text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  INSERT INTO public.batailles_engagements
    (bataille_id, camp, personnage, compagnie_id, section_id, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, pd.name, sm.compagnie_id, sm.section_id, sm.grade, pd.pa,
         coalesce(sm.compagnie_id, 'solo') || ':' || coalesce(sm.section_id, pd.name)
    FROM public.personnages_donnees pd
    JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
   WHERE pd.country = p_camp AND pd.current_city = p_ville
     AND pd.current_building = p_bat AND pd.current_room = p_piece
     AND coalesce(pd.pa, 0) > 0
  ON CONFLICT DO NOTHING;

  INSERT INTO public.batailles_engagements
    (bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, c.id, s->>'id', sol->>'matricule', 'soldat',
         (sol->>'pa')::integer, c.id || ':' || (s->>'id')
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE c.data->>'pays' = p_camp
     AND NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND ((sol->>'ville' = p_ville AND sol->>'buildingId' = p_bat AND sol->>'roomId' = p_piece
           AND (sol->>'leaderCourant') IS NULL)
       OR EXISTS (SELECT 1 FROM public.personnages_donnees chef
                   WHERE chef.name = sol->>'leaderCourant' AND chef.current_city = p_ville
                     AND chef.current_building = p_bat AND chef.current_room = p_piece))
  ON CONFLICT DO NOTHING;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_recruter(bigint, text, text, text, text) FROM PUBLIC, anon, authenticated;


-- Constitue les groupes a partir des engages : effectif initial, chef PJ
-- eventuel, position de repli.
CREATE OR REPLACE FUNCTION public.militaire_bataille_groupes_constituer(p_bataille_id bigint)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_n integer;
BEGIN
  INSERT INTO public.batailles_groupes
    (bataille_id, groupe_id, camp, compagnie_id, section_id, leader, effectif_initial, repli)
  SELECT e.bataille_id, e.groupe_id, min(e.camp), min(e.compagnie_id), min(e.section_id),
         -- Le chef est le PJ du groupe le plus grade present ; NULL si le
         -- groupe n'est mene que par des PNJ.
         (SELECT p.personnage FROM public.batailles_engagements p
           WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
             AND p.personnage IS NOT NULL
           ORDER BY CASE p.grade WHEN 'commandant' THEN 1 WHEN 'capitaine' THEN 2
                                 WHEN 'lieutenant' THEN 3 ELSE 4 END, p.id LIMIT 1),
         count(*),
         (SELECT public.militaire_position_repli(p.personnage, b.ville, b.batiment, b.piece)
            FROM public.batailles_engagements p
            JOIN public.batailles b ON b.id = p.bataille_id
           WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
             AND p.personnage IS NOT NULL LIMIT 1)
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
   GROUP BY e.bataille_id, e.groupe_id
  ON CONFLICT (bataille_id, groupe_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_groupes_constituer(bigint) FROM PUBLIC, anon, authenticated;


CREATE OR REPLACE FUNCTION public.militaire_bataille_engager()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_moi text; a record; v_id bigint; v_contact bigint; v_init text;
  v_camps text[]; v_camp text; v_na integer; v_total integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room, pa INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.services_militaires
                  WHERE personnage = v_moi AND fin_ts IS NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_militaire');
  END IF;
  IF EXISTS (SELECT 1 FROM public.batailles WHERE statut = 'en_cours'
              AND pays = a.country AND ville = a.current_city
              AND batiment = a.current_building AND piece = a.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_deja_en_cours');
  END IF;

  -- TOUS les pays en guerre avec le mien ayant des soldats reellement poses
  -- ici. Plus de LIMIT 1 : une bataille peut opposer plus de deux forces.
  SELECT coalesce(array_agg(DISTINCT c.data->>'pays'), '{}') INTO v_camps
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE c.data->>'pays' IS DISTINCT FROM a.country
     AND sol->>'ville' = a.current_city AND sol->>'buildingId' = a.current_building
     AND sol->>'roomId' = a.current_room AND (sol->>'leaderCourant') IS NULL
     AND EXISTS (SELECT 1 FROM public.guerres g WHERE g.statut = 'active'
                  AND ((g.data->>'attaquant' = a.country AND g.data->>'attaque' = c.data->>'pays')
                    OR (g.data->>'attaque'  = a.country AND g.data->>'attaquant' = c.data->>'pays')));
  IF coalesce(array_length(v_camps, 1), 0) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_ennemi_ici');
  END IF;

  SELECT id INTO v_contact FROM public.contacts_militaires
   WHERE consomme_le IS NULL AND ville = a.current_city AND batiment = a.current_building
     AND ((pays_a = a.country AND pays_b = ANY(v_camps)) OR (pays_a = ANY(v_camps) AND pays_b = a.country))
   ORDER BY etabli_le DESC LIMIT 1;
  v_init := CASE WHEN v_contact IS NOT NULL THEN 'simultane' ELSE 'a' END;

  INSERT INTO public.batailles (pays, ville, batiment, piece, camp_a, camp_b, initiative,
                                leader_a, contact_id, statut, round_courant)
  VALUES (a.country, a.current_city, a.current_building, a.current_room, a.country, v_camps[1],
          v_init, v_moi, v_contact, 'en_cours', 0)
  RETURNING id INTO v_id;

  PERFORM public.militaire_bataille_recruter(v_id, a.country, a.current_city, a.current_building, a.current_room);
  FOREACH v_camp IN ARRAY v_camps LOOP
    PERFORM public.militaire_bataille_recruter(v_id, v_camp, a.current_city, a.current_building, a.current_room);
  END LOOP;

  SELECT count(*) INTO v_na    FROM public.militaire_bataille_combattants(v_id, a.country);
  SELECT count(*) INTO v_total FROM public.batailles_engagements
   WHERE bataille_id = v_id AND camp <> a.country AND sorti_round IS NULL;
  IF v_na = 0 OR v_total = 0 THEN
    DELETE FROM public.batailles_engagements WHERE bataille_id = v_id;
    DELETE FROM public.batailles WHERE id = v_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant',
      'mon_camp', v_na, 'adverse', v_total);
  END IF;

  PERFORM public.militaire_bataille_groupes_constituer(v_id);
  UPDATE public.batailles SET effectif_initial_a = v_na, effectif_initial_b = v_total,
         repli_a = public.militaire_position_repli(v_moi, a.current_city, a.current_building, a.current_room)
   WHERE id = v_id;

  IF v_contact IS NOT NULL THEN
    UPDATE public.contacts_militaires SET consomme_le = now(), bataille_id = v_id WHERE id = v_contact;
  END IF;

  RETURN jsonb_build_object('ok', true, 'bataille_id', v_id, 'initiative', v_init,
    'mon_camp', a.country, 'camps_adverses', v_camps, 'mon_effectif', v_na,
    'effectif_adverse', v_total,
    'groupes', (SELECT count(*) FROM public.batailles_groupes WHERE bataille_id = v_id));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_engager() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_engager() TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- 2. REPLI D'UN GROUPE — et de lui seul
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.militaire_bataille_decrocher(bigint, text, jsonb, integer);

CREATE FUNCTION public.militaire_bataille_decrocher_groupe(
  p_bataille_id bigint, p_groupe_id text, p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE r record; v_repli jsonb; v_data jsonb; v_sec jsonb; v_sols jsonb; v_n integer := 0;
BEGIN
  SELECT g.repli INTO v_repli FROM public.batailles_groupes g
   WHERE g.bataille_id = p_bataille_id AND g.groupe_id = p_groupe_id;
  IF v_repli IS NULL THEN RETURN 0; END IF;   -- sans position de repli, on tient

  FOR r IN SELECT e.* FROM public.batailles_engagements e
            WHERE e.bataille_id = p_bataille_id AND e.groupe_id = p_groupe_id
              AND e.sorti_round IS NULL
  LOOP
    IF r.personnage IS NOT NULL THEN
      UPDATE public.personnages_donnees
         SET current_city = v_repli->>'ville', current_building = v_repli->>'batiment',
             current_room = v_repli->>'piece'
       WHERE name = r.personnage;
    ELSE
      SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = r.compagnie_id FOR UPDATE;
      SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
       WHERE s->>'id' = r.section_id;
      CONTINUE WHEN v_sec IS NULL;
      SELECT coalesce(jsonb_agg(
               CASE WHEN sol->>'matricule' = r.matricule AND (sol->>'leaderCourant') IS NULL
                    THEN sol || jsonb_build_object('ville', v_repli->>'ville',
                                 'buildingId', v_repli->>'batiment', 'roomId', v_repli->>'piece')
                    ELSE sol END ORDER BY pos), '[]'::jsonb)
        INTO v_sols FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
          WITH ORDINALITY AS t(sol, pos);
      UPDATE public.compagnies_militaires
         SET data = public.militaire_sections_remplacer(v_data, r.section_id,
                      v_sec || jsonb_build_object('soldats', v_sols))
       WHERE id = r.compagnie_id;
    END IF;
    UPDATE public.batailles_engagements
       SET sorti_round = p_round, etat_final = 'replie' WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;

  UPDATE public.batailles_groupes
     SET sorti_round = p_round, attente_depuis = NULL
   WHERE bataille_id = p_bataille_id AND groupe_id = p_groupe_id;
  RETURN v_n;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_decrocher_groupe(bigint, text, integer) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. ARBITRAGE DES GROUPES — seuil, fenetre de 90 s, repli automatique
-- ---------------------------------------------------------------------
-- Rend le nombre de groupes ENCORE EN ATTENTE d'une decision humaine.
-- Tant qu'il en reste un, le round suivant ne part pas : c'est ainsi que la
-- fenetre de decision ne se paie pas en morts.
CREATE OR REPLACE FUNCTION public.militaire_bataille_arbitrer_groupes(
  p_bataille_id bigint, p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE g record; v_attente integer := 0;
BEGIN
  FOR g IN SELECT * FROM public.batailles_groupes
            WHERE bataille_id = p_bataille_id AND sorti_round IS NULL
  LOOP
    -- Un groupe qui a deja tranche « replier » decroche.
    IF g.decision = 'replier' THEN
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
      CONTINUE;
    END IF;
    -- Un groupe qui a deja tranche « tenir » continue : rien a faire.
    IF g.decision = 'tenir' THEN CONTINUE; END IF;

    IF NOT public.militaire_groupe_sous_seuil(p_bataille_id, g.groupe_id) THEN
      CONTINUE;                                  -- pas encore a 50 % de pertes
    END IF;

    IF g.leader IS NULL THEN
      -- Groupe mene par un PNJ : repli automatique, sans attente.
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
      CONTINUE;
    END IF;

    IF g.attente_depuis IS NULL THEN
      -- Ouverture de la fenetre de 90 secondes pour le chef PJ.
      UPDATE public.batailles_groupes SET attente_depuis = now()
       WHERE bataille_id = p_bataille_id AND groupe_id = g.groupe_id;
      v_attente := v_attente + 1;
    ELSIF now() - g.attente_depuis >= interval '90 seconds' THEN
      -- Delai ecoule sans reponse : repli automatique du groupe.
      PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, p_round);
    ELSE
      v_attente := v_attente + 1;                -- la fenetre court encore
    END IF;
  END LOOP;
  RETURN v_attente;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_arbitrer_groupes(bigint, integer) FROM PUBLIC, anon, authenticated;


-- ######################################################################
-- MIGRATION 20260920225508  militaire_combat_boucle_v2
-- ######################################################################

-- =====================================================================
-- BOUCLE DE COMBAT V2 (21 septembre 2026)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. APPLICATION — rend desormais les actions ENRICHIES
-- ---------------------------------------------------------------------
-- Les degats etant proportionnels, la perte reelle n'est connue qu'au
-- moment de l'application. On la renvoie pour que le rapport de round
-- puisse la chiffrer sans la recalculer.
DROP FUNCTION IF EXISTS public.militaire_bataille_appliquer(bigint, jsonb, integer);

CREATE FUNCTION public.militaire_bataille_appliquer(
  p_bataille_id bigint, p_actions jsonb, p_round integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  act jsonb; v_pa integer; v_new integer; v_gilet jsonb; v_degre text; v_abaisse text;
  v_out jsonb := '[]'::jsonb; v_protege boolean;
BEGIN
  FOR act IN SELECT value FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb))
  LOOP
    v_degre := act->>'degre'; v_protege := false;

    IF v_degre = 'echec_critique' THEN
      UPDATE public.batailles_engagements SET saute_round = p_round + 1
       WHERE id = (act->>'att_eng')::bigint AND sorti_round IS NULL;
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0, 'saute_suivant', true));
      CONTINUE;
    END IF;

    IF public.militaire_degats_pct(v_degre) = 0
       OR NOT EXISTS (SELECT 1 FROM public.batailles_engagements
                       WHERE id = (act->>'cib_eng')::bigint AND sorti_round IS NULL) THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    SELECT pa INTO v_pa FROM public.militaire_bataille_combattants(
      p_bataille_id, act->>'cib_camp') WHERE eng_id = (act->>'cib_eng')::bigint;
    IF v_pa IS NULL THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    v_new := public.militaire_pa_restants(v_pa, v_degre);

    -- GILET : feu seulement, et seulement si le tir devait neutraliser.
    IF v_new = 0 AND act->>'mode' = 'feu' THEN
      v_gilet := public.militaire_gilet_absorber(
        (act->>'cib_pj')::boolean, act->>'cib_nom',
        act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      IF coalesce((v_gilet->>'protege')::boolean, false) THEN
        v_protege := true;
        v_abaisse := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) - 1);
        v_new := greatest(1, public.militaire_pa_restants(v_pa, v_abaisse));
      END IF;
    END IF;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';
    ELSE
      PERFORM public.militaire_soldat_pa_fixer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat', v_new);
    END IF;

    v_out := v_out || jsonb_build_array(act || jsonb_build_object(
      'pa_avant', v_pa, 'pa_apres', v_new, 'perte', v_pa - v_new,
      'gilet', v_protege, 'degre_applique', coalesce(v_abaisse, v_degre)));

    CONTINUE WHEN v_new > 0;

    IF (act->>'cib_pj')::boolean THEN
      -- PJ : NEUTRALISE, jamais mort. Infirmerie de SA propre caserne.
      UPDATE public.personnages_donnees
         SET current_city = 'caserne', current_building = 'caserne-militaire',
             current_room = 'infirmerie'
       WHERE name = act->>'cib_nom';
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'neutralise'
       WHERE id = (act->>'cib_eng')::bigint;
    ELSE
      -- PNJ : MORT. Suppression reelle : le contingent diminue definitivement.
      PERFORM public.militaire_soldat_supprimer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'mort'
       WHERE id = (act->>'cib_eng')::bigint;
    END IF;
  END LOOP;
  RETURN v_out;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_appliquer(bigint, jsonb, integer) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. RAPPORT — la perte reelle remonte de l'application
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_rapport(
  p_bataille_id bigint, p_camp text, p_camp_adverse text, p_round integer,
  p_actions jsonb, p_reste_moi integer, p_reste_adverse integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  b record; v_pa_perdus integer; v_touches integer; v_morts integer; v_neutralises integer;
  v_tombes_adverse integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id;

  SELECT coalesce(sum(coalesce((a->>'perte')::integer, 0)), 0),
         count(*) FILTER (WHERE coalesce((a->>'perte')::integer, 0) > 0)
    INTO v_pa_perdus, v_touches
    FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb)) a
   WHERE a->>'cib_camp' = p_camp;

  SELECT count(*) FILTER (WHERE etat_final = 'mort'),
         count(*) FILTER (WHERE etat_final = 'neutralise')
    INTO v_morts, v_neutralises
    FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp = p_camp AND sorti_round = p_round;

  SELECT count(*) INTO v_tombes_adverse FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND camp <> p_camp AND sorti_round = p_round;

  RETURN jsonb_build_object(
    'round', p_round,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', p_camp,
    'mes_combattants_restants', p_reste_moi,
    'mes_pa_perdus', v_pa_perdus,
    'mes_combattants_touches', v_touches,
    'mes_morts_pnj', v_morts,
    'mes_pj_neutralises', v_neutralises,
    'adversaires_tombes', v_tombes_adverse,
    'adversaire_estime', CASE WHEN p_reste_adverse > 0
      THEN public.militaire_degrader('proche', p_reste_adverse, p_camp_adverse, b.ville, b.batiment)
      ELSE jsonb_build_object('libelle', 'plus aucun adversaire debout') END,
    'termine', (p_reste_moi = 0 OR p_reste_adverse = 0));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_rapport(bigint, text, text, integer, jsonb, integer, integer) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 3. LE ROUND
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_round(p_bataille_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  b record; v_round integer; v_camps text[]; v_camp text; v_surprise text;
  v_actions jsonb := '[]'::jsonb; v_autres jsonb := '[]'::jsonb;
  v_reste integer; v_debout integer; v_issue text; v_attente integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  v_round := b.round_courant + 1;
  IF v_round > 200 THEN
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           termine_raison = 'borne_technique_atteinte', issue = NULL WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'borne_technique_atteinte', 'round', v_round);
  END IF;

  SELECT coalesce(array_agg(DISTINCT camp), '{}') INTO v_camps
    FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;

  -- SURPRISE : premier round, et seulement si l'engageant avait l'initiative.
  v_surprise := CASE WHEN v_round = 1 AND b.initiative = 'a' THEN b.camp_a ELSE NULL END;

  IF v_surprise IS NOT NULL THEN
    -- La passe du camp surprenant est calculee ET appliquee avant que les
    -- autres ne soient photographies : c'est cela, l'initiative.
    v_actions := public.militaire_bataille_actions(p_bataille_id, v_surprise, v_round, true);
    v_actions := public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
    FOREACH v_camp IN ARRAY v_camps LOOP
      CONTINUE WHEN v_camp = v_surprise;
      v_autres := v_autres || public.militaire_bataille_actions(p_bataille_id, v_camp, v_round, false);
    END LOOP;
    v_autres  := public.militaire_bataille_appliquer(p_bataille_id, v_autres, v_round);
    v_actions := v_actions || v_autres;
  ELSE
    -- Hors surprise, toutes les passes sont calculees AVANT toute
    -- application : c'est cela, la simultaneite.
    FOREACH v_camp IN ARRAY v_camps LOOP
      v_actions := v_actions || public.militaire_bataille_actions(p_bataille_id, v_camp, v_round, false);
    END LOOP;
    v_actions := public.militaire_bataille_appliquer(p_bataille_id, v_actions, v_round);
  END IF;

  -- Un rapport par camp encore present.
  FOREACH v_camp IN ARRAY v_camps LOOP
    SELECT count(*) INTO v_reste FROM public.batailles_engagements
     WHERE bataille_id = p_bataille_id AND camp = v_camp AND sorti_round IS NULL;
    INSERT INTO public.batailles_rounds (bataille_id, numero, camp, rapport)
    VALUES (p_bataille_id, v_round, v_camp,
            public.militaire_bataille_rapport(p_bataille_id, v_camp,
              coalesce((public.militaire_camps_hostiles(p_bataille_id, v_camp))[1], v_camp),
              v_round, v_actions, v_reste,
              (SELECT count(*)::integer FROM public.batailles_engagements
                WHERE bataille_id = p_bataille_id AND camp <> v_camp AND sorti_round IS NULL)))
    ON CONFLICT (bataille_id, numero, camp) DO NOTHING;
  END LOOP;

  UPDATE public.batailles SET round_courant = v_round WHERE id = p_bataille_id;

  -- Seuil de 50 %, fenetre de 90 s, replis automatiques.
  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, v_round);

  -- Fin : il ne reste qu'un camp debout, ou aucun.
  SELECT count(DISTINCT camp) INTO v_debout FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;
  IF v_debout <= 1 THEN
    SELECT CASE WHEN v_debout = 0 THEN 'aneantissement_mutuel'
                ELSE 'victoire_' || (SELECT DISTINCT camp FROM public.batailles_engagements
                                      WHERE bataille_id = p_bataille_id AND sorti_round IS NULL) END
      INTO v_issue;
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(), issue = v_issue,
           termine_raison = 'camp_hors_combat' WHERE id = p_bataille_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'round', v_round, 'surprise', v_surprise,
    'camps', v_camps, 'camps_debout', v_debout, 'groupes_en_attente', v_attente,
    'issue', v_issue, 'terminee', (v_debout <= 1));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_round(bigint) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. AVANCER — jamais pendant qu'un chef reflechit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_avancer(p_bataille_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE b record; v_attente integer; v_debout integer;
BEGIN
  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  -- Les fenetres echues se resolvent ici : un chef qui n'a pas repondu dans
  -- les 90 secondes voit son groupe decrocher.
  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, b.round_courant);

  SELECT count(DISTINCT camp) INTO v_debout FROM public.batailles_engagements
   WHERE bataille_id = p_bataille_id AND sorti_round IS NULL;
  IF v_debout <= 1 THEN
    UPDATE public.batailles SET statut = 'terminee', fin_ts = now(),
           termine_raison = 'camp_hors_combat',
           issue = CASE WHEN v_debout = 0 THEN 'aneantissement_mutuel'
                        ELSE 'victoire_' || (SELECT DISTINCT camp FROM public.batailles_engagements
                                              WHERE bataille_id = p_bataille_id AND sorti_round IS NULL) END
     WHERE id = p_bataille_id;
    RETURN jsonb_build_object('ok', true, 'terminee', true, 'camps_debout', v_debout);
  END IF;

  IF v_attente > 0 THEN
    -- AUCUN ROUND NE PART tant qu'un chef a la main : la fenetre de decision
    -- ne se paie pas en morts.
    RETURN jsonb_build_object('ok', true, 'en_attente', v_attente,
      'raison', 'decision_en_attente', 'round', b.round_courant);
  END IF;

  RETURN public.militaire_bataille_round(p_bataille_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_avancer(bigint) FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 5. DECIDER — le chef tranche pour SON groupe, et pour lui seul
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_decider(p_bataille_id bigint, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_moi text; b record; g record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_decision NOT IN ('tenir','replier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = p_bataille_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;
  IF b.statut <> 'en_cours' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_terminee', 'issue', b.issue);
  END IF;

  SELECT * INTO g FROM public.batailles_groupes
   WHERE bataille_id = p_bataille_id AND leader = v_moi AND sorti_round IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_chef_de_groupe');
  END IF;

  UPDATE public.batailles_groupes
     SET decision = p_decision, attente_depuis = NULL
   WHERE bataille_id = p_bataille_id AND groupe_id = g.groupe_id;

  IF p_decision = 'replier' THEN
    PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id, g.groupe_id, b.round_courant);
  END IF;

  RETURN public.militaire_bataille_avancer(p_bataille_id)
         || jsonb_build_object('mon_groupe', g.groupe_id, 'ma_decision', p_decision);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_decider(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_decider(bigint, text) TO authenticated, service_role;


-- La doctrine de camp n'existe plus : le seuil de 50 % s'applique groupe par
-- groupe, avec fenetre de 90 s pour un chef PJ et repli automatique pour un
-- groupe mene par un PNJ. La fonction est conservee le temps que le client
-- retire son bouton, et refuse proprement.
CREATE OR REPLACE FUNCTION public.militaire_bataille_doctrine(p_bataille_id bigint, p_doctrine text)
RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT jsonb_build_object('ok', false, 'raison', 'doctrine_obsolete',
    'detail', 'Le repli se decide desormais groupe par groupe, a 50 % de pertes.');
$function$;


-- ######################################################################
-- MIGRATION 20260920225758  militaire_repli_defaut_groupe_pnj
-- ######################################################################

-- Un groupe mene par des PNJ n'avait aucune position de repli : la position
-- etait derivee d'un PJ du groupe, et il n'y en a pas. Consequence mesuree au
-- banc : le groupe combattait jusqu'au dernier homme, alors que l'arbitrage
-- prevoit son repli automatique a 50 % de pertes.
--
-- Le repli par defaut est la CASERNE de l'empire du groupe : c'est la
-- position canonique ou militaire_compagnie_creer pose deja tout contingent
-- neuf ('caserne' / 'caserne-militaire' / 'corps_garde'). Aucune position
-- nouvelle n'est inventee.
CREATE OR REPLACE FUNCTION public.militaire_bataille_groupes_constituer(p_bataille_id bigint)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_n integer;
BEGIN
  INSERT INTO public.batailles_groupes
    (bataille_id, groupe_id, camp, compagnie_id, section_id, leader, effectif_initial, repli)
  SELECT e.bataille_id, e.groupe_id, min(e.camp), min(e.compagnie_id), min(e.section_id),
         (SELECT p.personnage FROM public.batailles_engagements p
           WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
             AND p.personnage IS NOT NULL
           ORDER BY CASE p.grade WHEN 'commandant' THEN 1 WHEN 'capitaine' THEN 2
                                 WHEN 'lieutenant' THEN 3 ELSE 4 END, p.id LIMIT 1),
         count(*),
         coalesce(
           (SELECT public.militaire_position_repli(p.personnage, b.ville, b.batiment, b.piece)
              FROM public.batailles_engagements p
              JOIN public.batailles b ON b.id = p.bataille_id
             WHERE p.bataille_id = e.bataille_id AND p.groupe_id = e.groupe_id
               AND p.personnage IS NOT NULL LIMIT 1),
           jsonb_build_object('ville', 'caserne', 'batiment', 'caserne-militaire',
                              'piece', 'corps_garde'))
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
   GROUP BY e.bataille_id, e.groupe_id
  ON CONFLICT (bataille_id, groupe_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_groupes_constituer(bigint) FROM PUBLIC, anon, authenticated;


-- ######################################################################
-- MIGRATION 20260920230054  militaire_bataille_etat_par_groupe
-- ######################################################################

-- L'ecran de combat doit savoir si une decision est attendue de CE joueur,
-- pour SON groupe, et combien de secondes il lui reste. La doctrine de camp
-- disparait de la reponse : elle n'existe plus.
CREATE OR REPLACE FUNCTION public.militaire_bataille_etat(p_bataille_id bigint DEFAULT NULL::bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_moi text; v_id bigint; b record; g record; v_camp text; v_reste integer;
  v_rounds jsonb; v_hostiles text[]; v_secondes integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  IF p_bataille_id IS NULL THEN
    SELECT e.bataille_id INTO v_id FROM public.batailles_engagements e
      JOIN public.batailles bb ON bb.id = e.bataille_id
     WHERE e.personnage = v_moi AND bb.statut = 'en_cours'
     ORDER BY bb.debut_ts DESC LIMIT 1;
    IF v_id IS NULL THEN RETURN jsonb_build_object('ok', true, 'bataille', NULL); END IF;
  ELSE
    v_id := p_bataille_id;
  END IF;

  SELECT * INTO b FROM public.batailles WHERE id = v_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'bataille_introuvable'); END IF;

  v_camp := public.militaire_bataille_mon_camp(v_id, v_moi);
  IF v_camp IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_engage'); END IF;

  -- Mon groupe : celui ou je suis engage.
  SELECT gg.* INTO g FROM public.batailles_groupes gg
    JOIN public.batailles_engagements e
      ON e.bataille_id = gg.bataille_id AND e.groupe_id = gg.groupe_id
   WHERE gg.bataille_id = v_id AND e.personnage = v_moi LIMIT 1;

  v_hostiles := public.militaire_camps_hostiles(v_id, v_camp);
  SELECT count(*) INTO v_reste FROM public.militaire_bataille_combattants(v_id, v_camp);
  SELECT coalesce(jsonb_agg(r.rapport ORDER BY r.numero), '[]'::jsonb) INTO v_rounds
    FROM public.batailles_rounds r WHERE r.bataille_id = v_id AND r.camp = v_camp;

  v_secondes := CASE WHEN g.attente_depuis IS NULL THEN NULL
    ELSE greatest(0, 90 - extract(epoch FROM now() - g.attente_depuis))::integer END;

  RETURN jsonb_build_object('ok', true, 'bataille', jsonb_build_object(
    'id', b.id, 'statut', b.statut, 'round_courant', b.round_courant,
    'lieu', jsonb_build_object('ville', b.ville, 'batiment', b.batiment, 'piece', b.piece),
    'mon_camp', v_camp, 'camps_adverses', v_hostiles,
    'camp_adverse', coalesce(v_hostiles[1], '—'),
    'mon_effectif_actuel', v_reste,
    -- Mon groupe, unite de decision
    'mon_groupe', g.groupe_id,
    'mon_groupe_effectif_initial', g.effectif_initial,
    'mon_groupe_restants', (SELECT count(*) FROM public.batailles_engagements e2
                             WHERE e2.bataille_id = v_id AND e2.groupe_id = g.groupe_id
                               AND e2.sorti_round IS NULL),
    'mon_effectif_initial', g.effectif_initial,
    'je_suis_leader', (g.leader IS NOT NULL AND g.leader = v_moi),
    'mon_chef', g.leader,
    'decision_attendue', (g.attente_depuis IS NOT NULL AND g.decision IS NULL),
    'secondes_restantes', v_secondes,
    'ma_decision', g.decision,
    'mon_groupe_replie', (g.sorti_round IS NOT NULL),
    'issue', b.issue, 'rounds', v_rounds));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_etat(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_etat(bigint) TO authenticated, service_role;


-- ######################################################################
-- MIGRATION 20260920230517  militaire_revoquer_anon_primitives_v2
-- ######################################################################

-- Les DEFAULT PRIVILEGES du schema public reaccordent EXECUTE a anon sur
-- toute fonction creee. Ces cinq-la sont PURES (IMMUTABLE, aucun acces aux
-- tables) et donc inoffensives, mais la doctrine du projet est de ne jamais
-- laisser un droit non voulu : on ferme explicitement.
REVOKE ALL ON FUNCTION public.militaire_degats_pct(text)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_degre_rang(text)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_degre_par_rang(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_pa_restants(integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_sections_remplacer(jsonb, text, jsonb) FROM PUBLIC, anon;
