-- Mission du 28/11/2026 (après-midi, Claude), étape 3 — Accessoires de club revêtables (décision de Fred, 28/11/2026).
--   • L'accessoire standard de la buvette (club_accessoire_acheter : écharpe, casquette, maillot ; prix inchangés, payés en
--     monnaie du jeu) devient revêtable (ordre « Revêtir ») et donne +5 popularité tant qu'il est porté.
--   • L'accessoire personnalisé donne exactement le même bonus, +5 (au lieu de +10) : la personnalisation ne change que
--     l'apparence.
--   • Le bonus ne vaut QUE dans la ville du club (pays + ville enregistrés sur l'objet à l'achat) : il disparaît quand le
--     porteur en sort et revient quand il y rentre. On ne perd que la popularité réellement gagnée (plafond 100,
--     accessoire_gain_effectif_v1 du 28/11, conservé).
--   • Un objet de chaque type au plus : une écharpe, une casquette, un maillot de club (standard et personnalisé confondus,
--     tous clubs confondus, commandes personnalisées en cours comprises) ; refus à l'achat.
--   • Trois objets revêtus à la fois au plus, quels qu'ils soient (revetus_trois_max_v1 remplace revetus_deux_max_v1).
--   • Personnalisation incluse dans l'abonnement : elle consomme le renouvellement d'image hebdomadaire de l'abonné
--     (premium_renouvellements, source « abonnement », un par semaine, non cumulable) ; les non-abonnés l'achètent à l'unité
--     (paiement toujours « bientôt disponible »). Une commande dont l'image n'a pas encore été créée peut être annulée par
--     l'abonné : son renouvellement lui est rendu.
--
-- Choix technique : le bonus est tenu dans la fiche (resources.pop), comme avant, par un déclencheur qui suit l'inventaire
-- ET la position (pays, ville). Tous les déplacements (marche, transports, prison, expulsion…) passent par ces deux colonnes :
-- un seul endroit, quel que soit le chemin. Calculer le bonus à la lecture aurait obligé à modifier tous les lecteurs de la
-- popularité (élections, nominations, journaux…). Le déclencheur est renommé pour passer après les gardes de position
-- (navigation_positions_garder) et de popularité (personnages_fusionner_pop) ; il ne fait rien sur une écriture directe du
-- navigateur (que ces gardes annulent).
--
-- Contrôles en lecture après application :
--   SELECT position('revetus_trois_max_v1' in pg_get_functiondef('public.crim_revetir(integer,jsonb)'::regprocedure)) > 0;          -- vrai
--   SELECT position('accessoire_standard_revetable_v1' in pg_get_functiondef('public.club_accessoire_acheter(uuid,text,integer,integer)'::regprocedure)) > 0; -- vrai
--   SELECT position('accessoire_un_par_type_v1' in pg_get_functiondef('public.club_accessoire_acheter(uuid,text,integer,integer)'::regprocedure)) > 0;        -- vrai
--   SELECT tgname FROM pg_trigger WHERE tgname IN ('accessoires_revetus_popularite', 'zzz_accessoires_club_popularite');  -- zzz_… seul
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> 1 THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de 1 (%)', p_fn, n, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
END $$;

-- ===================================================================== 1. Outils
-- Type d'accessoire de club d'un objet (echarpe, casquette, maillot) ou NULL. Standard (accessoire_sport) ou personnalisé.
CREATE OR REPLACE FUNCTION public.accessoire_club_type_interne(p_item jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN jsonb_typeof(p_item) = 'object' AND p_item ->> 'type' IN ('accessoire_sport', 'accessoire_club_perso') THEN
    coalesce(nullif(replace(coalesce(p_item ->> 'revetable', ''), 'accessoire_', ''), ''),
             CASE split_part(coalesce(p_item ->> 'name', ''), ' — ', 1)
               WHEN 'Écharpe' THEN 'echarpe' WHEN 'Casquette' THEN 'casquette' WHEN 'Maillot' THEN 'maillot' END)
  END /* accessoire_un_par_type_v1 */
$$;

-- Le personnage possède-t-il déjà un accessoire de club de ce type (ou en a-t-il un personnalisé en commande) ?
CREATE OR REPLACE FUNCTION public.accessoire_club_type_possede_interne(p_nom text, p_inv jsonb, p_type text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_inv) = 'array' THEN p_inv ELSE '[]'::jsonb END) e
                  WHERE public.accessoire_club_type_interne(e) = p_type)
      OR EXISTS (SELECT 1 FROM public.accessoires_personnalises a
                  WHERE a.acheteur_nom = p_nom AND a.type_accessoire = p_type AND a.etat IN ('commande', 'apercu'))
