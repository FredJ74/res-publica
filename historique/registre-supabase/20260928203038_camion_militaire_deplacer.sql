-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928203038
-- Nom original      : camion_militaire_deplacer
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-28 20:30:38 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e9ea554623ac295a97fae82beb1655db
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
create or replace function public.camion_deplacer(
  p_camion_id text, p_destination_cle text, p_avec_officier boolean, p_cle text)
returns jsonb
language plpgsql security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_moi text; c record; a record; d record; v_rejeu jsonb; v_grade text;
  v_cout constant integer := 2;
  v_total integer; v_debarques text[] := '{}'; v_transportes_pj text[] := '{}';
  v_transportes_pnj text[] := '{}'; u record; v_res jsonb; v_compagnie text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cle), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cle_requete_absente'); END IF;

  SELECT * INTO c FROM public.camions_militaires WHERE id = p_camion_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_introuvable'); END IF;
  IF c.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_hors_service'); END IF;

  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  IF FOUND THEN RETURN v_rejeu || jsonb_build_object('rejeu', true); END IF;

  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF a.country IS DISTINCT FROM c.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;
  IF NOT (a.current_city = c.ville
          AND a.current_building = public.camion_batiment_interieur()
          AND a.current_room = c.id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'officier_absent_du_camion');
  END IF;

  v_grade := public.camion_grade_commandant(v_moi);
  IF v_grade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_insuffisant'); END IF;

  SELECT * INTO d FROM public.camion_destinations(p_camion_id)
   WHERE cle = p_destination_cle;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destination_refusee'); END IF;
  IF NOT p_avec_officier AND v_grade = 'lieutenant' AND p_destination_cle <> '__caserne__' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'envoi_a_vide_hors_caserne');
  END IF;

  SELECT count(*) INTO v_total FROM public.camion_occupants(p_camion_id);
  IF v_total > c.capacite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_depassee',
      'occupants', v_total, 'capacite', c.capacite);
  END IF;

  IF p_avec_officier THEN
    IF EXISTS (SELECT 1 FROM public.camion_occupants(p_camion_id) o
                WHERE o.chef = v_moi
                  AND (o.est_pj OR o.classe = 'alpha')
                  AND COALESCE(o.pa, 0) < v_cout) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants_section',
        'cout_par_occupant', v_cout,
        'manquants', COALESCE((SELECT jsonb_agg(o.nom) FROM public.camion_occupants(p_camion_id) o
           WHERE o.chef = v_moi AND (o.est_pj OR o.classe = 'alpha')
             AND COALESCE(o.pa, 0) < v_cout), '[]'::jsonb));
    END IF;
  END IF;

  FOR u IN
    SELECT DISTINCT o.chef,
           (SELECT bool_or((x.est_pj OR x.classe = 'alpha') AND COALESCE(x.pa,0) < v_cout)
              FROM public.camion_occupants(p_camion_id) x WHERE x.chef = o.chef) AS sans_pa,
           (SELECT bool_or(x.est_pj) FROM public.camion_occupants(p_camion_id) x
             WHERE x.chef = o.chef AND x.ref = o.chef) AS est_pj
      FROM public.camion_occupants(p_camion_id) o
  LOOP
    IF u.chef = v_moi AND NOT p_avec_officier THEN
      UPDATE public.personnages_donnees
         SET current_city = c.ville, current_building = c.building_id,
             current_room = c.room_id, updated_at = now()
       WHERE name = v_moi;
      DELETE FROM public.camions_embarquements
       WHERE camion_id = c.id AND personnage = v_moi;
      CONTINUE;
    END IF;
    IF u.sans_pa THEN
      IF COALESCE(u.est_pj, false) THEN
        UPDATE public.personnages_donnees
           SET current_city = c.ville, current_building = c.building_id,
               current_room = c.room_id, updated_at = now()
         WHERE name = u.chef;
        DELETE FROM public.camions_embarquements
         WHERE camion_id = c.id AND personnage = u.chef;
      ELSE
        UPDATE public.pnj_membres
           SET ville = c.ville, building_id = c.building_id, room_id = c.room_id,
               rue_noeud_id = NULL, maj_le = now()
         WHERE id = u.chef;
      END IF;
      v_debarques := v_debarques || u.chef;
    END IF;
  END LOOP;

  SELECT COALESCE(array_agg(o.ref), '{}') INTO v_transportes_pj
    FROM public.camion_occupants(p_camion_id) o WHERE o.est_pj;
  SELECT COALESCE(array_agg(o.ref), '{}') INTO v_transportes_pnj
    FROM public.camion_occupants(p_camion_id) o
   WHERE NOT o.est_pj AND o.classe = 'alpha';

  IF array_length(v_transportes_pj, 1) > 0 THEN
    UPDATE public.personnages_donnees
       SET pa = pa - v_cout, updated_at = now()
     WHERE name = ANY(v_transportes_pj);
  END IF;
  IF array_length(v_transportes_pnj, 1) > 0 THEN
    PERFORM public.pnj_pa_debiter(v_transportes_pnj, v_cout);
  END IF;

  UPDATE public.camions_militaires
     SET ville = d.ville, building_id = d.building_id, room_id = d.room_id,
         maj_le = now()
   WHERE id = c.id;

  IF array_length(v_transportes_pj, 1) > 0 THEN
    UPDATE public.personnages_donnees SET current_city = d.ville, updated_at = now()
     WHERE name = ANY(v_transportes_pj);
  END IF;
  UPDATE public.pnj_membres
     SET ville = d.ville, maj_le = now()
   WHERE building_id = public.camion_batiment_interieur() AND room_id = c.id;

  IF array_length(v_transportes_pnj, 1) > 0 THEN
    FOR v_compagnie IN
      SELECT DISTINCT m.proprietaire_perimetre
        FROM public.pnj_membres m
       WHERE m.id = ANY(v_transportes_pnj) AND m.famille = 'soldat'
         AND m.proprietaire_perimetre IS NOT NULL
    LOOP
      PERFORM public.militaire_blob_projeter(
        regexp_replace(v_compagnie, '-s[0-9]+$', ''));
    END LOOP;
  END IF;

  v_res := jsonb_build_object('ok', true, 'camion_id', c.id,
    'depart', jsonb_build_object('ville', c.ville, 'building_id', c.building_id,
                                 'room_id', c.room_id),
    'arrivee', jsonb_build_object('ville', d.ville, 'building_id', d.building_id,
                                  'room_id', d.room_id, 'libelle', d.libelle),
    'avec_officier', p_avec_officier, 'grade', v_grade,
    'cout_par_occupant', v_cout,
    'transportes_pj', to_jsonb(v_transportes_pj),
    'transportes_pnj', COALESCE(array_length(v_transportes_pnj, 1), 0),
    'debarques', to_jsonb(v_debarques));

  INSERT INTO public.camions_ordres (requete, camion_id, acteur, action, destination, resultat)
       VALUES (p_cle, c.id, v_moi,
               CASE WHEN p_avec_officier THEN 'trajet' ELSE 'a_vide' END,
               p_destination_cle, v_res);
  RETURN v_res;
EXCEPTION WHEN unique_violation THEN
  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  RETURN COALESCE(v_rejeu, '{}'::jsonb) || jsonb_build_object('rejeu', true);
END; $fn$;

comment on function public.camion_deplacer(text,text,boolean,text) is
  'Deplace un camion et ce qu''il transporte, en une transaction. 0 FR, 2 PA par occupant reellement transporte, chacun sur ses propres PA. Refus global si un membre de la section prioritaire ne peut pas payer ; debarquement des seuls opportunistes insolvables. Idempotent par cle de requete.';

revoke all on function public.camion_deplacer(text,text,boolean,text) from public, anon, authenticated;
grant execute on function public.camion_deplacer(text,text,boolean,text) to authenticated, service_role;