-- =============================================================================
-- L'ENTREPOT MUNICIPAL REVERSE A SA MAIRIE
-- =============================================================================
-- Date d'application en production : 20 septembre 2026.
--
-- CE FICHIER EST UN RATTRAPAGE DE VERSIONNEMENT. Il reproduit l'ETAT FINAL
-- present en production, pas l'historique de la session.
--
-- MIGRATION DE PRODUCTION ABSORBEE :
--   20260920100703  entrepot_reversement_mairie
--       cree la table public.entrepots_reversements et les quatre fonctions
--       entrepot_caisse_lire, entrepot_reverser, entrepot_virement_mairie,
--       entrepots_reverser_excedent.
--
-- DEPENDANCES — a rejouer AVANT ce fichier :
--   * public.batiments_etat et public.batiment_etat_lire(...)   (hors depot,
--     lot « caisses batiments_etat » ; cf. migration_caisses_batiments_etat.sql)
--   * public.caisse_institution_mouvement(...) et son marqueur d'appel interne
--     `rp.caisse_interne` — migration_caisse_institution.sql, puis les
--     migrations de production 20260913230229 caisse_institution_mouvement_plafonne,
--     20260916222731 caisse_institution_mouvement_exige_acteur,
--     20260919224608 caisse_institution_autorite_lot1 et
--     20260920091040 caisse_primitive_heritee_durcie.
--   * public.salaire_caisse_de(poste, pays, ville) — migrations de production
--     20260920094712 salaires_payes_par_leur_caisse puis
--     20260920110011 salaire_caisse_ville_du_poste.
--     ATTENTION : 110011 est POSTERIEURE a 100703. En rejeu, entrepot_reverser
--     n'a besoin que de l'existence de la fonction, mais la resolution
--     « mairie-capitale » contre « mairie_ville_a » n'est complete qu'apres 110011.
--   * public.acteur_poste_courant() et public.mon_personnage() — lot « postes,
--     source d'autorite serveur » (20260915214756) et chantier B
--     (20260913120554 chantier_b_ossature_identite_auth).
--   * public.est_appel_serveur() rendu fail-closed — 20260919231313.
--   * l'autorite `directeur_entrepot` doit exister dans postes_nommes_regles.
--
-- CHEVAUCHEMENT SIGNALE : public.entrepot_reverser pose le marqueur
-- `rp.caisse_interne` et figure a ce titre dans le lot « caisses ». Elle est
-- versionnee ICI parce que c'est son lot fonctionnel d'origine. Si le fichier du
-- lot « caisses » la redefinit aussi, un seul des deux doit la garder.
--
-- -----------------------------------------------------------------------------
-- COMMENTAIRE D'ORIGINE DE LA MIGRATION 20260920100703
-- -----------------------------------------------------------------------------
-- =====================================================================
-- §1 — L'ENTREPOT MUNICIPAL REVERSE A SA MAIRIE
-- =====================================================================
-- REGLE GD : fonds de roulement permanent de 5 000 FR par entrepot. Au-dela,
-- l'excedent remonte a la mairie. Plus deux flux :
--   A. virement VOLONTAIRE decide par le directeur de l'entrepot ;
--   B. reversement AUTOMATIQUE quotidien de tout ce qui depasse 5 000 FR.
--
-- CE QUI EST REUTILISE, PAS REINVENTE :
--   * la caisse vit deja dans batiments_etat, sous-cle `entrepot.caisse`, avec
--     un `data` stocke en CHAINE JSON -- batiment_etat_lire() sait deja la
--     deballer, on s'en sert ;
--   * l'autorite `directeur_entrepot` existe deja dans postes_nommes_regles
--     (nomme par le maire_adjoint, portee ville) ;
--   * la mairie destinataire est resolue par salaire_caisse_de(), qui gere deja
--     l'irregularite « mairie-capitale » contre « mairie_ville_a ».

