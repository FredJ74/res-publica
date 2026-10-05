-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916222758
-- Nom original      : presse_publication_reservee_a_l_auteur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 22:27:58 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d0bd29a97af2604aca657f244c3057d7
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
-- Audit des frontieres d'autorite, 17 septembre 2026.
-- fuite_publier et scandale_publier etaient executables par le role anon (SANS session) et ne
-- verifiaient rien. Consequences avant correctif :
--   * injection de texte arbitraire dans chronique_nationale, signe « Cellule enquete de la
--     redaction » (fuite) ou attribue a l'auteur du scandale ;
--   * scandale_publier declenchait en plus personnage_ajuster_pop_inf(cible, -15, -15) : un
--     visiteur sans compte pouvait donc infliger -15 POP et -15 INF a un joueur.
-- La regle appliquee n'est PAS inventee : fuites_journalistiques.auteur et scandales_presse.auteur
-- existent deja et sont renseignes par fuite_reserver / scandale_tenter, qui passent eux-memes par
-- exiger_acteur. On ne fait qu'appliquer ce que la ligne dit deja.
-- Les deux tables sont VIDES au moment du correctif (0 ligne) : aucune donnee existante affectee.
CREATE OR REPLACE FUNCTION public.fuite_publier(p_fuite_id bigint, p_contenu text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_f record; v_cid text; v_moi text;
BEGIN
  SELECT * INTO v_f FROM public.fuites_journalistiques WHERE id = p_fuite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fuite_introuvable');
  END IF;

  IF NOT public.est_appel_serveur() THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    IF v_f.auteur IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
    END IF;
  END IF;

  IF v_f.chronique_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'chronique_id', v_f.chronique_id);
  END IF;

  v_cid := 'chronique-fuite-' || p_fuite_id::text;
  BEGIN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES (v_cid, v_f.pays, v_f.ville, 'fuite_journalistique',
            jsonb_build_array(v_f.cible),
            COALESCE(NULLIF(btrim(p_contenu), ''), 'Révélations concernant ' || v_f.cible || '.'),
            jsonb_build_object('cible', v_f.cible, 'source', v_f.source, 'faits', v_f.faits,
                               'auteur_public', 'Cellule enquête de la rédaction'),
            'fuite-' || p_fuite_id::text);
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  UPDATE public.fuites_journalistiques
     SET contenu = COALESCE(NULLIF(btrim(p_contenu), ''), contenu), chronique_id = v_cid
   WHERE id = p_fuite_id;

  RETURN jsonb_build_object('ok', true, 'chronique_id', v_cid);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.fuite_publier(bigint, text) FROM anon;

CREATE OR REPLACE FUNCTION public.scandale_publier(p_scandale_id bigint, p_article text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_s record; v_cid text; v_eff jsonb := NULL; v_n integer; v_moi text;
BEGIN
  SELECT * INTO v_s FROM public.scandales_presse WHERE id = p_scandale_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scandale_introuvable');
  END IF;

  IF NOT public.est_appel_serveur() THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    IF v_s.auteur IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
    END IF;
  END IF;

  IF v_s.chronique_id IS NOT NULL THEN
    SELECT count(*) INTO v_n FROM public.scandales_presse WHERE auteur = v_s.auteur AND chronique_id IS NOT NULL;
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'chronique_id', v_s.chronique_id, 'total_auteur', v_n);
  END IF;

  v_cid := 'chronique-scandale-' || p_scandale_id::text;
  BEGIN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES (v_cid, v_s.pays, v_s.ville, 'scandale_presse',
            jsonb_build_array(v_s.cible, v_s.auteur),
            COALESCE(NULLIF(btrim(p_article), ''), v_s.accusation),
            jsonb_build_object('cible', v_s.cible, 'auteur', v_s.auteur, 'auteur_public', v_s.auteur,
                               'type_contenu', 'kompromat', 'accusation', v_s.accusation,
                               'scandale_id', p_scandale_id),
            'scandale-' || p_scandale_id::text);
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  IF NOT v_s.effet_applique THEN
    v_eff := public.personnage_ajuster_pop_inf(v_s.cible, -15, -15);
  END IF;

  UPDATE public.scandales_presse
     SET article = COALESCE(NULLIF(btrim(p_article), ''), article),
         chronique_id = v_cid, statut = 'publie', effet_applique = true
   WHERE id = p_scandale_id;

  SELECT count(*) INTO v_n FROM public.scandales_presse WHERE auteur = v_s.auteur AND chronique_id IS NOT NULL;
  RETURN jsonb_build_object('ok', true, 'chronique_id', v_cid, 'effet', v_eff, 'total_auteur', v_n);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.scandale_publier(bigint, text) FROM anon;