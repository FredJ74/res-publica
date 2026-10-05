-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927141942
-- Nom original      : socle_pnj_bascule_axe_possessions_soldat
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:19:42 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 436658f63077aff77e6a8b189258150e
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
-- LOT 4c — BASCULE DE L'AXE POSSESSIONS (27 septembre 2026)
--
-- Les lectures etaient deja au socle depuis le 26/09 (camouflage, gilet en bataille, popup de
-- groupe). Seules les ECRITURES restaient dans `soldat.accessoires`. Ce lot les deplace, et
-- arrete le miroir de cet axe -- sans quoi la prochaine ecriture du blob, pour une toute autre
-- raison, ecraserait le socle avec un tableau perime.
--
-- TROIS ECRIVAINS, ET TROIS SEULEMENT : militaire_equiper_accessoire, militaire_gilet_absorber,
-- militaire_ordre_collectif (consommation d'une ration). Recensement fait avant d'ecrire.
--
-- CE QUI NE CHANGE PAS. L'autorite reste le Lieutenant de CETTE section. Le plafond d'inventaire
-- reste 100. Le gilet se fragilise toujours a 50 %, et seulement s'il a servi. L'equipement
-- militaire reste NON CESSIBLE a la main : la raison n'est plus « le blob le detient encore »
-- mais « il se reprend par l'ordre de section » -- une regle metier, qui survivra a la migration.
--
-- LA VALEUR `origine = 'blob_accessoires'` EST CONSERVEE, a dessein. Trois lectures de detection
-- s'en servent pour distinguer l'equipement REGLEMENTAIRE d'un objet donne par un joueur. La
-- renommer obligerait a reecrire ces trois fonctions volumineuses pour un gain purement
-- cosmetique, au prix d'un risque de transcription. Le nom est donc historique et son sens est
-- fixe ici : DELIVRE PAR LE MAGASIN MILITAIRE. Dette consignee.
COMMENT ON COLUMN public.pnj_possessions.origine IS
  'Provenance. ''socle'' : remis par un joueur, cessible a la main. ''blob_accessoires'' : delivre '
  'par le magasin militaire, non cessible a la main -- se reprend par l''ordre de section. Le nom '
  'est HISTORIQUE (il datait de la phase miroir) ; depuis la bascule de l''axe possessions le '
  '27/09/2026, il ne designe plus une copie du blob mais l''origine reglementaire de l''objet.';

-- ---------------------------------------------------------------------------------------
-- EQUIPER / DESEQUIPER : l'objet se deplace entre l'inventaire du Lieutenant et le socle
-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_equiper_accessoire(
  p_compagnie_id text, p_section_id text, p_matricule text, p_objet_id text, p_sens text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c_plafond constant integer := 100;
  g record; v_inv jsonb; v_occupe numeric; v_objet jsonb; v_pos integer;
  v_pnj text; v_ligne bigint;
BEGIN
  IF coalesce(p_sens,'') NOT IN ('equiper','desequiper') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;
  IF coalesce(btrim(coalesce(p_matricule,'')),'') = ''
     OR coalesce(btrim(coalesce(p_objet_id,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- AUTORITE INCHANGEE : Lieutenant structurel de cette section, meme empire.
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  -- Le soldat est desormais identifie par la couche METIER du socle, qui porte sa section.
  SELECT sm.pnj_id INTO v_pnj
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND sm.matricule = p_matricule AND m.statut = 'actif';
  IF v_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable', 'matricule', p_matricule);
  END IF;

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  IF p_sens = 'equiper' THEN
    SELECT i, pos INTO v_objet, v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
     WHERE i->>'id' = p_objet_id LIMIT 1;
    IF v_objet IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent_de_l_inventaire');
    END IF;
    SELECT coalesce(jsonb_agg(i ORDER BY pos), '[]'::jsonb) INTO v_inv
      FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos) WHERE pos <> v_pos;
    INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
    VALUES (v_pnj, v_objet, 'blob_accessoires');
    UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = g.o_moi;

  ELSE
    SELECT p.id, p.objet INTO v_ligne, v_objet FROM public.pnj_possessions p
     WHERE p.pnj_id = v_pnj AND p.objet->>'id' = p_objet_id
     ORDER BY p.id LIMIT 1 FOR UPDATE;
    IF v_ligne IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_porte');
    END IF;
    SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric, (i->>'encombrement')::numeric, 1))), 0)
      INTO v_occupe FROM jsonb_array_elements(v_inv) i;
    IF v_occupe + 1 > c_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein', 'plafond', c_plafond);
    END IF;
    DELETE FROM public.pnj_possessions WHERE id = v_ligne;
    UPDATE public.personnages_donnees
       SET inventory = v_inv || jsonb_build_array(v_objet) WHERE name = g.o_moi;
  END IF;

  RETURN jsonb_build_object('ok', true, 'sens', p_sens, 'matricule', p_matricule,
    'objet', v_objet->>'name', 'produit', v_objet->>'produitMilitaire', 'objet_id', p_objet_id);
