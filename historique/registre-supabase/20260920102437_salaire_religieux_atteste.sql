-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920102437
-- Nom original      : salaire_religieux_atteste
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 10:24:37 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4cf6e8c4a1310f8a04ff8a8f1b6e01ee
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
-- §6.1 : LE SALAIRE RELIGIEUX PASSE AU SERVEUR
-- ---------------------------------------------------------------------------
-- CE QUI SE PASSAIT. verifierSalaireReligieux() (plateau-justice-economie.js)
-- debitait la caisse de l'eglise par une RPC, puis creditait le joueur par un
-- « state.arg += montant » LOCAL. Les deux moitiees etaient donc disjointes : le
-- credit n'etait atteste par rien, et son anti-rejeu tenait dans une valeur du
-- navigateur (state.char.dernierSalaireReligieuxJour) comparee a state.day.
-- Une fois le verrou arg/liquide actif, cette moitie-la serait silencieusement
-- ecrasee : la caisse aurait ete debitee sans que personne ne soit paye.
--
-- REGLES REPRISES A L'IDENTIQUE, rien d'invente ici :
--   * Pretre d'une ville     : 100 FR/jour, payes par la caisse de SON eglise ;
--   * Grand Pretre national  : +100 FR/jour, TOUJOURS par le Grand Tabernacle,
--                              meme s'il est par ailleurs Pretre d'une autre ville ;
--   * versement PLAFONNE par le solde (comportement existant : une caisse a moitie
--     vide paie ce qu'elle peut, ce qui ne cree aucune dette) ;
--   * titulaire lu dans titulaires_pnj, avec repli sur le PNJ par defaut -- un PJ
--     n'est paye que s'il EST le titulaire.
--
-- Le bareme et la carte des eglises sont declares en base, pas passes par l'appel :
-- le client ne choisit ni le montant, ni la caisse, ni le titulaire.

CREATE TABLE IF NOT EXISTS public.salaires_religieux_declares (
  cle       text PRIMARY KEY,
  ville     text,
  caisse    text NOT NULL,
  montant   integer NOT NULL CHECK (montant > 0),
  libelle   text
);
ALTER TABLE public.salaires_religieux_declares ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salaires_religieux_declares FROM anon, authenticated, public;

INSERT INTO public.salaires_religieux_declares (cle, ville, caisse, montant, libelle) VALUES
  ('pretre:capitale',   'capitale', 'republic_tabernacle-impots', 100, 'Pretre du Grand Tabernacle (Luthecia)'),
  ('pretre:ville_a',    'ville_a',  'republic_notre-dame-mer',    100, 'Pretre de Notre-Dame-de-la-Mer (Port-Sainte-Marie)'),
  ('pretre:ville_b',    'ville_b',  'republic_eglise-montrouge',  100, 'Pretre de l''eglise de Montrouge'),
  ('grand_pretre',      NULL,       'republic_tabernacle-impots', 100, 'Grand Pretre national')
ON CONFLICT (cle) DO UPDATE
  SET ville = EXCLUDED.ville, caisse = EXCLUDED.caisse,
      montant = EXCLUDED.montant, libelle = EXCLUDED.libelle;

-- Anti-rejeu : la cle EST le verrou (personnage + charge + jour reel).
CREATE TABLE IF NOT EXISTS public.salaires_religieux_verses (
  id          text PRIMARY KEY,
  personnage  text NOT NULL,
  cle         text NOT NULL,
  jour        date NOT NULL,
  montant     numeric NOT NULL,
  verse_le    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.salaires_religieux_verses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salaires_religieux_verses FROM anon, authenticated, public;

CREATE OR REPLACE FUNCTION public.salaire_religieux_percevoir()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_moi     text;
  v_pays    text;
  v_jour    date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_total   numeric := 0;
  v_details jsonb := '[]'::jsonb;
  r         record;
  v_titulaire text;
  v_id      text;
  v_solde   numeric;
  v_verse   numeric;
  v_arg     numeric;
  v_liquide numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF coalesce(v_pays, 'republic') <> 'republic' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'carriere_religieuse_republia_uniquement');
  END IF;

  FOR r IN SELECT * FROM public.salaires_religieux_declares ORDER BY cle LOOP
    -- LE TITULAIRE FAIT AUTORITE, PAS L'APPELANT. Le repli PNJ par defaut n'est
    -- jamais le joueur : une charge sans titulaire enregistre ne paie personne.
    SELECT t.nom_pnj INTO v_titulaire
      FROM public.titulaires_pnj t
     WHERE t.country = 'republic'
       AND t.poste_id = split_part(r.cle, ':', 1)
       AND ((r.ville IS NULL AND t.city IS NULL) OR t.city = r.ville)
     LIMIT 1;

    CONTINUE WHEN v_titulaire IS NULL OR v_titulaire <> v_moi;

    v_id := v_moi || ':' || r.cle || ':' || v_jour::text;
    BEGIN
      INSERT INTO public.salaires_religieux_verses (id, personnage, cle, jour, montant)
      VALUES (v_id, v_moi, r.cle, v_jour, r.montant);
    EXCEPTION WHEN unique_violation THEN
      CONTINUE;  -- deja percu aujourd'hui pour CETTE charge
    END;

    SELECT (data->>'solde')::numeric INTO v_solde
      FROM public.caisses_batiments WHERE id = r.caisse FOR UPDATE;

    -- Plafonne : la caisse paie ce qu'elle peut, jamais a decouvert.
    v_verse := least(coalesce(v_solde, 0), r.montant);
    IF v_verse <= 0 THEN
      -- Rien verse : on retire la ligne d'anti-rejeu pour que le titulaire puisse
      -- retenter si sa caisse est realimentee dans la journee.
      DELETE FROM public.salaires_religieux_verses WHERE id = v_id;
      v_details := v_details || jsonb_build_object('cle', r.cle, 'verse', 0, 'raison', 'caisse_vide');
      CONTINUE;
    END IF;

    UPDATE public.caisses_batiments
       SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
           updated_at = now()
     WHERE id = r.caisse;
    UPDATE public.salaires_religieux_verses SET montant = v_verse WHERE id = v_id;

    v_total   := v_total + v_verse;
    v_details := v_details || jsonb_build_object('cle', r.cle, 'verse', v_verse, 'caisse', r.caisse);
  END LOOP;

  IF v_total > 0 THEN
    UPDATE public.personnages_donnees
       SET liquide = coalesce(liquide, 0) + v_total,
           arg     = coalesce(arg, 0)     + v_total,
           updated_at = now()
     WHERE name = v_moi
     RETURNING arg, liquide INTO v_arg, v_liquide;
  ELSE
    SELECT coalesce(arg, 0), coalesce(liquide, 0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
  END IF;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'jour', v_jour,
                            'details', v_details, 'arg', v_arg, 'liquide', v_liquide);
END;
$$;

REVOKE ALL ON FUNCTION public.salaire_religieux_percevoir() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.salaire_religieux_percevoir() TO authenticated, service_role;