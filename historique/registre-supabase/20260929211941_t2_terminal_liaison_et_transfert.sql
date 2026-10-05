-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260929211941
-- Nom original      : t2_terminal_liaison_et_transfert
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-29 21:19:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8ccd7d181a6691478c96444ae83a1035
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
create or replace function public.militaire_terminal_liaison(p_moi text, p_pnj_id text)
returns boolean
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_radio_moi boolean; v_leader text; pe record; v_radio_groupe boolean;
BEGIN
  IF public.pnj_co_present(p_moi, p_pnj_id) THEN RETURN true; END IF;

  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
           jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                     THEN pd.inventory ELSE '[]'::jsonb END) i
           WHERE pd.name = p_moi AND i->>'produitMilitaire' = 'radio') INTO v_radio_moi;
  IF NOT coalesce(v_radio_moi, false) THEN RETURN false; END IF;

  SELECT leader_pj INTO v_leader FROM public.pnj_membres WHERE id = p_pnj_id;
  IF v_leader IS NOT NULL THEN
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                       THEN pd.inventory ELSE '[]'::jsonb END) i
             WHERE pd.name = v_leader AND i->>'produitMilitaire' = 'radio') INTO v_radio_groupe;
    RETURN coalesce(v_radio_groupe, false);
  END IF;

  SELECT * INTO pe FROM public.pnj_position_effective(p_pnj_id);
  IF pe.ville IS NULL THEN RETURN false; END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.pnj_membres m2
      JOIN public.pnj_possessions p ON p.pnj_id = m2.id
     WHERE m2.statut = 'actif' AND m2.pays = pe.pays
       AND m2.ville = pe.ville
       AND m2.building_id IS NOT DISTINCT FROM pe.building_id
       AND m2.room_id IS NOT DISTINCT FROM pe.room_id
       AND p.objet->>'produitMilitaire' = 'radio') INTO v_radio_groupe;
  RETURN coalesce(v_radio_groupe, false);
END; $fn$;

comment on function public.militaire_terminal_liaison(text,text) is
  'Le Lieutenant peut-il commander ce soldat ? Vrai s''il est physiquement present avec lui, sinon vrai seulement si le Lieutenant porte une radio ET que le groupe distant en porte une -- celle de son leader PJ, ou, a defaut de leader joueur, celle d''un PNJ place au meme endroit, qui fait alors office de leader pour cette liaison.';

create or replace function public.militaire_terminal_transferer(
  p_requete text, p_matricule text, p_signature text, p_qte integer, p_sens text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_plafond constant integer := 100;
  g record; v_deja record; v_pnj text; v_qte integer := coalesce(p_qte, 0);
  v_inv jsonb; v_reste integer; v_dispo integer := 0; v_occupe numeric;
  v_ligne jsonb; v_u integer; v_nouv jsonb := '[]'::jsonb;
  v_bouge integer := 0; v_nom text; v_arme text; v_id bigint; v_objet jsonb;
  v_res jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF coalesce(p_sens,'') NOT IN ('donner','reprendre') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide'); END IF;
  IF v_qte < 1 OR v_qte > 100 OR v_qte IS DISTINCT FROM p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  IF coalesce(btrim(coalesce(p_signature,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT sm.pnj_id INTO v_pnj
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
     AND sm.matricule = p_matricule AND m.statut = 'actif';
  IF v_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;
  IF NOT public.pnj_co_present(g.o_moi, v_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  IF p_sens = 'donner' THEN
    SELECT coalesce(sum(public.militaire_unites_objet(i)), 0)::integer INTO v_dispo
      FROM jsonb_array_elements(v_inv) i
     WHERE public.militaire_objet_signature(i) = p_signature;
    IF v_dispo < v_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante',
        'disponibles', v_dispo, 'demande', v_qte); END IF;

    v_reste := v_qte;
    FOR v_ligne IN SELECT value FROM jsonb_array_elements(v_inv) LOOP
      IF v_reste > 0 AND public.militaire_objet_signature(v_ligne) = p_signature THEN
        v_u := public.militaire_unites_objet(v_ligne);
        v_nom := coalesce(v_ligne->>'name', '?');
        IF v_u <= v_reste THEN
          INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
          VALUES (v_pnj, v_ligne, 'socle');
          v_reste := v_reste - v_u; v_bouge := v_bouge + v_u;
        ELSE
          INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
          VALUES (v_pnj, v_ligne || jsonb_build_object('qty', v_reste), 'socle');
          v_nouv := v_nouv || jsonb_build_array(v_ligne || jsonb_build_object('qty', v_u - v_reste));
          v_bouge := v_bouge + v_reste; v_reste := 0;
        END IF;
      ELSE
        v_nouv := v_nouv || jsonb_build_array(v_ligne);
      END IF;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_nouv, updated_at = now()
     WHERE name = g.o_moi;

  ELSE
    SELECT coalesce(sum(public.militaire_unites_objet(p.objet)), 0)::integer INTO v_dispo
      FROM public.pnj_possessions p
     WHERE p.pnj_id = v_pnj AND public.militaire_objet_signature(p.objet) = p_signature;
    IF v_dispo < v_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante_soldat',
        'disponibles', v_dispo, 'demande', v_qte); END IF;

    SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric,
             (i->>'encombrement')::numeric, 1))), 0) INTO v_occupe
      FROM jsonb_array_elements(v_inv) i;
    IF v_occupe + v_qte > c_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein',
        'occupe', v_occupe, 'plafond', c_plafond, 'demande', v_qte); END IF;

    v_reste := v_qte;
    FOR v_id, v_objet IN
      SELECT p.id, p.objet FROM public.pnj_possessions p
       WHERE p.pnj_id = v_pnj AND public.militaire_objet_signature(p.objet) = p_signature
       ORDER BY p.id FOR UPDATE
    LOOP
      EXIT WHEN v_reste <= 0;
      v_u := public.militaire_unites_objet(v_objet);
      v_nom := coalesce(v_objet->>'name', '?');
      IF v_u <= v_reste THEN
        DELETE FROM public.pnj_possessions WHERE id = v_id;
        v_inv := v_inv || jsonb_build_array(v_objet);
        v_reste := v_reste - v_u; v_bouge := v_bouge + v_u;
      ELSE
        UPDATE public.pnj_possessions
           SET objet = v_objet || jsonb_build_object('qty', v_u - v_reste) WHERE id = v_id;
        v_inv := v_inv || jsonb_build_array(v_objet || jsonb_build_object('qty', v_reste));
        v_bouge := v_bouge + v_reste; v_reste := 0;
      END IF;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_inv, updated_at = now()
     WHERE name = g.o_moi;
  END IF;

  v_arme := public.militaire_arme_recalculer(v_pnj);

  v_res := jsonb_build_object('ok', true, 'sens', p_sens, 'matricule', p_matricule,
    'signature', p_signature, 'quantite', v_bouge, 'objet', v_nom, 'arme', v_arme);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'transfert', v_res);
  RETURN v_res;
END; $fn$;

comment on function public.militaire_terminal_transferer(text,text,text,integer,text) is
  'Deplace N unites d''une signature d''objet entre le Lieutenant et un de ses soldats PNJ, dans les deux sens. Aucune liste blanche : n''importe quel objet passe. Co-presence exigee dans les deux sens. Un objet empile est scinde par son qty, un objet unitaire part en entier. Recalcule l''armement du soldat apres chaque mouvement. Idempotente par cle de requete.';

revoke all on function public.militaire_terminal_transferer(text,text,text,integer,text) from public, anon, authenticated;
grant execute on function public.militaire_terminal_transferer(text,text,text,integer,text) to authenticated, service_role;