$$;
REVOKE ALL ON FUNCTION public.accessoire_club_type_possede_interne(text, jsonb, text) FROM PUBLIC, anon, authenticated;

-- Bonus actif : accessoire de club revêtu par ce personnage, qui se trouve dans le pays ET la ville du club.
CREATE OR REPLACE FUNCTION public.accessoire_club_bonus_actif_interne(p_item jsonb, p_nom text, p_pays text, p_ville text)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.accessoire_club_type_interne(p_item) IS NOT NULL
     AND public.crim_porte_ligne_interne(p_item, p_nom)
     AND coalesce((p_item ->> 'bonus_pop_revetu')::numeric, 0) > 0
     AND p_item ->> 'club_pays' IS NOT DISTINCT FROM p_pays AND p_pays IS NOT NULL
     AND p_item ->> 'club_ville' IS NOT DISTINCT FROM p_ville AND p_ville IS NOT NULL /* accessoire_ville_club_v1 */
$$;

-- ===================================================================== 2. Popularité : inventaire ET position
CREATE OR REPLACE FUNCTION public.accessoires_revetus_popularite_trg()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_res jsonb; v_pop numeric; v_inv jsonb; v_old jsonb; i integer; e jsonb; v_gain integer; o jsonb;
BEGIN
  -- accessoire_ville_club_v1 (Fred, 28/11/2026) : +5 par accessoire de club revêtu, seulement dans la ville du club.
  -- accessoire_gain_effectif_v1 (Fred, 28/11/2026) : le gain réellement obtenu (plafond 100) est stocké sur l'objet
  -- (bonus_pop_applique) ; seul ce gain est repris quand le bonus cesse (objet retiré, parti, ou porteur hors de la ville).
  -- Écriture directe du navigateur : les gardes de position, d'inventaire et de popularité l'annulent ; rien à faire.
  IF coalesce(nullif(current_setting('role', true), 'none'), session_user) IN ('anon', 'authenticated')
     AND coalesce(current_setting('request.path', true), '') NOT LIKE '/rpc/%' THEN RETURN NEW; END IF;
  v_inv := CASE WHEN jsonb_typeof(NEW.inventory) = 'array' THEN NEW.inventory ELSE '[]'::jsonb END;
  v_old := CASE WHEN jsonb_typeof(OLD.inventory) = 'array' THEN OLD.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) x WHERE public.accessoire_club_type_interne(x) IS NOT NULL)
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_old) x WHERE x ? 'bonus_pop_applique') THEN RETURN NEW; END IF;
  v_res := CASE WHEN jsonb_typeof(NEW.resources) = 'object' THEN NEW.resources ELSE '{}'::jsonb END;
  v_pop := coalesce((v_res ->> 'pop')::numeric, 0);
  -- Reprises : bonus actif avant (ancienne position), qui ne l'est plus après (objet retiré, parti, ou porteur sorti).
  FOR o IN SELECT x FROM jsonb_array_elements(v_old) x
            WHERE public.accessoire_club_bonus_actif_interne(x, OLD.name, OLD.country, OLD.current_city) AND x ? 'bonus_pop_applique' LOOP
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) y WHERE y ->> 'accessoire_id' = o ->> 'accessoire_id'
                    AND public.accessoire_club_bonus_actif_interne(y, NEW.name, NEW.country, NEW.current_city)) THEN
      v_pop := v_pop - coalesce((o ->> 'bonus_pop_applique')::numeric, 0);
    END IF;
  END LOOP;
  -- Nouvel état : bonus actif sans marque (ou qui ne l'était pas avant) → gain réel, marqué ; bonus inactif → marque ôtée.
  FOR i IN 0 .. jsonb_array_length(v_inv) - 1 LOOP
    e := v_inv -> i;
    CONTINUE WHEN public.accessoire_club_type_interne(e) IS NULL;
    IF public.accessoire_club_bonus_actif_interne(e, NEW.name, NEW.country, NEW.current_city) THEN
      IF NOT (e ? 'bonus_pop_applique') OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_old) y
             WHERE y ->> 'accessoire_id' = e ->> 'accessoire_id'
               AND public.accessoire_club_bonus_actif_interne(y, OLD.name, OLD.country, OLD.current_city)) THEN
        v_gain := greatest(0, least(5, (100 - greatest(0, least(100, v_pop)))::integer));
        v_pop := v_pop + v_gain;
        v_inv := jsonb_set(v_inv, ARRAY[i::text], e || jsonb_build_object('bonus_pop_applique', v_gain));
      END IF;
    ELSIF e ? 'bonus_pop_applique' THEN
      v_inv := jsonb_set(v_inv, ARRAY[i::text], e - 'bonus_pop_applique');
    END IF;
  END LOOP;
  IF v_inv IS DISTINCT FROM NEW.inventory THEN NEW.inventory := v_inv; END IF;
  IF v_pop IS DISTINCT FROM coalesce((v_res ->> 'pop')::numeric, 0) THEN
    NEW.resources := v_res || jsonb_build_object('pop', greatest(0, least(100, v_pop)));
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS accessoires_revetus_popularite ON public.personnages_donnees;
DROP TRIGGER IF EXISTS zzz_accessoires_club_popularite ON public.personnages_donnees;
-- Après navigation_positions_garder et personnages_fusionner_pop, avant zzzz_hg_inventory_revision (ordre alphabétique).
CREATE TRIGGER zzz_accessoires_club_popularite BEFORE UPDATE ON public.personnages_donnees
  FOR EACH ROW WHEN (OLD.inventory IS DISTINCT FROM NEW.inventory OR OLD.country IS DISTINCT FROM NEW.country
                     OR OLD.current_city IS DISTINCT FROM NEW.current_city)
  EXECUTE FUNCTION public.accessoires_revetus_popularite_trg();

