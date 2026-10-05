-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920094712
-- Nom original      : salaires_payes_par_leur_caisse
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 09:47:12 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f03751cad267aad1c26e8564b29bbe5d
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
-- DECISION GD — CHAQUE POSTE EST PAYE PAR LA CAISSE DE SON INSTITUTION
-- =====================================================================
-- Si la caisse ne contient pas assez : LE SALAIRE N'EST PAS VERSE. Pas de
-- creation monetaire, pas de decouvert, pas de dette, pas d'arriere. Le systeme
-- de dette militaire n'est PAS generalise.
-- Le revenu universel de 150 FR reste, lui, une creation ex nihilo assumee,
-- independante de toute caisse.
--
-- MIROIR DU RATTACHEMENT. Les identifiants de caisse du jeu ne sont pas
-- reguliers : la capitale utilise « mairie-capitale » et « commissariat_capitale »
-- (tiret puis souligne), les autres villes « mairie_ville_a ». On ne devine donc
-- pas le nom : on le declare, a partir des 54 caisses reellement presentes.
CREATE TABLE IF NOT EXISTS public.salaires_caisses (
  poste_id   text PRIMARY KEY,
  motif      text NOT NULL,         -- gabarit d'identifiant, {pays} et {ville} substitues
  par_ville  boolean NOT NULL DEFAULT false,
  note       text
);
ALTER TABLE public.salaires_caisses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salaires_caisses FROM PUBLIC, anon, authenticated;

INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note) VALUES
  ('president',   '{pays}_palais-presidentiel',   false, 'Palais presidentiel'),
  ('pm',          '{pays}_gouvernement-pm',       false, 'Palais du Gouvernement — enveloppe du PM'),
  ('min_int',     '{pays}_gouvernement-min_int',  false, 'ministere'),
  ('min_fin',     '{pays}_gouvernement-min_fin',  false, 'ministere'),
  ('min_just',    '{pays}_gouvernement-min_just', false, 'ministere'),
  ('min_def',     '{pays}_gouvernement-min_def',  false, 'ministere'),
  ('min_info',    '{pays}_gouvernement-min_info', false, 'ministere'),
  ('min_ae',      '{pays}_gouvernement-min_ae',   false, 'ministere'),
  ('depute',      '{pays}_assemblee',             false, 'Assemblee nationale'),
  ('juge',        '{pays}_tribunal_capitale',     false, 'poste de portee nationale : tribunal de la capitale'),
  ('commissaire', '{pays}_commissariat_{ville}',  true,  'commissariat de sa ville'),
  ('maire',       '{pays}_mairie_{ville}',        true,  'mairie de sa ville'),
  ('maire_adjoint','{pays}_mairie_{ville}',       true,  'mairie de sa ville')
ON CONFLICT (poste_id) DO UPDATE
  SET motif=EXCLUDED.motif, par_ville=EXCLUDED.par_ville, note=EXCLUDED.note;

-- Resout l'identifiant reel, en tenant compte de l'irregularite de nommage de
-- la capitale (mairie-capitale, commissariat_capitale...). On ne renvoie que des
-- caisses qui EXISTENT : un nom resolu vers rien n'est pas une caisse.
CREATE OR REPLACE FUNCTION public.salaire_caisse_de(p_poste_id text, p_pays text, p_ville text)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE r record; v_id text; v_alt text;
BEGIN
  SELECT * INTO r FROM public.salaires_caisses s WHERE s.poste_id = p_poste_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  v_id := replace(replace(r.motif, '{pays}', coalesce(p_pays,'')), '{ville}', coalesce(p_ville,''));
  IF EXISTS (SELECT 1 FROM public.caisses_batiments c WHERE c.id = v_id) THEN
    RETURN v_id;
  END IF;

  -- La capitale ecrit « mairie-capitale » la ou les autres villes ecrivent
  -- « mairie_ville_a ». On essaie donc la variante a tiret avant d'abandonner.
  v_alt := replace(v_id, '_' || coalesce(p_ville,''), '-' || coalesce(p_ville,''));
  IF v_alt <> v_id AND EXISTS (SELECT 1 FROM public.caisses_batiments c WHERE c.id = v_alt) THEN
    RETURN v_alt;
  END IF;

  RETURN NULL;
