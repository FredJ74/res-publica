-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920224857
-- Nom original      : militaire_combat_primitives_v2
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 22:48:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 76196d0a71d2107963b5dec9175b1a4a
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
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