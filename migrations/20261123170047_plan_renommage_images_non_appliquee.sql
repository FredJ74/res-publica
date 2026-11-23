-- NON APPLIQUÉE — plan de renommage des images, 23/11/2026.
-- Aucun fichier renommé. Ne pas exécuter avant livraison et contrôle des nouvelles URL.
-- Inventaire source du 22/11 : 12 occurrences ; recompter sur la base actuelle avant application.
-- Chaînes entières uniquement ; aucun texte narratif, quantité, PA ou règle de jeu modifié.
-- Le verrou explicite protège contre une application avant le futur chantier coordonné.
DO $images$
DECLARE r record;
BEGIN
  IF current_setting('human_gambit.renommage_images_valide', true) IS DISTINCT FROM 'oui' THEN
    RAISE EXCEPTION 'NON APPLIQUÉE : renommage des fichiers et contrôle public préalables requis';
  END IF;
  FOR r IN SELECT * FROM (VALUES
    ('personnages_donnees','inventory','jsonb','images/Sovarka/Krasnov/Krasnov_place_ours.webp','images/sovarka/krasnov/krasnov-place-ours.webp'),
    ('recettes_commerce','image','text','images/Sovarka/Krasnov/Krasnov_place_ours.webp','images/sovarka/krasnov/krasnov-place-ours.webp'),
    ('climat_points_eau','image','text','images/Sovarka/Krasnov/Krasnov_place_ours_fontaine.webp','images/sovarka/krasnov/krasnov-place-ours-fontaine.webp'),
    ('camions_militaires','image_url','text','images/Sovarka/Novomirsk/Novomirsk_camion_NAZ66_interieur.webp','images/sovarka/novomirsk/novomirsk-camion-naz66-interieur.webp'),
    ('escorts_catalogue','portrait','text','images/Sovarka/Novomirsk/Sovarka_escort_Boris_Kostof.webp','images/sovarka/novomirsk/sovarka-escort-boris-kostof.webp'),
    ('escorts_catalogue','vignette','text','images/Sovarka/Novomirsk/Sovarka_escort_Boris_Kostof_vignette.webp','images/sovarka/novomirsk/sovarka-escort-boris-kostof-vignette.webp'),
    ('escorts_catalogue','portrait','text','images/Sovarka/Novomirsk/Sovarka_escort_Ludmilla_Bonaskova.webp','images/sovarka/novomirsk/sovarka-escort-ludmilla-bonaskova.webp'),
    ('escorts_catalogue','vignette','text','images/Sovarka/Novomirsk/Sovarka_escort_Ludmilla_Bonaskova_vignette.webp','images/sovarka/novomirsk/sovarka-escort-ludmilla-bonaskova-vignette.webp'),
    ('escorts_catalogue','portrait','text','images/personnages/Clinique_escort_Boris.webp','images/personnages/clinique-escort-boris.webp'),
    ('escorts_catalogue','vignette','text','images/personnages/Clinique_escort_Boris_vignette.webp','images/personnages/clinique-escort-boris-vignette.webp'),
    ('escorts_catalogue','portrait','text','images/personnages/Clinique_escort_Irina.webp','images/personnages/clinique-escort-irina.webp'),
    ('escorts_catalogue','vignette','text','images/personnages/Clinique_escort_Irina_vignette.webp','images/personnages/clinique-escort-irina-vignette.webp')
  ) AS corrections(table_name, column_name, column_type, ancienne, nouvelle)
  LOOP
    IF r.column_type = 'text' THEN
      EXECUTE format('UPDATE public.%I SET %I = $2 WHERE %I = $1',
        r.table_name, r.column_name, r.column_name) USING r.ancienne, r.nouvelle;
    ELSE
      EXECUTE format('UPDATE public.%I SET %I = replace(%I::text,to_jsonb($1::text)::text,to_jsonb($2::text)::text)::jsonb WHERE strpos(%I::text,to_jsonb($1::text)::text) > 0',
        r.table_name, r.column_name, r.column_name, r.column_name) USING r.ancienne, r.nouvelle;
    END IF;
  END LOOP;
END
$images$;