-- ===================================================================== 3. Trois objets revêtus au plus
SELECT pg_temp.rp_remplacer('public.crim_revetir(integer,jsonb)'::regprocedure,
  'IF v_portes >= 2 THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''deux_objets_revetus_max''); END IF;',
  'IF v_portes >= 3 THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''trois_objets_revetus_max''); END IF; /* revetus_trois_max_v1 (Fred, 28/11/2026) : remplace la règle des deux */',
  'revetus_trois_max_v1');

-- ===================================================================== 4. Accessoire standard : revêtable, +5, un par type
SELECT pg_temp.rp_remplacer('public.club_accessoire_acheter(uuid,text,integer,integer)'::regprocedure,
  ' IF prix IS NULL THEN RETURN jsonb_build_object(''ok'',false,''raison'',''accessoire_inconnu'');END IF;',
  ' IF prix IS NULL THEN RETURN jsonb_build_object(''ok'',false,''raison'',''accessoire_inconnu'');END IF;
 /* accessoire_un_par_type_v1 (Fred, 28/11/2026) : une écharpe, une casquette, un maillot de club au plus */
 IF public.accessoire_club_type_possede_interne(a.name,a.inventory,p_accessoire) THEN RETURN jsonb_build_object(''ok'',false,''raison'',''accessoire_type_deja_possede'',''type'',p_accessoire);END IF;',
  'accessoire_un_par_type_v1');
SELECT pg_temp.rp_remplacer('public.club_accessoire_acheter(uuid,text,integer,integer)'::regprocedure,
  ' o:=o||jsonb_build_object(''name'',(o->>''name'')||'' — ''||c.nom);',
  ' o:=o||jsonb_build_object(''name'',(o->>''name'')||'' — ''||c.nom,''revetable'',''accessoire_''||p_accessoire,''bonus_pop_revetu'',5,
  ''club'',c.nom,''club_pays'',a.country,''club_ville'',a.current_city,''accessoire_id'',gen_random_uuid()::text,
  ''desc'',''Accessoire du club ''||c.nom||''. Revêtu : +5 popularité tant que vous êtes dans la ville du club.''); /* accessoire_standard_revetable_v1 (Fred, 28/11/2026) */',
  'accessoire_standard_revetable_v1');

