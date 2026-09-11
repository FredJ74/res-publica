-- =====================================================================
-- L'AUTRUCHE ENTRAVEE -- SECURISATION DES TRACTS (11 septembre 2026)
-- =====================================================================
-- 1. Caisse de l'Imprimerie-Librairie Gutenberg (Port-Sainte-Marie) : meme systeme que les ateliers
--    de La Tribune (batiments_etat, sous-objet imprimerie.caisse), amorcee par la dotation unique
--    (registre dotations_amorcage_caisses : jamais deux fois).
-- 2. POP : fusion des sauvegardes clientes (trigger) -- une sauvegarde qui porte popBase (derniere
--    POP envoyee par ce client) n'applique que SON delta sur la valeur courante de la base ; une
--    sauvegarde ancienne ne peut plus remettre l'ancienne POP.
-- 3. tracts_appliquer_effet_pop : effet POP d'un tract, atomique (un seul UPDATE, verrou de ligne),
--    ne modifie QUE resources.pop.
-- 4. tracts_donner_joueur / tracts_reclamer_don : don de tracts entre vrais PJ par objets_recus, avec
--    destinataire verifie, idempotence (id de requete) et reclamation exclusive a la reception.
-- =====================================================================

-- ------------------------------------------------------------------ 1. CAISSE GUTENBERG
DO $$
DECLARE
  c_ref   CONSTANT text := 'batiments_etat:republic_ville_a_imprimerie-librairie#imprimerie';
  c_id    CONSTANT text := 'republic_ville_a_imprimerie-librairie';
  v_data  jsonb;
  v_d     jsonb;
  v_obj   jsonb;
  v_solde numeric;
  v_verse numeric;
  v_existe boolean;
BEGIN
  IF EXISTS (SELECT 1 FROM public.dotations_amorcage_caisses WHERE caisse_ref = c_ref) THEN
    RETURN;   -- deja amorcee : jamais une seconde dotation
  END IF;
  SELECT data INTO v_data FROM public.batiments_etat WHERE id = c_id FOR UPDATE;
  v_existe := FOUND;
  v_d := CASE WHEN NOT v_existe THEN '{}'::jsonb
              WHEN jsonb_typeof(v_data) = 'string' THEN (v_data #>> '{}')::jsonb
              WHEN jsonb_typeof(v_data) = 'object' THEN v_data ELSE '{}'::jsonb END;
  v_obj := CASE WHEN jsonb_typeof(v_d -> 'imprimerie') = 'object' THEN v_d -> 'imprimerie' ELSE '{"caisse":0}'::jsonb END;
  v_solde := CASE WHEN jsonb_typeof(v_obj -> 'caisse') = 'number' THEN (v_obj ->> 'caisse')::numeric ELSE 0 END;
  v_verse := CASE WHEN v_solde < 200 THEN 200 - v_solde ELSE 0 END;
  IF v_verse > 0 THEN
    v_d := v_d || jsonb_build_object('imprimerie', v_obj || '{"caisse":200}'::jsonb);
    IF v_existe THEN
      UPDATE public.batiments_etat SET data = to_jsonb(v_d::text), updated_at = now() WHERE id = c_id;
    ELSE
      INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
      VALUES (c_id, 'republic', 'ville_a', 'imprimerie-librairie', to_jsonb(v_d::text), now());
    END IF;
  END IF;
  INSERT INTO public.dotations_amorcage_caisses (caisse_ref, stockage, pays, cle, solde_avant, montant_verse, solde_apres, caisse_creee)
  VALUES (c_ref, 'batiments_etat', 'republic', 'ville_a/imprimerie-librairie#imprimerie', v_solde, v_verse, GREATEST(v_solde, 200), NOT v_existe AND v_verse > 0);
END $$;

-- ------------------------------------------------------------------ 2. FUSION DE LA POP
CREATE OR REPLACE FUNCTION public.personnages_fusionner_pop()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_base numeric;
  v_old  numeric;
BEGIN
  IF jsonb_typeof(NEW.resources) = 'object' AND NEW.resources ? 'popBase' THEN
    v_base := CASE WHEN jsonb_typeof(NEW.resources -> 'popBase') = 'number' THEN (NEW.resources ->> 'popBase')::numeric END;
    NEW.resources := NEW.resources - 'popBase';   -- jamais stocke
    IF TG_OP = 'UPDATE' AND v_base IS NOT NULL AND jsonb_typeof(NEW.resources -> 'pop') = 'number' THEN
      v_old := CASE WHEN jsonb_typeof(OLD.resources -> 'pop') = 'number' THEN (OLD.resources ->> 'pop')::numeric ELSE v_base END;
      -- Valeur courante de la base + ce que CE client a change depuis sa derniere sauvegarde.
      NEW.resources := jsonb_set(NEW.resources, '{pop}',
        to_jsonb(GREATEST(0, LEAST(100, v_old + ((NEW.resources ->> 'pop')::numeric - v_base)))));
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.personnages_fusionner_pop() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_personnages_fusionner_pop ON public.personnages;
CREATE TRIGGER trg_personnages_fusionner_pop
  BEFORE INSERT OR UPDATE ON public.personnages
  FOR EACH ROW EXECUTE FUNCTION public.personnages_fusionner_pop();

-- ------------------------------------------------------------------ 3. EFFET POP D'UN TRACT
-- Valeurs de jeu inchangees : tract ordinaire +/-3 a 8, tract calomnieux -5. Un seul UPDATE : la
-- lecture de la POP courante et l'ecriture se font sous le verrou de ligne, deux effets simultanes
-- se cumulent. updated_at n'est pas touche (ce n'est pas une sauvegarde du personnage).
CREATE OR REPLACE FUNCTION public.tracts_appliquer_effet_pop(p_cible text, p_delta integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_pop numeric;
BEGIN
  IF p_delta IS NULL OR abs(p_delta) < 3 OR abs(p_delta) > 8 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_invalide');
  END IF;
  UPDATE public.personnages
     SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{pop}',
           to_jsonb(GREATEST(0, LEAST(100,
             COALESCE(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END, 50) + p_delta))))
   WHERE name = p_cible
   RETURNING (resources ->> 'pop')::numeric INTO v_pop;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'pop', v_pop);
