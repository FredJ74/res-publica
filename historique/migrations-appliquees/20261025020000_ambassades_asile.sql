-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025004912.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025004912.
-- Eprouvee avant application en transaction annulee. Baseline NON reextrait.
-- ============================================================================
-- ASILE POLITIQUE -- 1/3 : demande et decision (25 octobre 2026, arbitrage de Fred)
-- ============================================================================
-- LE PARCOURS DECIDE PAR FRED :
--   1. Demande a l'accueil du Quartier des Ambassades, aupres d'une ambassade (2 PA, cout deja
--      declare de l'ordre demander_asile_politique).
--   2. Mail « demande transmise ». L'ambassadeur accepte ou refuse.
--   3. Ambassadeur PNJ : decision SELON LE DOSSIER, prise par le serveur a l'echeance (tiree
--      entre tout de suite et 3 jours, comme l'audience) : acceptee si le joueur est reellement
--      menace -- recherche (justice_recherches, condamnations non executees comprises) ou mis en
--      cause dans une affaire vivante -- refusee sinon. Mail de reponse.
--   4. Refugie accepte : acces au bureau de l'ambassade qui l'accueille, et impossible a
--      arreter tant qu'il est au Quartier des Ambassades ; arretable des qu'il en sort
--      (2/3 et 3/3).
--
-- REGLES DE CE LOT (sans arbitrage contraire de Fred) : une seule demande en cours ou un seul
-- asile actif par joueur ; une demande refusee peut etre renouvelee. Ambassadeur joueur : la
-- branche n'est pas ouverte ici (elle viendra avec les autres empires) -- toute demande est
-- donc instruite par l'ambassadeur PNJ.
--
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ambassades_asiles (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  demandeur          text NOT NULL,
  pays_hote          text NOT NULL,
  empire             text NOT NULL CHECK (empire IN ('khalija','soviet','narco')),
  statut             text NOT NULL DEFAULT 'demandee'
                     CHECK (statut IN ('demandee','accorde','refuse')),
  demandee_le        timestamptz NOT NULL DEFAULT now(),
  -- Echeance tiree a la demande. Jamais renvoyee au navigateur.
  decision_prevue_le timestamptz NOT NULL,
  decide_le          timestamptz,
  CHECK (statut = 'demandee' OR decide_le IS NOT NULL)
);
-- UNE DEMANDE EN COURS OU UN ASILE ACTIF PAR JOUEUR : garanti par la base.
CREATE UNIQUE INDEX IF NOT EXISTS ambassades_asiles_un_actif
  ON public.ambassades_asiles (demandeur) WHERE statut IN ('demandee','accorde');
ALTER TABLE public.ambassades_asiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ambassades_asiles FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.ambassades_asiles IS
  'HG asile politique v1 (25/10/2026) : lue et ecrite uniquement par les fonctions ambassade_*';

-- Le dossier : le joueur est-il reellement menace dans ce pays ?
CREATE OR REPLACE FUNCTION public.ambassade_dossier_menace(p_nom text, p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.justice_recherches(p_nom) r
                  WHERE r.country IS NULL OR r.country = p_pays)
      OR EXISTS (SELECT 1 FROM public.plaintes_en_cours p
                  WHERE p.country = p_pays
                    AND left(btrim(coalesce(p.data, '')), 1) = '{'
                    AND (p.data::jsonb ->> 'cible') = p_nom
                    AND (p.data::jsonb ->> 'status') IN ('au_parquet','enquete','poursuites',
                                                         'saisie','abandon_demande','appel'));
$function$;
REVOKE ALL ON FUNCTION public.ambassade_dossier_menace(text, text) FROM PUBLIC, anon, authenticated;

-- L'ambassade dont ce joueur est refugie, ou NULL.
CREATE OR REPLACE FUNCTION public.ambassade_refuge_de(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT empire FROM public.ambassades_asiles
   WHERE demandeur = p_nom AND statut = 'accorde' LIMIT 1;
$function$;
REVOKE ALL ON FUNCTION public.ambassade_refuge_de(text) FROM PUBLIC, anon, authenticated;

-- PROTEGE = refugie ET present au Quartier des Ambassades (decision de Fred).
CREATE OR REPLACE FUNCTION public.ambassade_refugie_protege(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.ambassade_refuge_de(p_nom) IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personnages_donnees d
                  WHERE d.name = p_nom AND d.current_building = 'quartier-ambassades');
$function$;
REVOKE ALL ON FUNCTION public.ambassade_refugie_protege(text) FROM PUBLIC, anon, authenticated;

-- LA DECISION, prise a l'echeance par le serveur. Interne. p_demandeur NULL = tous.
CREATE OR REPLACE FUNCTION public.ambassades_asiles_echoir(p_demandeur text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_ident jsonb; v_ok boolean; v_n integer := 0;
BEGIN
  FOR r IN SELECT * FROM public.ambassades_asiles
            WHERE statut = 'demandee' AND decision_prevue_le <= now()
              AND (p_demandeur IS NULL OR demandeur = p_demandeur)
            FOR UPDATE SKIP LOCKED
  LOOP
    v_ok := public.ambassade_dossier_menace(r.demandeur, r.pays_hote);
    UPDATE public.ambassades_asiles
       SET statut = CASE WHEN v_ok THEN 'accorde' ELSE 'refuse' END, decide_le = now()
     WHERE id = r.id;
    v_ident := public.ambassade_identite(r.empire);
    IF v_ok THEN
      PERFORM public.mail_systeme_poser_interne(
        v_ident ->> 'ambassade', r.demandeur, 'Asile politique accordé',
        'Après examen de votre dossier, Son Excellence <strong>' || (v_ident ->> 'ambassadeur')
        || '</strong> vous accorde l''asile politique.<br><br>'
        || 'Vous êtes en sécurité tant que vous restez au Quartier des Ambassades, et le bureau de l'''
        || (v_ident ->> 'ambassade') || ' vous est ouvert. <strong>Dès que vous en sortez, vous pouvez être arrêté(e).</strong><br><br>'
        || 'Le secrétariat de l''' || (v_ident ->> 'ambassade'));
    ELSE
      PERFORM public.mail_systeme_poser_interne(
        v_ident ->> 'ambassade', r.demandeur, 'Demande d''asile refusée',
        'Après examen de votre dossier, l''<strong>' || (v_ident ->> 'ambassade')
        || '</strong> ne peut donner suite à votre demande : rien n''y établit que vous soyez menacé(e).<br><br>'
        || 'Le secrétariat de l''' || (v_ident ->> 'ambassade'));
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END; $function$;
REVOKE ALL ON FUNCTION public.ambassades_asiles_echoir(text) FROM PUBLIC, anon, authenticated;

-- DEMANDER L'ASILE. Le PA est preleve dans la meme transaction que l'enregistrement.
CREATE OR REPLACE FUNCTION public.ambassade_demander_asile(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_batiment text; v_id uuid; v_paie jsonb; v_ident jsonb; v_statut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  v_ident := public.ambassade_identite(p_empire);
  IF v_ident IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  SELECT country, current_building INTO v_pays, v_batiment
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL OR v_pays = p_empire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  IF v_batiment IS DISTINCT FROM 'quartier-ambassades' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_asiles
   WHERE demandeur = v_moi AND statut IN ('demandee','accorde');
  IF v_statut = 'demandee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'asile_en_cours');
  ELSIF v_statut = 'accorde' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_refugie');
  END IF;

  BEGIN
    INSERT INTO public.ambassades_asiles (demandeur, pays_hote, empire, decision_prevue_le)
    VALUES (v_moi, v_pays, p_empire, now() + random() * interval '3 days')
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'asile_en_cours');
  END;

  v_paie := public.payer_ordre(v_moi, 'demander_asile_politique', 2, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    DELETE FROM public.ambassades_asiles WHERE id = v_id;
    RETURN v_paie;
  END IF;

  PERFORM public.mail_systeme_poser_interne(
    'Quartier des Ambassades', v_moi, 'Demande d''asile transmise',
    'Votre demande d''asile politique auprès de l''<strong>' || (v_ident ->> 'ambassade')
    || '</strong> a bien été transmise.<br><br>Votre dossier sera examiné, et la réponse vous parviendra dans les plus brefs délais.<br><br>'
    || 'Le secrétariat du Quartier des Ambassades');

  PERFORM public.ambassades_asiles_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_asiles WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'statut', v_statut,
                            'ambassade', v_ident ->> 'ambassade', 'pa', v_paie -> 'pa');
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_demander_asile(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_demander_asile(text) TO authenticated;
