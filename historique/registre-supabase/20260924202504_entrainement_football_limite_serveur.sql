-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924202504
-- Nom original      : entrainement_football_limite_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 20:25:04 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e418d4c260d29ab57b96edca3ae854ef
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
CREATE TABLE IF NOT EXISTS public.entrainements_football (
  id         text PRIMARY KEY,
  personnage text NOT NULL,
  jour       integer NOT NULL,
  stat       text NOT NULL CHECK (stat IN ('defense','technique','endurance')),
  cree_le    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS entrainements_football_perso_jour
  ON public.entrainements_football (personnage, jour);

COMMENT ON TABLE public.entrainements_football IS
  'Journal des entrainements de football reellement effectues. Une ligne = un entrainement. La limite de 2 par jour de jeu se calcule a la lecture, jamais stockee.';

ALTER TABLE public.entrainements_football ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.entrainements_football FROM anon, authenticated, PUBLIC;
GRANT ALL ON public.entrainements_football TO service_role;

-- CONSOMMER UN ENTRAINEMENT : limite + paiement + enregistrement dans la MEME transaction.
CREATE OR REPLACE FUNCTION public.football_entrainement_consommer(p_stat text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE c_max constant integer := 2;
        v_moi text; v_jour integer; v_nb integer; v_paie jsonb; v_id text;
BEGIN
  IF p_stat NOT IN ('defense','technique','endurance') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stat_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- DOUBLE CLIC : le second appel attend ici, puis constate la limite.
  PERFORM pg_advisory_xact_lock(hashtext('football_entrainement|' || v_moi));

  SELECT d.day INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT count(*) INTO v_nb
    FROM public.entrainements_football e
   WHERE e.personnage = v_moi AND e.jour = v_jour;

  IF v_nb >= c_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'limite_quotidienne_atteinte',
                              'nb', v_nb, 'max', c_max, 'jour', v_jour);
  END IF;

  -- LE PAIEMENT EN DERNIER, ET PAR L'AUTORITE HABITUELLE (miroir des couts + verrou).
  v_paie := public.payer_ordre(v_moi, 'tenue_entrainement', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'));
  END IF;

  v_id := 'ef-' || (extract(epoch from clock_timestamp())*1000)::bigint
               || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.entrainements_football (id, personnage, jour, stat)
  VALUES (v_id, v_moi, v_jour, p_stat);

  RETURN jsonb_build_object('ok', true, 'nb', v_nb + 1, 'max', c_max,
                            'jour', v_jour, 'pa', v_paie->'pa');
END;
$function$;

-- COMBIEN AUJOURD'HUI ? Affichage seul, jamais autre chose que le compte du joueur courant.
CREATE OR REPLACE FUNCTION public.football_entrainements_du_jour()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE c_max constant integer := 2; v_moi text; v_jour integer; v_nb integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT d.day INTO v_jour FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  SELECT count(*) INTO v_nb
    FROM public.entrainements_football e
   WHERE e.personnage = v_moi AND e.jour = v_jour;
  RETURN jsonb_build_object('ok', true, 'nb', v_nb, 'max', c_max, 'jour', v_jour);
END;
$function$;

REVOKE ALL ON FUNCTION public.football_entrainement_consommer(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.football_entrainements_du_jour() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.football_entrainement_consommer(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.football_entrainements_du_jour() TO authenticated, service_role;