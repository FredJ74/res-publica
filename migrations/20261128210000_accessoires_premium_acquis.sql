-- Mission du 28/11/2026 (soir, Claude), réponses de Fred aux questions 9 à 14, 19 et 20 de l'après-midi (points 5, 6, 7).
--   5. Accessoires de club : l'ACHAT n'est plus limité (plus de refus « accessoire_type_deja_possede » à la buvette ni à la
--      commande personnalisée ; les dons, vols et trouvailles n'ont jamais été bloqués). Seul le PORT est limité, et il l'est
--      déjà par crim_revetir (revetus_trois_max_v1) : trois objets revêtus au plus, et un seul objet par catégorie de port
--      (accessoire_echarpe, accessoire_casquette, accessoire_maillot : revêtir une deuxième écharpe, quel que soit son club,
--      retire d'office la première). Rien à changer côté port.
--   6. Accessoire personnalisé : gratuit pour tous pendant la bêta (« comme tout le premium ») ; abonné : renouvellement
--      d'image de la semaine, puis achat à l'unité une fois ce renouvellement utilisé ; non-abonné : à l'unité. L'achat à
--      l'unité passe par le paiement commun (premium_achat_preparer → webhook → premium_droits « accessoire_personnalise ») ;
--      la commande consomme ce crédit. Le renouvellement (ou le crédit) n'est rendu que si l'image n'a pas été créée
--      (commande annulée avant toute image) : dès que l'image existe, il est consommé, même si l'objet n'est jamais validé.
--      visuels_versions accepte désormais le type « accessoire » (l'historique des images de la fonction Edge était refusé
--      en silence par la contrainte).
--   7. Fin d'abonnement : tout ce que l'abonné a utilisé reste acquis. Les options attachées à un lieu l'étaient déjà
--      (paiement_stripe_v1) ; s'y ajoute le COMMERCE PREMIUM dès son premier usage : dès qu'un abonné dépasse les plafonds
--      gratuits d'un fonds (familles ou références), le droit commerce_premium de ce fonds est acquis
--      (premium_droits, source « abonnement »). Les accessoires personnalisés créés sont des objets d'inventaire : ils restent.
--      Les mini-jeux ne sont pas encore codés (règle consignée pour le jour où ils le seront).
--
-- Remplacements contrôlés : club_accessoire_acheter (accessoire_achat_libre_v1), fonds_definir_types et fonds_reference_creer
--   (commerce_premium_acquis_v1). Réécrites : accessoire_personnalise_offre, accessoire_personnalise_commander,
--   accessoire_personnalise_annuler. Nouvelle : premium_commerce_usage_noter_interne. Supprimée : accessoire_club_type_possede_interne.
--
-- Contrôles en lecture après application :
--   SELECT position('accessoire_achat_libre_v1' in pg_get_functiondef('public.club_accessoire_acheter(uuid,text,integer,integer)'::regprocedure)) > 0
--      AND position('accessoire_club_type_possede' in pg_get_functiondef('public.club_accessoire_acheter(uuid,text,integer,integer)'::regprocedure)) = 0;  -- vrai
--   SELECT position('accessoire_perso_sources_v1' in pg_get_functiondef('public.accessoire_personnalise_commander(text,text)'::regprocedure)) > 0;     -- vrai
--   SELECT position('commerce_premium_acquis_v1' in pg_get_functiondef('public.fonds_definir_types(text,text,text[])'::regprocedure)) > 0
--      AND position('commerce_premium_acquis_v1' in pg_get_functiondef('public.fonds_reference_creer(text,text,text,text,text,text)'::regprocedure)) > 0; -- vrai
--   SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'visuels_versions_type_visuel_check';                -- … 'accessoire' …
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_marque text, p_n integer DEFAULT 1)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente (%)', p_fn, p_marque; END IF;
END $$;

-- ===================================================================== 5. Achat libre des accessoires de club
SELECT pg_temp.rp_remplacer('public.club_accessoire_acheter(uuid,text,integer,integer)'::regprocedure,
  $a$ /* accessoire_un_par_type_v1 (Fred, 28/11/2026) : une écharpe, une casquette, un maillot de club au plus */
 IF public.accessoire_club_type_possede_interne(a.name,a.inventory,p_accessoire) THEN RETURN jsonb_build_object('ok',false,'raison','accessoire_type_deja_possede','type',p_accessoire);END IF;
$a$,
  $b$ /* accessoire_achat_libre_v1 (Fred, 28/11/2026 soir) : achat non limité ; seul le port l'est (crim_revetir) */
$b$,
  'accessoire_achat_libre_v1');

-- ===================================================================== 6. Accessoire personnalisé : bêta, abonnement, unité
-- Source de la prochaine commande : 'beta', 'abonnement' (renouvellement de la semaine libre), 'unite' (crédit acheté), ou NULL.
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_source_interne(p_user uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE
    WHEN p_user IS NULL THEN NULL
    WHEN public.premium_beta_interne() THEN 'beta'
    WHEN public.premium_abonne_interne(p_user) AND NOT EXISTS (SELECT 1 FROM public.premium_renouvellements r
           WHERE r.user_id = p_user AND r.semaine = public.premium_semaine_interne() AND r.source = 'abonnement') THEN 'abonnement'
    WHEN EXISTS (SELECT 1 FROM public.premium_droits d WHERE d.user_id = p_user AND d.produit = 'accessoire_personnalise'
           AND d.revoque_le IS NULL AND d.consomme_le IS NULL) THEN 'unite'
  END /* accessoire_perso_sources_v1 */
$$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_source_interne(uuid) FROM PUBLIC, anon, authenticated;

-- Offre affichée au joueur (aucune écriture). Plus de liste « possédés » : l'achat n'est plus limité.
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_offre()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); p record; c record; pr public.premium_produits; v_abonne boolean; v_source text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT user_id, country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = moi;
  IF public.accessoire_club_lieu_refus_interne(p.country, p.current_city, p.current_building, p.current_room) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE country = p.country AND city = p.current_city;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'club_local_introuvable'); END IF;
  SELECT * INTO pr FROM public.premium_produits WHERE produit = 'accessoire_personnalise';
  v_abonne := public.premium_abonne_interne(p.user_id);
  v_source := public.accessoire_personnalise_source_interne(p.user_id);
  RETURN jsonb_build_object('ok', true, 'club', c.nom, 'beta', public.premium_beta_interne(), 'abonne', v_abonne,
    'source', v_source,                                   -- beta | abonnement | unite | null (achat à l'unité nécessaire)
    'inclus_disponible', v_source IN ('beta', 'abonnement'),
    'credits_unite', (SELECT count(*) FROM public.premium_droits d WHERE d.user_id = p.user_id AND d.produit = 'accessoire_personnalise'
                       AND d.revoque_le IS NULL AND d.consomme_le IS NULL),
    'prix_centimes', pr.prix_centimes,
    -- Produit tel que l'écran de paiement commun l'attend (plateau-paiement.js, confirmerAchat).
    'produit', jsonb_build_object('produit', pr.produit, 'nature', pr.nature, 'libelle', pr.libelle, 'prix_centimes', pr.prix_centimes),
    'en_cours', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'type', a.type_accessoire, 'etat', a.etat,
                   'demande', a.demande, 'source', split_part(coalesce(a.achat_id, ''), ':', 1),
                   'annulable', a.etat = 'commande' AND a.apercu_path IS NULL) ORDER BY a.cree_le), '[]'::jsonb)
                   FROM public.accessoires_personnalises a WHERE a.acheteur_nom = moi AND a.etat IN ('commande', 'apercu')));
