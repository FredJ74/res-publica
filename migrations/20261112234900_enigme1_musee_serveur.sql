-- Enquête du musée de la Ville de Luthécia : départ lisible (décisions de Fred, 13/11/2026, 0 h 46-0 h 48).
-- 1. Hall : pendant l'enquête, Valérie Loisillon accueille le joueur UNE fois (s'excuse de la visite amputée).
-- 2. Salles des Maires, des Criminels, des Entrepreneurs, des Plumes : ordre gratuit « Examiner le cadre vide ».
-- 3. Chaque cadre examiné ajoute au calepin « Musée : portrait manquant de … » (une ligne par salle).
-- 4. Le débarras (révélation de Gérard Poinçon) : la résolution est décidée ici, plus par l'écran.
-- Le serveur juge le lieu, l'étape de l'enquête et la possession de la clé ; l'écran adopte `enigme`.
-- Idempotente (CREATE OR REPLACE) ; aucune donnée de joueur modifiée à l'application.
CREATE OR REPLACE FUNCTION public.enigme1_musee(p_action text, p_salle text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a public.personnages_donnees; e jsonb; cadres jsonb; premiere boolean := false; nouveau boolean := false;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_action IS NULL OR p_action NOT IN ('accueil', 'examiner', 'debarras') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commande_invalide'); END IF;
  e := CASE WHEN jsonb_typeof(a.enigme1) = 'object' THEN a.enigme1 ELSE '{"etape":"non_commencee","variante":null}'::jsonb END;
  IF (a.country, a.current_city, a.current_building) IS DISTINCT FROM ('republic', 'capitale', 'musee-ville-luthecia') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place', 'enigme', e); END IF;

  IF p_action = 'accueil' THEN
    IF a.current_room IS DISTINCT FROM 'hall' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place', 'enigme', e); END IF;
    IF e->>'etape' NOT IN ('declenchee', 'relancee') THEN RETURN jsonb_build_object('ok', true, 'premiere', false, 'enigme', e); END IF;
    IF NOT coalesce((e->>'accueilValerie')::boolean, false) THEN
      e := e || jsonb_build_object('accueilValerie', true); premiere := true;
      UPDATE public.personnages_donnees SET enigme1 = e, updated_at = now() WHERE name = a.name;
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