-- ===================================================================== 5. Accessoire personnalisé : +5, ville du club
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_livrer_service(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a public.accessoires_personnalises%ROWTYPE; v_obj jsonb; v_dep jsonb;
BEGIN
  SELECT * INTO a FROM public.accessoires_personnalises WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_introuvable'); END IF;
  IF a.etat = 'livre' THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF a.paiement_confirme_le IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'paiement_requis'); END IF;
  IF a.etat <> 'apercu' OR a.apercu_path IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'image_requise'); END IF;
  -- accessoire_perso_cinq_v1 (Fred, 28/11/2026) : même bonus que l'accessoire standard, +5, dans la ville du club seulement.
  v_obj := jsonb_build_object(
    'name', CASE a.type_accessoire WHEN 'maillot' THEN 'Maillot personnalisé' WHEN 'casquette' THEN 'Casquette personnalisée'
              ELSE 'Écharpe personnalisée' END || ' — ' || a.club,
    'type', 'accessoire_club_perso', 'revetable', 'accessoire_' || a.type_accessoire, 'bonus_pop_revetu', 5,
    'club', a.club, 'club_pays', a.pays, 'club_ville', a.ville,
    'icon', CASE a.type_accessoire WHEN 'maillot' THEN 'ti-shirt-sport' WHEN 'casquette' THEN 'ti-baseball' ELSE 'ti-ribbon-health' END,
    'image', a.apercu_path, 'personnalisation', a.demande, 'accessoire_id', a.id::text, 'encombrement', 1,
    'desc', 'Accessoire du club ' || a.club || ', personnalisé : « ' || a.demande || ' ». Revêtu : +5 popularité tant que vous êtes dans la ville du club.');
  v_dep := public.inventaire_deposer_interne(a.acheteur_nom, v_obj, true);
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_dep; END IF;
  UPDATE public.accessoires_personnalises SET etat = 'livre', image_path = a.apercu_path, livre_le = now() WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'objet', v_obj ->> 'name');
END $$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_livrer_service(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_livrer_service(uuid) TO service_role;

-- Lieu de vente commun (buvette, ou boutique des stades de Sovarka) : NULL si sur place, sinon la raison du refus.
CREATE OR REPLACE FUNCTION public.accessoire_club_lieu_refus_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_batiment IS DISTINCT FROM 'stade' OR (p_piece IS DISTINCT FROM 'buvette'
     AND NOT (p_pays = 'soviet' AND p_ville IN ('capitale', 'ville_b', 'ville_a') AND p_piece = 'boutique')) THEN 'pas_sur_place' END
$$;

-- Offre affichée au joueur (aucune écriture).
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_offre()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); p record; c record; v_prix integer; v_abonne boolean; v_inclus boolean;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT user_id, inventory, country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = moi;
  IF public.accessoire_club_lieu_refus_interne(p.country, p.current_city, p.current_building, p.current_room) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE country = p.country AND city = p.current_city;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'club_local_introuvable'); END IF;
  SELECT prix_centimes INTO v_prix FROM public.premium_produits WHERE produit = 'accessoire_personnalise';
  -- accessoire_perso_abonnement_v1 (Fred, 28/11/2026) : inclus dans l'abonnement (renouvellement d'image de la semaine).
  v_abonne := public.premium_abonne_interne(p.user_id);
  v_inclus := v_abonne AND NOT EXISTS (SELECT 1 FROM public.premium_renouvellements r WHERE r.user_id = p.user_id
                AND r.semaine = public.premium_semaine_interne() AND r.source = 'abonnement');
  RETURN jsonb_build_object('ok', true, 'club', c.nom, 'prix_centimes', v_prix,
    'paiement_ouvert', false, -- prestataire de paiement non choisi (Fred, 27/11/2026)
    'abonne', v_abonne, 'inclus_disponible', v_inclus,
    'possedes', (SELECT coalesce(jsonb_agg(t), '[]'::jsonb) FROM unnest(ARRAY['maillot', 'casquette', 'echarpe']) t
                  WHERE public.accessoire_club_type_possede_interne(moi, p.inventory, t)),
    'en_cours', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'type', a.type_accessoire, 'etat', a.etat,
                   'demande', a.demande, 'inclus', coalesce(a.achat_id, '') LIKE 'abonnement:%') ORDER BY a.cree_le), '[]'::jsonb)
                   FROM public.accessoires_personnalises a WHERE a.acheteur_nom = moi AND a.etat IN ('commande', 'apercu')));
