-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924141151
-- Nom original      : recrutement_candidatures_rpc_recruteur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 14:11:51 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 44ccc311b086e1085248437e03fea4ae
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
-- QUI RECRUTE QUI : Commandant -> Capitaines, Capitaine -> Lieutenants (sa compagnie),
-- Lieutenant -> soldats (sa section). Le maillon Ministre -> Commandant vit ailleurs, dans la
-- filiere des postes nommes (ordre `postuler`, 2 PA, tirage au sort a 48 h).
CREATE OR REPLACE FUNCTION public.militaire_recruteur_de_moi(
  OUT o_moi text, OUT o_pays text, OUT o_grade_recrute text,
  OUT o_compagnie text, OUT o_section text, OUT o_raison text)
RETURNS record
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_poste jsonb;
BEGIN
  o_moi := public.mon_personnage();
  IF o_moi IS NULL THEN o_raison := 'acteur_non_authentifie'; RETURN; END IF;

  SELECT coalesce(country,'republic'), poste INTO o_pays, v_poste
    FROM public.personnages_donnees WHERE name = o_moi;
  IF o_pays IS NULL THEN o_raison := 'personnage_introuvable'; RETURN; END IF;
  IF jsonb_typeof(v_poste) <> 'object' THEN o_raison := 'pas_recruteur'; RETURN; END IF;

  IF v_poste->>'id' = 'commandant' THEN
    o_grade_recrute := 'capitaine';
  ELSIF v_poste->>'id' = 'capitaine' THEN
    o_grade_recrute := 'lieutenant'; o_compagnie := v_poste->>'compagnieId';
  ELSIF v_poste->>'id' = 'lieutenant' THEN
    o_grade_recrute := 'soldat';
    o_compagnie := v_poste->>'compagnieId'; o_section := v_poste->>'sectionId';
  ELSE
    o_raison := 'pas_recruteur'; RETURN;
  END IF;
END;
$function$;

-- LES CANDIDATURES QUE JE PEUX TRAITER, et les places ou je peux les mettre.
CREATE OR REPLACE FUNCTION public.militaire_candidatures_a_traiter()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE r record; v_places jsonb; v_cands jsonb;
BEGIN
  SELECT * INTO r FROM public.militaire_recruteur_de_moi();
  IF r.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', r.o_raison); END IF;

  -- LES PLACES OUVERTES. Le calcul retranche deja les acceptations vivantes, si bien qu'un
  -- Capitaine ne peut pas promettre deux fois la meme section.
  IF r.o_grade_recrute = 'capitaine' THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'compagnie_id', c.id, 'compagnie_nom', coalesce(c.data->>'nom', c.id),
             'section_id', NULL, 'libre',
             public.militaire_places_libres_grade(r.o_pays, 'capitaine', c.id, NULL))
             ORDER BY c.id), '[]'::jsonb) INTO v_places
      FROM public.compagnies_militaires c
     WHERE c.data->>'pays' = r.o_pays
       AND public.militaire_places_libres_grade(r.o_pays, 'capitaine', c.id, NULL) > 0;

  ELSIF r.o_grade_recrute = 'lieutenant' THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'compagnie_id', c.id, 'compagnie_nom', coalesce(c.data->>'nom', c.id),
             'section_id', s->>'id', 'section_nom', coalesce(s->>'nom', s->>'id'), 'libre',
             public.militaire_places_libres_grade(r.o_pays, 'lieutenant', c.id, s->>'id'))
             ORDER BY s->>'id'), '[]'::jsonb) INTO v_places
      FROM public.compagnies_militaires c, jsonb_array_elements(c.data->'sections') s
     WHERE c.id = r.o_compagnie
       AND public.militaire_places_libres_grade(r.o_pays, 'lieutenant', c.id, s->>'id') > 0;

  ELSE
    SELECT jsonb_build_array(jsonb_build_object(
             'compagnie_id', c.id, 'compagnie_nom', coalesce(c.data->>'nom', c.id),
             'section_id', s->>'id', 'section_nom', coalesce(s->>'nom', s->>'id'), 'libre',
             public.militaire_places_libres_grade(r.o_pays, 'soldat', c.id, s->>'id')))
      INTO v_places
      FROM public.compagnies_militaires c, jsonb_array_elements(c.data->'sections') s
     WHERE c.id = r.o_compagnie AND s->>'id' = r.o_section;
  END IF;

  -- LES CANDIDATS. On masque ceux que J'AI deja ecartes -- pas ceux que d'autres ont ecartes.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', cm.id, 'candidat', cm.candidat, 'depuis', cm.cree_le) ORDER BY cm.cree_le),
         '[]'::jsonb) INTO v_cands
    FROM public.candidatures_militaires cm
   WHERE cm.pays = r.o_pays AND cm.grade_vise = r.o_grade_recrute AND cm.statut = 'active'
     AND NOT (cm.refus ? r.o_moi);

  RETURN jsonb_build_object('ok', true, 'grade_recrute', r.o_grade_recrute,
    'places', coalesce(v_places, '[]'::jsonb), 'candidatures', v_cands);
