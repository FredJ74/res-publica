-- #219 : mêmes droits publics et même requête judiciaire, porte interne privée.
DO $prevol$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='public.justice_recherches(text)'::regprocedure)
 NOT IN ('cf59bce0728d889c21a8be912a8d9340','4c94219d69d9cb89f573777e1e96a6d3') THEN RAISE EXCEPTION 'recherches_vivantes_non_examinees';END IF;
 IF to_regprocedure('public.douane_recherches_interne(text)') IS NOT NULL
 AND (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.douane_recherches_interne(text)'))<>'d0a48e3bd14edefbbc643eb89815a9c7'
 THEN RAISE EXCEPTION 'recherches_internes_non_examinees';END IF;
END $prevol$;
CREATE OR REPLACE FUNCTION public.douane_recherches_interne(p_nom text)
 RETURNS TABLE(id text, country text, ville_condamnation text, motif text, jours integer, data jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- `motif_allegue` EST RETIRE DE CE QUI SORT (13 octobre 2026). C'est le texte libre du
  -- plaignant, recopie sur la condamnation depuis le dossier : il n'a rien a faire sur un avis de
  -- recherche, que l'autorite lit pour savoir QUI chercher, pour QUELLE qualification, OU et
  -- pour COMBIEN de jours. Le retrait est inconditionnel -- meme pour la personne recherchee
  -- elle-meme, qui lit le texte du plaignant sur SON dossier par sa propre porte, pas ici.
  RETURN QUERY
    SELECT j.id, j.country, j.city, j.motif,
           coalesce((SELECT sum((m->>'jours')::int)
                       FROM jsonb_array_elements(coalesce(j.data->'motifs', '[]'::jsonb)) m), 0)::int,
           (j.data - 'motif_allegue')
      FROM public.jugements j
     WHERE j.accuse = p_nom AND j.executee = false
     ORDER BY j.created_at;
END;
$function$;
REVOKE ALL ON FUNCTION public.douane_recherches_interne(text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.justice_recherches(p_nom text)
 RETURNS TABLE(id text, country text, ville_condamnation text, motif text, jours integer, data jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_autorise boolean := false;
BEGIN
  IF public.est_appel_serveur() THEN
    v_autorise := true;
  ELSE
    v_moi := public.mon_personnage();
    IF v_moi IS NOT NULL THEN
      -- Soi-meme : un joueur peut savoir qu'il est recherche.
      IF v_moi = p_nom THEN
        v_autorise := true;
      ELSE
        -- Autorite judiciaire, dans son propre pays.
        SELECT true INTO v_autorise
          FROM public.acteur_poste_courant() a
          JOIN public.personnages_donnees c ON c.name = p_nom
         WHERE a.poste_id IN ('commissaire','juge','min_just','min_int','president')
           AND a.pays = c.country
         LIMIT 1;
      END IF;
    END IF;
  END IF;

  IF NOT coalesce(v_autorise, false) THEN RETURN; END IF;

  -- `motif_allegue` EST RETIRE DE CE QUI SORT (13 octobre 2026). C'est le texte libre du
  -- plaignant, recopie sur la condamnation depuis le dossier : il n'a rien a faire sur un avis de
  -- recherche, que l'autorite lit pour savoir QUI chercher, pour QUELLE qualification, OU et
  -- pour COMBIEN de jours. Le retrait est inconditionnel -- meme pour la personne recherchee
  -- elle-meme, qui lit le texte du plaignant sur SON dossier par sa propre porte, pas ici.
  RETURN QUERY SELECT * FROM public.douane_recherches_interne(p_nom);
END;
$function$;