END $$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_offre() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_offre() TO authenticated;

-- Commande : crée une commande réglée (paiement_confirme_le posé) en prenant, dans l'ordre, la bêta, le renouvellement
-- hebdomadaire de l'abonné, puis un crédit acheté à l'unité. Sinon : achat à l'unité nécessaire (« achat_unite_requis »).
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_commander(p_type text, p_demande text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); p record; c record; v_sem text := public.premium_semaine_interne();
  v_demande text := btrim(coalesce(p_demande, '')); v_id uuid := gen_random_uuid(); v_source text; v_droit bigint; v_achat text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT user_id, country, current_city, current_building, current_room INTO p
    FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  IF public.accessoire_club_lieu_refus_interne(p.country, p.current_city, p.current_building, p.current_room) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE country = p.country AND city = p.current_city;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'club_local_introuvable'); END IF;
  IF p_type IS NULL OR p_type NOT IN ('maillot', 'casquette', 'echarpe') THEN RETURN jsonb_build_object('ok', false, 'raison', 'accessoire_inconnu'); END IF;
  IF char_length(v_demande) NOT BETWEEN 3 AND 300 THEN RETURN jsonb_build_object('ok', false, 'raison', 'demande_invalide'); END IF;
  v_source := public.accessoire_personnalise_source_interne(p.user_id);
  IF v_source = 'beta' THEN
    INSERT INTO public.premium_renouvellements (user_id, semaine, type_visuel, objet, source)
    VALUES (p.user_id, v_sem, 'accessoire', v_id::text, 'beta');
    v_achat := 'beta:' || v_sem;
  ELSIF v_source = 'abonnement' THEN
    INSERT INTO public.premium_renouvellements (user_id, semaine, type_visuel, objet, source)
    VALUES (p.user_id, v_sem, 'accessoire', v_id::text, 'abonnement');
    v_achat := 'abonnement:' || v_sem;
  ELSIF v_source = 'unite' THEN
    SELECT id INTO v_droit FROM public.premium_droits WHERE user_id = p.user_id AND produit = 'accessoire_personnalise'
       AND revoque_le IS NULL AND consomme_le IS NULL ORDER BY accorde_le LIMIT 1 FOR UPDATE SKIP LOCKED;
    IF v_droit IS NULL THEN v_source := NULL; ELSE
      UPDATE public.premium_droits SET consomme_le = now(), cible = v_id::text WHERE id = v_droit;
      v_achat := 'unite:' || v_droit;
    END IF;
  END IF;
  IF v_source IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'achat_unite_requis', 'abonne', public.premium_abonne_interne(p.user_id),
      'prix_fixe', (SELECT prix_centimes IS NOT NULL FROM public.premium_produits WHERE produit = 'accessoire_personnalise'));
  END IF;
  INSERT INTO public.accessoires_personnalises (id, acheteur_user_id, acheteur_nom, pays, ville, club, type_accessoire, demande,
                                                paiement_confirme_le, achat_id)
  VALUES (v_id, p.user_id, moi, p.country, p.current_city, c.nom, p_type, v_demande, now(), v_achat);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'source', v_source); /* accessoire_perso_sources_v1 (Fred, 28/11/2026 soir) */
