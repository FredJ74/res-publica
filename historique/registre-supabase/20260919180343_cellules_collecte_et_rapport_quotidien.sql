-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919180343
-- Nom original      : cellules_collecte_et_rapport_quotidien
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 18:03:43 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2b2af190c67d5fc675576d832e82beb8
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
-- COLLECTE QUOTIDIENNE ET RAPPORT DE CELLULE.
--
-- PAS DE TROISIEME CRON, et cron-minuit n'est pas deplace : la passe
-- quotidienne existante appelle ces deux fonctions. Le « rapport de 22 h » est
-- une convention diegetique ; l'execution technique est celle de la passe.
--
-- LE RAPPORT N'EST PAS ENVOYE PAR MAIL. La table mails est en allow_all PUBLIC
-- avec SELECT/UPDATE/DELETE ouverts a anon (dette transversale connue) : y
-- faire transiter des secrets d'Etat les exposerait a tout visiteur. Le contenu
-- reste donc en base, RLS + zero policy, et n'est rendu que par une projection
-- serveur controlee, reservee au ministre proprietaire. La notification, elle,
-- pourra passer par le canal ordinaire sans rien reveler.
--
-- IDEMPOTENCE : la cle primaire (cellule_id, jour) EST l'anti-rejeu. Un retry
-- de la passe ne produit jamais un second rapport pour la meme journee.

CREATE TABLE IF NOT EXISTS public.rapports_cellules (
  cellule_id text NOT NULL REFERENCES public.cellules_renseignement(id),
  jour       date NOT NULL,
  contenu    jsonb NOT NULL,
  nb_faits   integer NOT NULL DEFAULT 0,
  cree_le    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (cellule_id, jour)
);
ALTER TABLE public.rapports_cellules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rapports_cellules FROM PUBLIC, anon, authenticated;

-- --------------------------------------------------------------------------
-- Collecte : chaque agent pose execute SA specialite. Une collecte sans
-- information nouvelle ne produit aucun risque de trace -- la regle vit dans
-- chaque specialite, qui n'appelle agent_trace_deposer que si elle a ecrit.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cellules_renseignement_collecter()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_n integer := 0; v_faits integer := 0; v_res jsonb;
BEGIN
  FOR r IN
    SELECT a.id, a.role FROM public.agents_renseignement a
      JOIN public.cellules_renseignement c ON c.id = a.cellule_id
     WHERE c.statut = 'active' AND a.statut = 'actif'
       AND a.leader_courant IS NULL AND a.ville IS NOT NULL
  LOOP
    v_res := CASE r.role
      WHEN 'garde'        THEN public.agent_garde_observer(r.id)
      WHEN 'traducteur'   THEN public.agent_traducteur_ecouter(r.id)
      WHEN 'conseiller'   THEN public.agent_conseillere_observer(r.id)
      WHEN 'coordinateur' THEN public.agent_coordinateur_multimodal(r.id)
    END;
    v_n := v_n + 1;
    v_faits := v_faits + coalesce((v_res ->> 'faits')::integer, 0);
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'agents', v_n, 'faits', v_faits);
END;
$function$;

-- --------------------------------------------------------------------------
-- Rapport : agregation des faits de la cellule, UNE FOIS par journee logique.
-- Aucun fait invente : le contenu est exactement ce que les agents ont ecrit.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cellules_rapports_generer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_faits jsonb; v_n integer := 0;
BEGIN
  FOR c IN SELECT id, pays_proprietaire, pays_cible
             FROM public.cellules_renseignement WHERE statut = 'active'
  LOOP
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.rapports_cellules rc
                           WHERE rc.cellule_id = c.id AND rc.jour = v_jour);

    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'categorie', r.categorie, 'fait', r.contenu, 'source', r.source)
             ORDER BY r.categorie, r.created_at), '[]'::jsonb)
      INTO v_faits
      FROM public.renseignements_connus r
     WHERE r.titulaire = 'cellule:' || c.id
       AND (r.created_at AT TIME ZONE 'Europe/Paris')::date = v_jour;

    INSERT INTO public.rapports_cellules (cellule_id, jour, contenu, nb_faits)
    VALUES (c.id, v_jour,
            jsonb_build_object('cellule', c.id, 'pays_cible', c.pays_cible,
                               'jour', v_jour, 'faits', v_faits),
            jsonb_array_length(v_faits))
    ON CONFLICT (cellule_id, jour) DO NOTHING;

    PERFORM public.cellule_alerter_ministre(c.id, NULL,
      'Rapport de renseignement du ' || to_char(v_jour, 'DD/MM/YYYY'),
      'Le rapport quotidien de votre cellule ' || c.id ||
      ' est disponible dans votre panneau. ' ||
      jsonb_array_length(v_faits) || ' fait(s) consigne(s).');
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'rapports', v_n);
END;
$function$;

-- --------------------------------------------------------------------------
-- Projection controlee : le ministre proprietaire lit SES rapports. Aucun
-- parametre d'identite accepte du client.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cellule_rapports_mes_cellules(p_limite integer DEFAULT 10)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_res jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;

  SELECT coalesce(jsonb_agg(x ORDER BY x ->> 'jour' DESC), '[]'::jsonb) INTO v_res
    FROM (SELECT rc.contenu || jsonb_build_object('nb_faits', rc.nb_faits) AS x
            FROM public.rapports_cellules rc
            JOIN public.cellules_renseignement c ON c.id = rc.cellule_id
           WHERE c.pays_proprietaire = v_pays
           ORDER BY rc.jour DESC
           LIMIT greatest(1, least(coalesce(p_limite, 10), 60))) s;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'rapports', v_res);
END;
$function$;

REVOKE ALL ON FUNCTION public.cellules_renseignement_collecter() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cellules_rapports_generer()        FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cellules_renseignement_collecter() TO service_role;
GRANT EXECUTE ON FUNCTION public.cellules_rapports_generer()        TO service_role;
REVOKE ALL ON FUNCTION public.cellule_rapports_mes_cellules(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cellule_rapports_mes_cellules(integer) TO authenticated, service_role;