-- -----------------------------------------------------------------------------
-- 1. TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.entrepots_reversements (
  id           text PRIMARY KEY,          -- <entrepot>:<date> : l'anti-rejeu EST la cle
  entrepot_id  text NOT NULL,
  mairie_id    text NOT NULL,
  jour         date NOT NULL,
  montant      numeric NOT NULL,
  mode         text NOT NULL CHECK (mode IN ('automatique','volontaire')),
  acteur       text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.entrepots_reversements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.entrepots_reversements FROM PUBLIC, anon, authenticated;

-- ETAT FINAL CONSTATE : RLS active, AUCUNE politique, aucun trigger. La table
-- est donc close pour anon et authenticated ; seuls postgres et service_role
-- la voient. Rien a ajouter.

-- -----------------------------------------------------------------------------
-- 2. FONCTIONS — definitions recopiees telles quelles depuis la production
--    (pg_get_functiondef), sans reformatage ni correction.
-- -----------------------------------------------------------------------------

-- Lit la caisse d'un entrepot, en deballant la chaine JSON si besoin.
CREATE OR REPLACE FUNCTION public.entrepot_caisse_lire(p_id text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN jsonb_typeof(public.batiment_etat_lire(e.data) -> 'entrepot' -> 'caisse') = 'number'
              THEN (public.batiment_etat_lire(e.data) -> 'entrepot' ->> 'caisse')::numeric
              ELSE 0 END
    FROM public.batiments_etat e WHERE e.id = p_id;
$function$;

REVOKE ALL ON FUNCTION public.entrepot_caisse_lire(text) FROM PUBLIC, anon, authenticated;

-- Mouvement atomique d'une caisse d'entrepot vers la mairie de sa ville.
-- p_montant NULL = tout l'excedent au-dessus du fonds de roulement.
CREATE OR REPLACE FUNCTION public.entrepot_reverser(p_entrepot_id text, p_montant numeric, p_mode text, p_acteur text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_roulement constant numeric := 5000;   -- fonds de roulement permanent (regle GD)
  v_pays text; v_ville text; v_etat jsonb; v_caisse numeric;
  v_mairie text; v_verse numeric; v_jour date; v_id text;
BEGIN
  -- L'identifiant est <pays>_<ville>_<batiment> : on en derive pays et ville.
  v_pays  := split_part(p_entrepot_id, '_', 1);
  v_ville := split_part(p_entrepot_id, '_', 2);
  IF v_pays = '' OR v_ville = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_invalide');
  END IF;

  -- Verrou de ligne : deux reversements simultanes se serialisent.
  SELECT public.batiment_etat_lire(e.data) INTO v_etat
    FROM public.batiments_etat e WHERE e.id = p_entrepot_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable');
  END IF;

  v_caisse := CASE WHEN jsonb_typeof(v_etat -> 'entrepot' -> 'caisse') = 'number'
                   THEN (v_etat -> 'entrepot' ->> 'caisse')::numeric ELSE 0 END;

  v_mairie := public.salaire_caisse_de('maire', v_pays, v_ville);
  IF v_mairie IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mairie_introuvable', 'ville', v_ville);
  END IF;

  IF p_mode = 'automatique' THEN
    v_verse := greatest(0, v_caisse - c_roulement);
  ELSE
    -- Virement volontaire : borne par la tresorerie REELLE, jamais par ce que
    -- le client annonce.
    v_verse := least(greatest(coalesce(p_montant, 0), 0), greatest(v_caisse, 0));
  END IF;

  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'caisse', v_caisse,
                              'roulement', c_roulement);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id := p_entrepot_id || ':' || v_jour::text ||
          CASE WHEN p_mode = 'volontaire'
               THEN ':v' || (extract(epoch from clock_timestamp())*1000)::bigint
               ELSE '' END;

  -- L'anti-rejeu EST la cle : un reversement automatique deja fait aujourd'hui
  -- ne peut pas etre rejoue, meme par deux crons concurrents.
  BEGIN
    INSERT INTO public.entrepots_reversements (id, entrepot_id, mairie_id, jour, montant, mode, acteur)
    VALUES (v_id, p_entrepot_id, v_mairie, v_jour, v_verse, p_mode, p_acteur);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reverse_aujourdhui',
                              'jour', v_jour, 'caisse', v_caisse);
  END;

  -- Debit de l'entrepot, en conservant la forme d'origine (chaine JSON).
  v_etat := jsonb_set(v_etat, '{entrepot,caisse}', to_jsonb(v_caisse - v_verse));
  UPDATE public.batiments_etat
     SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = p_entrepot_id;

  -- Credit de la mairie, par la primitive verrouillee (appel interne).
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.caisse_institution_mouvement(v_mairie, v_verse, true);

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'mairie', v_mairie,
                            'caisse', v_caisse - v_verse, 'mode', p_mode, 'jour', v_jour);