END $$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_offre() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_offre() TO authenticated;

-- Commande incluse dans l'abonnement : consomme le renouvellement d'image de la semaine et crée une commande réglée.
-- Non-abonné (ou abonné dont le renouvellement de la semaine est déjà pris) : achat à l'unité, paiement pas encore ouvert.
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_commander(p_type text, p_demande text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); p record; c record; v_sem text := public.premium_semaine_interne();
  v_demande text := btrim(coalesce(p_demande, '')); v_id uuid;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT user_id, inventory, country, current_city, current_building, current_room INTO p
    FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  IF public.accessoire_club_lieu_refus_interne(p.country, p.current_city, p.current_building, p.current_room) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE country = p.country AND city = p.current_city;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'club_local_introuvable'); END IF;
  IF p_type IS NULL OR p_type NOT IN ('maillot', 'casquette', 'echarpe') THEN RETURN jsonb_build_object('ok', false, 'raison', 'accessoire_inconnu'); END IF;
  IF char_length(v_demande) NOT BETWEEN 3 AND 300 THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_invalide'); END IF;
  IF public.accessoire_club_type_possede_interne(moi, p.inventory, p_type) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'accessoire_type_deja_possede', 'type', p_type); END IF;
  IF NOT public.premium_abonne_interne(p.user_id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'paiement_bientot'); END IF;
  IF EXISTS (SELECT 1 FROM public.premium_renouvellements r WHERE r.user_id = p.user_id AND r.semaine = v_sem AND r.source = 'abonnement') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'renouvellement_hebdo_utilise'); END IF;
  v_id := gen_random_uuid();
  INSERT INTO public.premium_renouvellements (user_id, semaine, type_visuel, objet, source)
  VALUES (p.user_id, v_sem, 'accessoire', v_id::text, 'abonnement');
  INSERT INTO public.accessoires_personnalises (id, acheteur_user_id, acheteur_nom, pays, ville, club, type_accessoire, demande,
                                                paiement_confirme_le, achat_id)
  VALUES (v_id, p.user_id, moi, p.country, p.current_city, c.nom, p_type, v_demande, now(), 'abonnement:' || v_sem);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'source', 'abonnement'); /* accessoire_perso_abonnement_v1 */
END $$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_commander(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_commander(text, text) TO authenticated;

-- Annulation d'une commande incluse dont l'image n'a pas encore été créée : le renouvellement de la semaine est rendu.
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_annuler(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); a public.accessoires_personnalises%ROWTYPE; v_rendu integer;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO a FROM public.accessoires_personnalises WHERE id = p_id AND acheteur_nom = moi FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_introuvable'); END IF;
  IF a.etat <> 'commande' OR a.apercu_path IS NOT NULL OR coalesce(a.achat_id, '') NOT LIKE 'abonnement:%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commande_non_annulable'); END IF;
  UPDATE public.accessoires_personnalises SET etat = 'annule' WHERE id = p_id;
  DELETE FROM public.premium_renouvellements WHERE user_id = a.acheteur_user_id AND source = 'abonnement'
     AND type_visuel = 'accessoire' AND objet = p_id::text;
  GET DIAGNOSTICS v_rendu = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'renouvellement_rendu', v_rendu > 0);
END $$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_annuler(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_annuler(uuid) TO authenticated;

-- Dépôt des images (fonction Edge accessoire-personnalise, non déployée) : public comme les décors de commerce.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('accessoires-personnalises', 'accessoires-personnalises', true, 5242880, ARRAY['image/png'])
ON CONFLICT (id) DO NOTHING;

COMMIT;