END $$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_commander(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_commander(text, text) TO authenticated;

-- Annulation d'une commande dont l'image n'a pas encore été créée : ce qu'elle a pris est rendu (renouvellement, crédit).
-- Dès que l'image existe (apercu_path posé par la fonction Edge), le renouvellement est consommé : plus d'annulation.
CREATE OR REPLACE FUNCTION public.accessoire_personnalise_annuler(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); a public.accessoires_personnalises%ROWTYPE; v_rendu integer := 0; v_src text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO a FROM public.accessoires_personnalises WHERE id = p_id AND acheteur_nom = moi FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'commande_introuvable'); END IF;
  v_src := split_part(coalesce(a.achat_id, ''), ':', 1);
  IF a.etat <> 'commande' OR a.apercu_path IS NOT NULL OR v_src NOT IN ('abonnement', 'beta', 'unite') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commande_non_annulable'); END IF;
  UPDATE public.accessoires_personnalises SET etat = 'annule' WHERE id = p_id;
  IF v_src IN ('abonnement', 'beta') THEN
    DELETE FROM public.premium_renouvellements WHERE user_id = a.acheteur_user_id AND source = v_src
       AND type_visuel = 'accessoire' AND objet = p_id::text;
  ELSE
    UPDATE public.premium_droits SET consomme_le = NULL, cible = NULL
     WHERE id::text = split_part(a.achat_id, ':', 2) AND user_id = a.acheteur_user_id AND produit = 'accessoire_personnalise'
       AND cible = p_id::text;
  END IF;
  GET DIAGNOSTICS v_rendu = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'source', v_src, 'rendu', v_rendu > 0, 'renouvellement_rendu', v_rendu > 0 AND v_src = 'abonnement');