END;
$function$;

-- REFUSER — silencieux et individuel. La candidature reste `active` pour les autres recruteurs,
-- et AUCUN COURRIER n'est emis : le candidat ne doit jamais apprendre qui l'a ecarte.
CREATE OR REPLACE FUNCTION public.militaire_candidature_refuser(p_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE r record; v record;
BEGIN
  SELECT * INTO r FROM public.militaire_recruteur_de_moi();
  IF r.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', r.o_raison); END IF;

  SELECT * INTO v FROM public.candidatures_militaires WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'candidature_introuvable'); END IF;
  IF v.pays <> r.o_pays OR v.grade_vise <> r.o_grade_recrute THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_perimetre');
  END IF;
  IF v.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_non_active', 'statut', v.statut);
  END IF;

  IF NOT (v.refus ? r.o_moi) THEN
    UPDATE public.candidatures_militaires
       SET refus = refus || to_jsonb(r.o_moi) WHERE id = p_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', p_id);
END;
$function$;

-- ACCEPTER — reserve la place, fixe l'affectation, ouvre les 48 heures, annule le reste.
CREATE OR REPLACE FUNCTION public.militaire_candidature_accepter(
  p_id text, p_compagnie_id text, p_section_id text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE r record; v record; v_libre integer; v_echeance timestamptz; v_annulees integer;
BEGIN
  SELECT * INTO r FROM public.militaire_recruteur_de_moi();
  IF r.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', r.o_raison); END IF;

  -- LA CIBLE DOIT ETRE LA SIENNE : le client propose, le serveur verifie.
  IF r.o_compagnie IS NOT NULL AND p_compagnie_id IS DISTINCT FROM r.o_compagnie THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_hors_autorite');
  END IF;
  IF r.o_section IS NOT NULL AND p_section_id IS DISTINCT FROM r.o_section THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_hors_autorite');
  END IF;

  -- VERROU SUR LA CANDIDATURE D'ABORD. Deux recruteurs qui acceptent le meme candidat a la meme
  -- seconde se presentent ici l'un apres l'autre : le second trouve `acceptee` et repart avec un
  -- refus propre. C'est ce qui donne son sens a « le premier qui accepte l'emporte ».
  SELECT * INTO v FROM public.candidatures_militaires WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'candidature_introuvable'); END IF;
  IF v.pays <> r.o_pays OR v.grade_vise <> r.o_grade_recrute THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_perimetre');
  END IF;
  IF v.statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_non_active', 'statut', v.statut);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v.candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;
  IF public.militaire_grade_effectif(v.candidat) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_deja_militaire');
  END IF;

  v_libre := public.militaire_places_libres_grade(r.o_pays, v.grade_vise, p_compagnie_id, p_section_id);
  IF v_libre <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'plus_de_place'); END IF;

  v_echeance := now() + interval '48 hours';
  UPDATE public.candidatures_militaires
     SET statut = 'acceptee', accepte_par = r.o_moi, accepte_le = now(),
         echeance = v_echeance, compagnie_id = p_compagnie_id, section_id = p_section_id
   WHERE id = p_id;

  -- UNE ACCEPTATION EN ANNULE TOUTES LES AUTRES. On ne sert pas deux armees.
  UPDATE public.candidatures_militaires
     SET statut = 'annulee'
   WHERE candidat = v.candidat AND id <> p_id AND statut = 'active';
  GET DIAGNOSTICS v_annulees = ROW_COUNT;

  -- COURRIER AU CANDIDAT — et rien sur le lieu ni sur le recruteur : la decouverte se fait a la
  -- caserne, en personne. C'est tout l'interet de la scene.
  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES ('ce-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text),1,6),
          'Armée de Républia', v.candidat,
          'Votre engagement est accepté',
          'Votre candidature au grade de ' || v.grade_vise || ' a été retenue. ' ||
          'Présentez-vous à la Caserne Militaire dans les 48 heures pour découvrir votre affectation. ' ||
          'Passé ce délai, votre engagement sera caduc et la place rendue.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'), false);

  RETURN jsonb_build_object('ok', true, 'id', p_id, 'candidat', v.candidat,
    'grade', v.grade_vise, 'echeance', v_echeance, 'autres_annulees', v_annulees);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_recruteur_de_moi() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_candidatures_a_traiter() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_candidature_refuser(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_candidature_accepter(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_recruteur_de_moi() TO service_role;
GRANT EXECUTE ON FUNCTION public.militaire_candidatures_a_traiter() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_candidature_refuser(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_candidature_accepter(text,text,text) TO authenticated, service_role;