END;
$function$;

REVOKE ALL ON FUNCTION public.entrepot_reverser(text, numeric, text, text) FROM PUBLIC, anon, authenticated;

-- ------------------------------------------------ A. virement VOLONTAIRE
CREATE OR REPLACE FUNCTION public.entrepot_virement_mairie(p_entrepot_id text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  v_pays  := split_part(p_entrepot_id, '_', 1);
  v_ville := split_part(p_entrepot_id, '_', 2);

  -- AUTORITE : directeur de CET entrepot, dans SA ville. Le maire et son adjoint
  -- ne sont pas inclus : l'autonomie de la caisse est precisement le sujet.
  IF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                  WHERE a.poste_id = 'directeur_entrepot'
                    AND a.pays = v_pays
                    AND coalesce(a.poste_city, '') = v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  RETURN public.entrepot_reverser(p_entrepot_id, p_montant, 'volontaire', v_moi);
END;
$function$;

REVOKE ALL ON FUNCTION public.entrepot_virement_mairie(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.entrepot_virement_mairie(text, numeric) TO authenticated, service_role;

-- ------------------------------------------- B. reversement AUTOMATIQUE
-- Serveur uniquement : appele par le traitement quotidien.
CREATE OR REPLACE FUNCTION public.entrepots_reverser_excedent()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v jsonb; v_total numeric := 0; v_n int := 0; v_detail jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  FOR r IN SELECT e.id FROM public.batiments_etat e
            WHERE e.id LIKE '%\_entrepot-%'
              AND public.batiment_etat_lire(e.data) ? 'entrepot'
            ORDER BY e.id
  LOOP
    v := public.entrepot_reverser(r.id, NULL, 'automatique', NULL);
    IF coalesce((v->>'ok')::boolean, false) AND coalesce((v->>'verse')::numeric, 0) > 0 THEN
      v_total := v_total + (v->>'verse')::numeric;
      v_n := v_n + 1;
      v_detail := v_detail || jsonb_build_array(jsonb_build_object('entrepot', r.id, 'verse', v->>'verse'));
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'entrepots', v_n, 'total', v_total, 'detail', v_detail);
END;
$function$;

REVOKE ALL ON FUNCTION public.entrepots_reverser_excedent() FROM PUBLIC, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. DROITS — etat final constate en production (pg_proc.proacl)
-- -----------------------------------------------------------------------------
-- Les REVOKE ci-dessus laissent, sur une base neuve, les droits par defaut de
-- PUBLIC sur les fonctions nouvellement creees. La production porte exactement
-- ceci ; on le redit explicitement pour que le rejeu produise le meme etat.
--   entrepot_caisse_lire ......... postgres, service_role
--   entrepot_reverser ............ postgres, service_role
--   entrepot_virement_mairie ..... postgres, authenticated, service_role
--   entrepots_reverser_excedent .. postgres, service_role

GRANT EXECUTE ON FUNCTION public.entrepot_caisse_lire(text)                        TO service_role;
GRANT EXECUTE ON FUNCTION public.entrepot_reverser(text, numeric, text, text)      TO service_role;
GRANT EXECUTE ON FUNCTION public.entrepots_reverser_excedent()                     TO service_role;

-- -----------------------------------------------------------------------------
-- 4. REPARATION PONCTUELLE DES DONNEES DU 20 SEPTEMBRE
-- -----------------------------------------------------------------------------
-- NEANT. La migration 20260920100703 ne contient AUCUN UPDATE ponctuel sur
-- public.batiments_etat : verifie sur le texte integral conserve dans
-- supabase_migrations.schema_migrations (8 455 caracteres, un seul enonce).
-- Les caisses d'entrepot n'ont pas ete retouchees a la main ce jour-la.
