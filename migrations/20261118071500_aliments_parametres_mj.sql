-- MALADIES — LOT 2b : réglages du MJ pour les aliments (péremption, détection à la réception, prix des bandelettes).
-- « Qui peut le plus peut le moins » : le MJ lit et modifie chaque paramètre ; chaque modification est journalisée.
BEGIN;

CREATE OR REPLACE FUNCTION public.admin_aliments_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true, 'parametres',
    (SELECT coalesce(jsonb_object_agg(cle, valeur), '{}'::jsonb) FROM public.aliments_parametres));
END $$;

CREATE OR REPLACE FUNCTION public.admin_aliment_modifier(p_cle text, p_valeur numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  IF p_cle NOT IN ('peremption_jours', 'detection_base', 'detection_bandelette', 'prix_bandelette') OR p_valeur IS NULL OR p_valeur < 0
     OR (p_cle LIKE 'detection_%' AND p_valeur > 100) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  INSERT INTO public.aliments_parametres (cle, valeur) VALUES (p_cle, p_valeur)
  ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, ok)
  VALUES (auth.uid(), 'MJ', 'aliment_modifier', jsonb_build_object('cle', p_cle, 'valeur', p_valeur), true);
  RETURN jsonb_build_object('ok', true, 'cle', p_cle, 'valeur', p_valeur);
END $$;

REVOKE ALL ON FUNCTION public.admin_aliments_lire(), public.admin_aliment_modifier(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_aliments_lire(), public.admin_aliment_modifier(text, numeric) TO authenticated;

COMMIT;