END;
$$;

-- ------------------------------------------------------------------ 4. DON DE TRACTS ENTRE PJ
CREATE OR REPLACE FUNCTION public.tracts_donner_joueur(p_requete text, p_expediteur text, p_destinataire text, p_objet jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_existant record;
  v_qte      integer;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^don-tracts-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF jsonb_typeof(p_objet) <> 'object' OR COALESCE(p_objet ->> 'type', '') NOT IN ('tract', 'tract_calomnieux')
     OR COALESCE(btrim(p_objet ->> 'cible'), '') = '' OR jsonb_typeof(p_objet -> 'quantite') <> 'number' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide');
  END IF;
  v_qte := (p_objet ->> 'quantite')::integer;
  IF v_qte < 1 OR v_qte > 1000 OR v_qte::numeric <> (p_objet ->> 'quantite')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_expediteur IS NULL OR p_destinataire IS NULL OR p_expediteur = p_destinataire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE name = p_expediteur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'expediteur_introuvable');
  END IF;

  -- Meme format que sbDonnerObjetJoueur (data = texte JSON), lu tel quel par sbGetObjetsRecus.
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (p_requete, p_destinataire, p_expediteur, to_jsonb(p_objet::text))
  ON CONFLICT (id) DO NOTHING;
  IF NOT FOUND THEN
    SELECT destinataire, expediteur INTO v_existant FROM public.objets_recus WHERE id = p_requete;
    IF FOUND AND (v_existant.destinataire <> p_destinataire OR v_existant.expediteur <> p_expediteur) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'requete_deja_utilisee');
    END IF;
    RETURN jsonb_build_object('ok', true, 'id', p_requete, 'rejeu', true);
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', p_requete, 'rejeu', false);
END;
$$;

-- Reception : suppression ET lecture en une instruction. Deux onglets du destinataire ne peuvent
-- pas recevoir le meme don : seul celui qui recupere la ligne l'ajoute a son inventaire.
CREATE OR REPLACE FUNCTION public.tracts_reclamer_don(p_id text, p_destinataire text)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  DELETE FROM public.objets_recus
   WHERE id = p_id AND destinataire = p_destinataire
     AND id LIKE 'don-tracts-%'
  RETURNING jsonb_build_object('id', id, 'expediteur', expediteur, 'data', data);
$$;

REVOKE ALL ON FUNCTION public.tracts_appliquer_effet_pop(text, integer)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tracts_donner_joueur(text, text, text, jsonb)     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tracts_reclamer_don(text, text)                  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tracts_appliquer_effet_pop(text, integer)      TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.tracts_donner_joueur(text, text, text, jsonb) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.tracts_reclamer_don(text, text)              TO anon, authenticated, service_role;
