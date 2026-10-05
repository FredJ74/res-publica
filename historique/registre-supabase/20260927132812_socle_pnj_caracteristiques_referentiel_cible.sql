-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927132812
-- Nom original      : socle_pnj_caracteristiques_referentiel_cible
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 13:28:12 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2386a6f0d31638fef8240524827765f5
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
-- LOT 1 — LE CONTENANT GENERIQUE DES SIX CARACTERISTIQUES (27 septembre 2026)
--
-- PORTEE STRICTE. Ce lot ne formalise QUE le contenant. Il ne renseigne aucune valeur, ne touche
-- a aucun metier, n'introduit AUCUNE notion d'effet ni d'objet -- ceux-ci appartiennent au lot 10
-- et ne doivent creer aucune dependance ici. Les primitives ci-dessous lisent la VALEUR DE BASE,
-- et rien d'autre.
--
-- CE QUI ETAIT FAUX. Le socle portait `car_for` (Force) et n'avait pas `car_ent` (Entregent). Or
-- les six caracteristiques du jeu sont INT, CHA, VOL, PER, DUP, ENT : `FOR` n'existe chez aucun
-- personnage joueur -- il ne vient que d'une table de PNJ heritee. Le socle decrivait donc un
-- referentiel qui n'est celui de personne.
--
-- POURQUOI C'EST SANS RISQUE AUJOURD'HUI, et pourquoi ce ne le sera plus demain. Recensement
-- exhaustif fait AVANT d'ecrire cette migration : aucune fonction, aucune vue, aucun index,
-- aucune valeur par defaut, aucune policy et aucun declencheur ne lit `car_for` ; la seule
-- reference est la contrainte de bornes reprise ci-dessous ; et les 96 lignes ont leurs six
-- colonnes a NULL. Le renommage ne peut donc casser aucun comportement. Des qu'une valeur metier
-- y sera ecrite (lots 2 et 5), ce ne sera plus vrai : c'est precisement pour cela qu'on corrige
-- le referentiel MAINTENANT, avant la premiere valeur.
--
-- ROLLBACK EXACT, si besoin :
--   DROP FUNCTION public.pnj_caracteristique_base(text,text);
--   DROP FUNCTION public.pnj_caracteristiques_base(text);
--   DROP FUNCTION public.pnj_caracteristiques_cles();
--   ALTER TABLE public.pnj_membres DROP CONSTRAINT pnj_car_bornes;
--   ALTER TABLE public.pnj_membres RENAME COLUMN car_ent TO car_for;
--   ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_car_bornes CHECK (<definition d'origine>);
-- Aucune donnee a restaurer : les colonnes sont vides.

-- ---------------------------------------------------------------------------------------
-- 1. LE REFERENTIEL
-- ---------------------------------------------------------------------------------------
ALTER TABLE public.pnj_membres RENAME COLUMN car_for TO car_ent;

COMMENT ON COLUMN public.pnj_membres.car_int IS 'Intelligence — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.car_cha IS 'Charisme — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.car_vol IS 'Volonte — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.car_per IS 'Perception — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.car_dup IS 'Duplicite — 0 a 100. Valeur de BASE.';
COMMENT ON COLUMN public.pnj_membres.car_ent IS
  'Entregent — 0 a 100. Valeur de BASE. Remplace l''ancienne colonne `car_for` : FOR ne fait pas '
  'partie du referentiel cible et n''existe chez aucun personnage joueur.';

-- Memes bornes qu'avant, memes semantiques : NULL reste autorise (caracteristique non encore
-- posee), toute valeur presente reste dans 0..100.
ALTER TABLE public.pnj_membres DROP CONSTRAINT IF EXISTS pnj_car_bornes;
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_car_bornes CHECK (
      COALESCE(car_int, 0) BETWEEN 0 AND 100
  AND COALESCE(car_cha, 0) BETWEEN 0 AND 100
  AND COALESCE(car_vol, 0) BETWEEN 0 AND 100
  AND COALESCE(car_per, 0) BETWEEN 0 AND 100
  AND COALESCE(car_dup, 0) BETWEEN 0 AND 100
  AND COALESCE(car_ent, 0) BETWEEN 0 AND 100);

-- ---------------------------------------------------------------------------------------
-- 2. LA SEULE PORTE DE LECTURE -- VALEUR DE BASE UNIQUEMENT
-- ---------------------------------------------------------------------------------------
-- Ces primitives rendent ce qui est ECRIT dans la ligne. Elles ne composent rien, n'ajoutent
-- rien, ne connaissent ni objet, ni effet, ni bonus, ni groupe. Le jour ou une valeur EFFECTIVE
-- existera (lot 10), elle sera une fonction DISTINCTE construite par-dessus celles-ci -- jamais
-- une modification de celles-ci, pour qu'on puisse toujours lire la base sans composition.

-- Le referentiel, ecrit UNE fois. Tout le reste s'y refere plutot que de recopier six noms.
CREATE OR REPLACE FUNCTION public.pnj_caracteristiques_cles()
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  SELECT ARRAY['INT','CHA','VOL','PER','DUP','ENT']::text[];
$$;

CREATE OR REPLACE FUNCTION public.pnj_caracteristiques_base(p_pnj_id text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object(
           'INT', m.car_int, 'CHA', m.car_cha, 'VOL', m.car_vol,
           'PER', m.car_per, 'DUP', m.car_dup, 'ENT', m.car_ent)
    FROM public.pnj_membres m WHERE m.id = p_pnj_id;
$$;

-- Une cle inconnue LEVE, elle ne rend pas NULL en silence : une faute de frappe dans une formule
-- doit se voir tout de suite, pas se comporter comme une caracteristique absente.
CREATE OR REPLACE FUNCTION public.pnj_caracteristique_base(p_pnj_id text, p_cle text)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb;
BEGIN
  IF p_cle IS NULL OR NOT (p_cle = ANY (public.pnj_caracteristiques_cles())) THEN
    RAISE EXCEPTION 'pnj_caracteristique_base: caracteristique inconnue %. Referentiel : %',
      COALESCE(p_cle, '<NULL>'), array_to_string(public.pnj_caracteristiques_cles(), ', ')
      USING ERRCODE = 'invalid_parameter_value';
  END IF;
  v := public.pnj_caracteristiques_base(p_pnj_id);
  IF v IS NULL THEN RETURN NULL; END IF;        -- PNJ introuvable : pas une erreur de cle.
  RETURN (v->>p_cle)::integer;
END; $$;

REVOKE ALL ON FUNCTION public.pnj_caracteristiques_cles()            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_caracteristiques_base(text)        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_caracteristique_base(text,text)    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_caracteristiques_cles()         TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_caracteristiques_base(text)     TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_caracteristique_base(text,text) TO service_role;