END; $$;

-- ---------------------------------------------------------------------------------------
-- LE GILET : meme regle, lue et ecrite dans le socle pour un PNJ
-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_gilet_absorber(
  p_est_pj boolean, p_nom text, p_compagnie_id text, p_section_id text, p_matricule text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb; v_pos integer; v_protege boolean; v_pnj text; v_ligne bigint; v_objet jsonb;
BEGIN
  -- LE PJ : inchange, son gilet est dans son propre inventaire.
  IF p_est_pj THEN
    SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
      INTO v_inv FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
    IF v_inv IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'porteur_introuvable'); END IF;
    SELECT pos INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
     WHERE i->>'produitMilitaire' = 'gilet_pare_balles'
       AND coalesce((i->>'fragilise')::boolean, false) = false ORDER BY pos LIMIT 1;
    IF v_pos IS NULL THEN RETURN jsonb_build_object('protege', false, 'raison', 'aucun_gilet_intact'); END IF;
    v_protege := (random() < 0.5);
    IF v_protege THEN
      SELECT coalesce(jsonb_agg(CASE WHEN pos = v_pos
               THEN i || jsonb_build_object('fragilise', true,
                      'desc', coalesce(i->>'desc','') || ' Fragilisé : a déjà encaissé un impact.')
               ELSE i END ORDER BY pos), '[]'::jsonb)
        INTO v_inv FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos);
      UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_nom;
    END IF;
    RETURN jsonb_build_object('protege', v_protege, 'gilet_fragilise', v_protege);
  END IF;

  -- LE PNJ : son gilet vit desormais dans le socle. Le plus ancien gilet intact, comme avant.
  SELECT p.id, p.objet INTO v_ligne, v_objet
    FROM public.pnj_possessions p
    JOIN public.pnj_soldats_metier sm ON sm.pnj_id = p.pnj_id
   WHERE sm.compagnie_id = p_compagnie_id AND sm.section_id = p_section_id
     AND sm.matricule = p_matricule
     AND p.objet->>'produitMilitaire' = 'gilet_pare_balles'
     AND coalesce((p.objet->>'fragilise')::boolean, false) = false
   ORDER BY p.id LIMIT 1 FOR UPDATE;
  IF v_ligne IS NULL THEN
    RETURN jsonb_build_object('protege', false, 'raison', 'aucun_gilet_intact');
  END IF;

  -- Le jet AVANT l'ecriture : sur un echec le gilet reste intact. Regle inchangee.
  v_protege := (random() < 0.5);
  IF v_protege THEN
    UPDATE public.pnj_possessions
       SET objet = v_objet || jsonb_build_object('fragilise', true)
     WHERE id = v_ligne;
  END IF;
  RETURN jsonb_build_object('protege', v_protege, 'gilet_fragilise', v_protege);
END; $$;

-- ---------------------------------------------------------------------------------------
-- LE MIROIR S'ARRETE SUR CET AXE
-- ---------------------------------------------------------------------------------------
-- Indispensable, et c'est le point le plus dangereux de la bascule : sans cela, la prochaine
-- ecriture du blob pour une toute autre raison -- une ration, un entrainement -- rappellerait
-- pnj_miroir_possessions et ECRASERAIT le socle avec le tableau `accessoires` devenu perime.
CREATE OR REPLACE FUNCTION public.pnj_miroir_possessions_si_axe_blob(
  p_pnj_id text, p_accessoires jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF public.pnj_axe_verrouille(ARRAY[p_pnj_id], 'possessions') IS NOT NULL THEN
    PERFORM public.pnj_miroir_possessions(p_pnj_id, p_accessoires);
  END IF;
END; $$;

REVOKE ALL ON FUNCTION public.pnj_miroir_possessions_si_axe_blob(text,jsonb)
  FROM PUBLIC, anon, authenticated;