-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927165748
-- Nom original      : socle_pnj_militant_raccorde_au_socle
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 16:57:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : e6fd9404ee4c092b2160a71d806aaf20
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
-- CHECKPOINT B — LE MILITANT EST RACCORDE, SANS RIEN ACTIVER DE NEUF
--
-- POURQUOI LUI ET PAS LE CODETENU. Le mandat distingue deux situations. Le recrutement du militant
-- est REELLEMENT VIVANT et suffisamment defini -- recruteur : un membre d'une organisation
-- syndicale ; quota : deux ; un par jour ; cout : 2 PA ; gratuit a vie. Il est donc raccorde. Le
-- codetenu, lui, n'a aucun chemin vivant (aucun PNJ du jeu ne porte job=codetenu) et lui en donner
-- un ajouterait du gameplay : il reste hors des metiers recrutables, son profil conserve pour plus
-- tard.
--
-- CE QUI N'EST PAS ACTIVE : le blocus syndical, seule utilite du militant, reste mort en amont
-- (getMonSyndicatEtGrade lit chargerOrgas et state.orgas, qui n'existent ni l'un ni l'autre). Le
-- reparer serait un correctif de gameplay, pas une migration. Cette RPC ne le touche pas.
--
-- CE QUE LE RACCORDEMENT FERME AU PASSAGE. Le plafond de deux etait verifie DANS LE NAVIGATEUR, et
-- `militants_recrutes` etait alimentee par un INSERT direct du client : rien n'empechait d'en
-- recruter trente. Le plafond est desormais compte au serveur, sur le socle. C'est une fuite
-- d'autorite refermee par la migration, pas un changement de regle : la valeur reste deux.
--
-- CE QUI RESTE AU CLIENT, ET POURQUOI : la garde « un seul par jour » s'appuie sur `state.day`, et
-- le jeu n'a AUCUNE source serveur du jour de jeu. La verifier ici aurait exige d'en inventer une.
-- Elle reste donc cliente, et c'est consigne comme tel.
CREATE OR REPLACE FUNCTION public.militant_recruter(
  p_nom text, p_organisation_id text DEFAULT NULL,
  p_ville text DEFAULT NULL, p_batiment text DEFAULT NULL, p_piece text DEFAULT NULL,
  p_fn text DEFAULT NULL, p_pa integer DEFAULT NULL, p_cost integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c_plafond constant integer := 2;
  v_moi text; v_prof record; v_id text; v_nom text; v_pay jsonb; v_pays text;
  v_deja integer; v_pa integer; v_cost integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_nom := btrim(COALESCE(p_nom, ''));
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;

  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = 'militant';
  IF v_prof IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;

  SELECT COALESCE(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  -- PLAFOND COMPTE AU SERVEUR, sur le socle qui fait autorite.
  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'militant' AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_militants',
      'plafond', c_plafond, 'deja', v_deja); END IF;

  v_id := 'militant-' || substr(md5(lower(btrim(v_moi)) || '|' || lower(v_nom)), 1, 12);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_recrute', 'pnj_id', v_id); END IF;

  v_pa   := COALESCE(p_pa,   v_prof.pa_initial,   0);
  v_cost := COALESCE(p_cost, v_prof.cout_initial, 0);
  IF p_fn IS NOT NULL AND (v_pa > 0 OR v_cost > 0) THEN
    v_pay := public.payer_ordre(v_moi, p_fn, v_pa, v_cost);
  ELSE
    v_pay := jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse', 'paiement', v_pay); END IF;

  -- IL NE SUIT PERSONNE : un militant reste sur son lieu de militance, donc position PROPRE et
  -- aucun leader. C'est l'autre etat autorise par pnj_position_deux_etats.
  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      ville, building_id, room_id, pa, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'militant', 'beta', v_nom, v_pays, v_moi,
      p_ville, p_batiment, p_piece, 12, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
      statut = 'actif', proprietaire_pj = EXCLUDED.proprietaire_pj,
      ville = EXCLUDED.ville, building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
      car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
      car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
      maj_le = now();

  INSERT INTO public.pnj_militants_metier (pnj_id, organisation_id, grade, rejoint_le)
  VALUES (v_id, p_organisation_id, 'Militant (PNJ)', now())
  ON CONFLICT (pnj_id) DO UPDATE SET
      organisation_id = EXCLUDED.organisation_id, grade = EXCLUDED.grade;

  -- Le registre historique est CONSERVE : sbGetMesMilitants le lit encore, et on ne retire pas une
  -- structure dont un lecteur vivant depend.
  INSERT INTO public.militants_recrutes (id, country, recruteur, data)
  VALUES (v_id, v_pays, v_moi, jsonb_build_object('nom', v_nom, 'pnj_id', v_id,
            'jour', (extract(epoch from now()) * 1000)::bigint))
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id, 'nom', v_nom, 'metier', 'militant',
    'caracteristiques', public.pnj_metier_profil('militant'),
    'paiement', v_pay, 'militants', v_deja + 1, 'plafond', c_plafond);
END; $$;