END;
$fn$;
REVOKE ALL ON FUNCTION public.salaire_caisse_de(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.salaire_caisse_de(text, text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.salaire_civil_percevoir()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_moi text; v_pays text; v_poste text; v_ville text; v_grade text;
  v_jour date; v_id text; v_cle text; v_origine text; v_montant integer;
  v_offres jsonb; v_offre text; v_caisse text; v_solde numeric;
  v_arg numeric; v_liquide numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country,'republic'), poste ->> 'id', coalesce(poste ->> 'city', current_city)
    INTO v_pays, v_poste, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;

  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NOT NULL OR coalesce(v_poste,'') IN ('soldat','lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paye_par_la_caserne');
  END IF;

  IF v_poste IS NOT NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s WHERE s.cle = v_poste AND s.categorie = 'poste';
  END IF;

  IF v_cle IS NULL THEN
    SELECT coalesce(e.data -> 'offres', e.data -> 'bne' -> 'offres')
      INTO v_offres FROM public.batiments_etat e WHERE e.id = v_pays || '_national_bne';
    IF v_offres IS NOT NULL AND jsonb_typeof(v_offres) = 'object' THEN
      SELECT t.k INTO v_offre
        FROM jsonb_each(v_offres) AS t(k, v)
        WHERE EXISTS (
          SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.v)='array' THEN t.v ELSE '[]'::jsonb END) o
           WHERE o ->> 'pjNom' = v_moi AND coalesce(o ->> 'statut','actif') = 'actif')
        LIMIT 1;
      IF v_offre IS NOT NULL THEN
        SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
          FROM public.salaires_civils_declares s WHERE s.cle = v_offre AND s.categorie = 'emploi';
      END IF;
    END IF;
  END IF;

  IF v_cle IS NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s WHERE s.cle = 'default';
  END IF;

  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bareme_absent');
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;

  -- LA CAISSE PAYEUSE. Seul le revenu universel n'en a pas.
  IF v_origine = 'poste' THEN
    v_caisse := public.salaire_caisse_de(v_poste, v_pays, v_ville);
    IF v_caisse IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_payeuse_non_declaree', 'poste', v_poste);
    END IF;
  END IF;

  -- L'anti-rejeu EST la cle : pose AVANT tout mouvement d'argent.
  BEGIN
    INSERT INTO public.salaires_civils_verses (id, personnage, jour, origine, cle, montant)
    VALUES (v_id, v_moi, v_jour, v_origine, v_cle, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT coalesce(arg,0), coalesce(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percu_aujourdhui',
                              'jour', v_jour, 'arg', v_arg, 'liquide', v_liquide);
  END;

  IF v_caisse IS NOT NULL THEN
    SELECT (data->>'solde')::numeric INTO v_solde
      FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    -- TOUT OU RIEN : pas de versement partiel, pas de dette.
    IF coalesce(v_solde, 0) < v_montant THEN
      -- On retire la ligne d'anti-rejeu : rien n'a ete verse, le titulaire
      -- pourra retenter si sa caisse est realimentee dans la journee.
      DELETE FROM public.salaires_civils_verses WHERE id = v_id;
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                                'caisse', v_caisse, 'solde', coalesce(v_solde,0), 'du', v_montant);
    END IF;
    UPDATE public.caisses_batiments
       SET data = coalesce(data,'{}'::jsonb) || jsonb_build_object('solde', v_solde - v_montant),
           updated_at = now()
     WHERE id = v_caisse;
  END IF;

  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide,0) + v_montant,
         arg     = coalesce(arg,0)     + v_montant,
         updated_at = now()
   WHERE name = v_moi
   RETURNING arg, liquide INTO v_arg, v_liquide;

  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'origine', v_origine,
                            'cle', v_cle, 'jour', v_jour, 'caisse', v_caisse,
                            'arg', v_arg, 'liquide', v_liquide);
END;
$fn$;