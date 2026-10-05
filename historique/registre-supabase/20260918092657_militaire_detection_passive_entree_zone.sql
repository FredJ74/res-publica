-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918092657
-- Nom original      : militaire_detection_passive_entree_zone
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 09:26:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 21d12a069ce68d1b568b33b749e21a7a
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
-- =========================================================================================
-- DETECTION PASSIVE SUR ENTREE DE ZONE (18 septembre 2026)
-- =========================================================================================
-- LA POSITION N'EST JAMAIS DECLAREE PAR LE CLIENT. La fonction ne prend AUCUN parametre : elle
-- relit la position canonique de l'acteur dans personnages_donnees. Un navigateur ne peut donc
-- pas se pretendre ailleurs pour sonder une zone qu'il n'occupe pas.
--
-- DEUX JETS INDEPENDANTS. A->B et B->A sont tires separement : voir n'est pas etre vu. Chaque
-- camp peut reussir, echouer, ou les deux.
--
-- CONFIDENTIALITE : la fonction ne renvoie QUE ce a quoi l'acteur a droit. Un camp qui echoue ne
-- recoit rien -- pas une liste masquee, pas un compteur, rien. La selection et la degradation se
-- font ici, et le navigateur ne voit jamais la donnee brute.
--
-- 0 PA, donc UNE TENTATIVE PAR ZONE ET PAR JOUR : sans cette garde, faire l'aller-retour dans un
-- couloir relancerait le de indefiniment et gratuitement. C'est une garde anti-rejeu technique,
-- pas un equilibrage.
CREATE TABLE IF NOT EXISTS public.militaire_detections (
  id          text PRIMARY KEY,          -- '<personnage>:<jour>:<pays>/<ville>/<batiment>/<piece>'
  personnage  text NOT NULL,
  jour        text NOT NULL,
  zone        text NOT NULL,
  cree_le     timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.militaire_detections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.militaire_detections FROM PUBLIC, anon, authenticated;

-- ETAT CANONIQUE DE CONTACT MUTUEL. C'est le seul artefact durable produit par la detection, et
-- c'est celui que le futur moteur physique consommera -- il n'aura pas a refaire la detection.
-- La resolution du combat n'est PAS inventee ici : on note qu'il y a contact, rien de plus.
CREATE TABLE IF NOT EXISTS public.contacts_militaires (
  id           bigserial PRIMARY KEY,
  pays_a       text NOT NULL,
  pays_b       text NOT NULL,
  ville        text,
  batiment     text,
  piece        text,
  effectif_a   integer,
  effectif_b   integer,
  etabli_le    timestamptz NOT NULL DEFAULT now(),
  consomme_le  timestamptz,              -- rempli par le moteur de combat le jour ou il existera
  bataille_id  bigint REFERENCES public.batailles(id)
);
CREATE INDEX IF NOT EXISTS contacts_militaires_ouverts_idx
  ON public.contacts_militaires (etabli_le DESC) WHERE consomme_le IS NULL;
ALTER TABLE public.contacts_militaires ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.contacts_militaires FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.contacts_militaires_id_seq FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.militaire_entree_zone()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  c_bonus_jumelles constant integer := 30;
  v_moi text; v_pays text; v_ville text; v_bat text; v_piece text;
  v_jour text; v_zone text; v_cle text;
  v_reco numeric; v_jumelles boolean;
  v_mes_pnj integer; v_ma_reco numeric; v_mes_equipes integer; v_mon_effectif integer;
  v_militaire boolean; v_contacts jsonb := '[]'::jsonb; v_mutuels integer := 0;
  r record; v_bande text; v_modif integer;
  v_camo_eux numeric; v_camo_moi numeric;
  v_chance_moi integer; v_chance_eux integer; v_vu_par_moi boolean; v_vu_par_eux boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_city,''), coalesce(current_building,''),
         coalesce(current_room,''), coalesce((competences_militaires->>'reconnaissance')::numeric, 0),
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'jumelles')
    INTO v_pays, v_ville, v_bat, v_piece, v_reco, v_jumelles
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- MA FORCE : les soldats que je mene physiquement, plus moi-meme.
  SELECT count(*)::integer,
         coalesce(avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)), 0),
         count(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
            WHERE a->>'produitMilitaire' = 'tenue_camouflage'))::integer
    INTO v_mes_pnj, v_ma_reco, v_mes_equipes
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE sol->>'leaderCourant' = v_moi;

  v_militaire := EXISTS (SELECT 1 FROM public.services_militaires sm
                          WHERE sm.personnage = v_moi AND sm.fin_ts IS NULL);

  -- Un civil seul n'est pas une force : il ne detecte rien passivement et n'est pas detecte
  -- comme unite. Les jumelles restent son moyen ACTIF de voir (militaire_observer, 1 PA).
  IF coalesce(v_mes_pnj,0) = 0 AND NOT v_militaire THEN
    RETURN jsonb_build_object('ok', true, 'force', false, 'contacts', '[]'::jsonb);
  END IF;
  v_mon_effectif := coalesce(v_mes_pnj,0) + 1;

  -- GARDE ANTI-REJEU : une tentative par zone et par jour, l'ordre etant a 0 PA.
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  v_zone := v_pays || '/' || v_ville || '/' || v_bat || '/' || v_piece;
  v_cle  := v_moi || ':' || v_jour || ':' || v_zone;
  BEGIN
    INSERT INTO public.militaire_detections (id, personnage, jour, zone)
    VALUES (v_cle, v_moi, v_jour, v_zone);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', true, 'force', true, 'deja_sonde', true, 'contacts', '[]'::jsonb);
  END;

  FOR r IN
    SELECT c.data->>'pays' AS pays_cible,
           sol->>'ville' AS ville, sol->>'buildingId' AS bat, sol->>'roomId' AS piece,
           count(*)::integer AS effectif,
           avg(coalesce((sol->'formation'->>'reconnaissance')::numeric, 0)) AS reco_moy,
           count(*) FILTER (WHERE EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
              WHERE a->>'produitMilitaire' = 'tenue_camouflage'))::integer AS equipes,
           bool_or(EXISTS (
             SELECT 1 FROM jsonb_array_elements(
               CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END) a
              WHERE a->>'produitMilitaire' = 'jumelles')) AS a_jumelles
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' IS DISTINCT FROM v_pays
       AND coalesce(sol->>'ville','') <> ''
       AND (sol->>'leaderCourant') IS NULL
       -- CONTEXTE DE GUERRE OBLIGATOIRE. Sans guerre active, une force etrangere est juste
       -- une force etrangere : on ne la sonde pas, et on ne revele rien a son sujet.
       AND EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = v_pays AND g.data->>'attaque' = c.data->>'pays')
                        OR (g.data->>'attaque'  = v_pays AND g.data->>'attaquant' = c.data->>'pays')))
     GROUP BY 1, 2, 3, 4
  LOOP
    -- La bande compare des POSITIONS, pas des nationalites : on passe donc le meme pays des deux
    -- cotes. Sinon militaire_bande_distance rendrait toujours 'hors' entre deux ennemis, qui sont
    -- par construction de pays differents -- et aucune detection ne serait jamais possible.
    v_bande := public.militaire_bande_distance(v_pays, v_ville, v_bat, v_pays, r.ville, r.bat);
    v_modif := public.militaire_modif_distance(v_bande);
    CONTINUE WHEN v_modif IS NULL;   -- hors de portee : aucun jet, aucune trace

    v_camo_eux := public.militaire_camouflage_groupe(r.reco_moy, r.effectif, r.equipes);
    v_camo_moi := public.militaire_camouflage_groupe(v_ma_reco, v_mon_effectif, v_mes_equipes);

    v_chance_moi := public.militaire_chance_detection(
      v_reco, v_camo_eux, v_modif, CASE WHEN v_jumelles THEN c_bonus_jumelles ELSE 0 END);
    v_chance_eux := public.militaire_chance_detection(
      r.reco_moy, v_camo_moi, v_modif, CASE WHEN coalesce(r.a_jumelles,false) THEN c_bonus_jumelles ELSE 0 END);

    v_vu_par_moi := (floor(random() * 100)::integer + 1) <= v_chance_moi;
    v_vu_par_eux := (floor(random() * 100)::integer + 1) <= v_chance_eux;

    -- Je les vois : je recois du renseignement DEJA degrade. Eux ne recoivent rien de ce fait.
    IF v_vu_par_moi THEN
      v_contacts := v_contacts || jsonb_build_array(
        public.militaire_degrader(v_bande, r.effectif, r.pays_cible, r.ville, r.bat));
    END IF;

    -- CONTACT MUTUEL : etat canonique, et lui seul est persiste. Aucun combat n'est declenche.
    IF v_vu_par_moi AND v_vu_par_eux THEN
      INSERT INTO public.contacts_militaires (pays_a, pays_b, ville, batiment, piece, effectif_a, effectif_b)
      VALUES (v_pays, r.pays_cible, r.ville, r.bat, r.piece, v_mon_effectif, r.effectif);
      v_mutuels := v_mutuels + 1;
    END IF;
  END LOOP;

  -- `mutuels` est un compte de MES contacts, information que j'ai acquise par mes propres jets.
  -- Il n'est rendu que parce que chaque contact mutuel implique que je les ai vus.
  RETURN jsonb_build_object('ok', true, 'force', true, 'effectif', v_mon_effectif,
    'reconnaissance', v_reco, 'jumelles', v_jumelles,
    'contacts', v_contacts, 'contacts_mutuels', v_mutuels);
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_entree_zone() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_entree_zone() TO authenticated;