END $$;
REVOKE ALL ON FUNCTION public.accessoire_personnalise_annuler(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accessoire_personnalise_annuler(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.accessoire_club_type_possede_interne(text, jsonb, text);

-- Historique des images : la fonction Edge accessoire-personnalise y écrit le type « accessoire ».
ALTER TABLE public.visuels_versions DROP CONSTRAINT IF EXISTS visuels_versions_type_visuel_check;
ALTER TABLE public.visuels_versions ADD CONSTRAINT visuels_versions_type_visuel_check
  CHECK (type_visuel = ANY (ARRAY['publicite'::text, 'commerce'::text, 'logement'::text, 'accessoire'::text]));

-- ===================================================================== 7. Commerce premium acquis dès son premier usage
-- Un abonné (hors bêta) qui dépasse un plafond gratuit de son fonds (familles ou références) acquiert le commerce premium de
-- ce fonds : premium_option_source_interne inscrit le droit (source « abonnement », paiement_stripe_v1) et note l'usage.
CREATE OR REPLACE FUNCTION public.premium_commerce_usage_noter_interne(p_fonds_id text, p_data jsonb, p_types integer, p_refs integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_user uuid := public.premium_user_de_interne(p_data ->> 'proprietaire');
BEGIN
  IF v_user IS NULL OR p_fonds_id IS NULL OR public.premium_beta_interne() OR NOT public.premium_abonne_interne(v_user) THEN RETURN; END IF;
  IF coalesce((p_data ->> 'premium')::boolean, false) THEN RETURN; END IF;
  IF coalesce(p_types, 0) <= greatest(1, coalesce((SELECT valeur::integer FROM public.entreprises_constantes WHERE cle = 'types_commerce_max_gratuit'), 2))
     AND coalesce(p_refs, 0) <= greatest(1, coalesce((SELECT valeur::integer FROM public.entreprises_constantes WHERE cle = 'references_max_gratuit'), 4)) THEN
    RETURN; END IF;
  IF EXISTS (SELECT 1 FROM public.premium_droits d WHERE d.user_id = v_user AND d.produit = 'commerce_premium' AND d.cible = p_fonds_id
              AND d.revoque_le IS NULL AND d.consomme_le IS NULL) THEN RETURN; END IF;
  PERFORM public.premium_option_source_interne(v_user, 'commerce_premium', p_fonds_id); /* commerce_premium_acquis_v1 */
END $$;
REVOKE ALL ON FUNCTION public.premium_commerce_usage_noter_interne(text, jsonb, integer, integer) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_remplacer('public.fonds_definir_types(text,text,text[])'::regprocedure,
  $a$  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;
$a$,
  $b$  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;
  -- commerce_premium_acquis_v1 (Fred, 28/11/2026 soir) : commerce premium acquis dès son premier usage par un abonné.
  PERFORM public.premium_commerce_usage_noter_interne(p_fonds_id, v_data::jsonb, coalesce(array_length(v_connus, 1), 0), NULL);
$b$,
  'commerce_premium_acquis_v1');

SELECT pg_temp.rp_remplacer('public.fonds_reference_creer(text,text,text,text,text,text)'::regprocedure,
  $a$  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;
$a$,
  $b$  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;
  -- commerce_premium_acquis_v1 (Fred, 28/11/2026 soir) : commerce premium acquis dès son premier usage par un abonné.
  PERFORM public.premium_commerce_usage_noter_interne(p_fonds_id, v_data::jsonb, NULL, v_n + 1);
$b$,
  'commerce_premium_acquis_v1');

NOTIFY pgrst, 'reload schema';
COMMIT;
