-- Musée de Luthécia : l'accueil de Valérie ne doit plus être consommé sans affichage.
-- Cas Angie : l'ancien flag accueilValerie est vrai, mais l'introduction ne s'est pas affichée.
-- Le nouveau marqueur est confirmé volontairement après lecture du dialogue.
-- Ne touche ni au reste de l'énigme ni aux personnages à la migration.
CREATE OR REPLACE FUNCTION public.enigme1_musee(p_action text, p_salle text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a public.personnages_donnees; e jsonb; cadres jsonb; premiere boolean := false; nouveau boolean := false;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_action IS NULL OR p_action NOT IN ('accueil', 'accueil_confirmer', 'examiner', 'debarras') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commande_invalide'); END IF;
  e := CASE WHEN jsonb_typeof(a.enigme1) = 'object' THEN a.enigme1 ELSE '{"etape":"non_commencee","variante":null}'::jsonb END;
  IF (a.country, a.current_city, a.current_building) IS DISTINCT FROM ('republic', 'capitale', 'musee-ville-luthecia') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place', 'enigme', e); END IF;

  IF p_action = 'accueil' THEN
    IF a.current_room IS DISTINCT FROM 'hall' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place', 'enigme', e); END IF;
    IF e->>'etape' NOT IN ('declenchee', 'relancee') THEN
      RETURN jsonb_build_object('ok', true, 'premiere', false, 'enigme', e); END IF;
    -- Une ancienne version du client posait accueilValerie=true AVANT l'affichage.
    -- Cette marque historique ne prouve donc pas que le joueur ait vu l'introduction.
    -- Le nouvel accueilValerieConfirme est fixé uniquement par une action explicite.
    RETURN jsonb_build_object('ok', true,
      'premiere', NOT coalesce((e->>'accueilValerieConfirme')::boolean, false),
      'enigme', e);

  ELSIF p_action = 'accueil_confirmer' THEN
    IF a.current_room IS DISTINCT FROM 'hall' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place', 'enigme', e); END IF;
    IF e->>'etape' NOT IN ('declenchee', 'relancee') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'enquete_inactive', 'enigme', e); END IF;
    IF NOT coalesce((e->>'accueilValerieConfirme')::boolean, false) THEN
      e := e || jsonb_build_object('accueilValerie', true,
                                   'accueilValerieConfirme', true);
      UPDATE public.personnages_donnees SET enigme1 = e, updated_at = now()
        WHERE name = a.name;
      premiere := true;
    END IF;
    RETURN jsonb_build_object('ok', true, 'premiere', premiere, 'enigme', e);

  ELSIF p_action = 'examiner' THEN
    IF p_salle IS NULL OR p_salle NOT IN ('salle_maires', 'salle_criminels', 'salle_entrepreneurs', 'salle_plumes') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'commande_invalide'); END IF;
    IF a.current_room IS DISTINCT FROM p_salle THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place', 'enigme', e); END IF;
    IF e->>'etape' NOT IN ('declenchee', 'relancee') THEN RETURN jsonb_build_object('ok', false, 'raison', 'enquete_inactive', 'enigme', e); END IF;
    cadres := CASE WHEN jsonb_typeof(e->'cadresVus') = 'array' THEN e->'cadresVus' ELSE '[]'::jsonb END;
    IF NOT cadres ? p_salle THEN
      e := e || jsonb_build_object('cadresVus', cadres || to_jsonb(p_salle)); nouveau := true;
      UPDATE public.personnages_donnees SET enigme1 = e, updated_at = now() WHERE name = a.name;
    END IF;
    RETURN jsonb_build_object('ok', true, 'nouveau', nouveau, 'salle', p_salle, 'enigme', e);

  ELSE -- débarras
    IF a.current_room IS DISTINCT FROM 'debarras' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place', 'enigme', e); END IF;
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(a.inventory) = 'array' THEN a.inventory ELSE '[]'::jsonb END) i
                   WHERE i->>'id' = 'cle-debarras-musee') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'porte_fermee_a_cle', 'enigme', e); END IF;
    IF coalesce((e->>'debarrasOuvert')::boolean, false) OR e->>'etape' = 'resolue' THEN
      RETURN jsonb_build_object('ok', true, 'premiere', false, 'enigme', e); END IF;
    IF e->>'etape' NOT IN ('declenchee', 'relancee') THEN RETURN jsonb_build_object('ok', false, 'raison', 'enquete_inactive', 'enigme', e); END IF;
    e := e || jsonb_build_object('etape', 'resolue', 'debarrasOuvert', true, 'resolueLe', now());
    UPDATE public.personnages_donnees SET enigme1 = e, updated_at = now() WHERE name = a.name;
    RETURN jsonb_build_object('ok', true, 'premiere', true, 'enigme', e);
  END IF;
END $$;


REVOKE ALL ON FUNCTION public.enigme1_musee(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enigme1_musee(text, text) TO authenticated;
