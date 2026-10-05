-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926131732
-- Nom original      : socle_pnj_primitives
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 13:17:32 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 860c06eec1d7e4336a7c3bac49b0a123
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
-- PRIMITIVES GENERIQUES DU SOCLE PNJ -- 26 septembre 2026
-- Aucune d'elles ne decide d'une regle metier. Elles exposent des capacites.

-- LA PRIMITIVE DE POSITION. Elle remplace 5 recopies SQL et 2 predicats clients.
-- Aucune copie synchronisee a chaque deplacement : le wagon est a la position de sa
-- locomotive. Profondeur bornee a 1 par l'invariant I6 -> deux LEFT JOIN, pas de recursion.
CREATE OR REPLACE FUNCTION public.pnj_position_effective(p_id text)
RETURNS TABLE(pays text, ville text, building_id text, room_id text,
              rue_noeud_id text, porte boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT m.pays,
    CASE WHEN m.leader_pj IS NOT NULL THEN d.current_city
         WHEN m.leader_pnj_id IS NOT NULL THEN l.ville ELSE m.ville END,
    CASE WHEN m.leader_pj IS NOT NULL THEN d.current_building
         WHEN m.leader_pnj_id IS NOT NULL THEN l.building_id ELSE m.building_id END,
    CASE WHEN m.leader_pj IS NOT NULL THEN d.current_room
         WHEN m.leader_pnj_id IS NOT NULL THEN l.room_id ELSE m.room_id END,
    CASE WHEN m.leader_pj IS NOT NULL THEN NULL
         WHEN m.leader_pnj_id IS NOT NULL THEN l.rue_noeud_id ELSE m.rue_noeud_id END,
    (m.leader_pj IS NOT NULL OR m.leader_pnj_id IS NOT NULL)
  FROM public.pnj_membres m
  LEFT JOIN public.personnages_donnees d ON d.name = m.leader_pj
  LEFT JOIN public.pnj_membres         l ON l.id   = m.leader_pnj_id
  WHERE m.id = p_id;
$$;

-- LE TITULAIRE D'UN POSTE : resolu, jamais stocke. NULL = poste vacant, ce qui veut dire
-- « personne ne peut administrer ces PNJ aujourd'hui », jamais « ils n'existent plus ».
CREATE OR REPLACE FUNCTION public.pnj_titulaire_du_poste(
  p_pays text, p_poste text, p_ville text DEFAULT NULL)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT d.name FROM public.personnages_donnees d
   WHERE d.country = p_pays AND d.poste->>'id' = p_poste
     AND (p_ville IS NULL OR d.poste->>'city' = p_ville)
   LIMIT 1;
$$;

-- QUI PEUT ADMINISTRER CE PNJ : son proprietaire personnel, ou le titulaire du poste
-- proprietaire. NULL si le poste est vacant.
CREATE OR REPLACE FUNCTION public.pnj_administrateur(p_id text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN m.proprietaire_pj IS NOT NULL THEN m.proprietaire_pj
    ELSE public.pnj_titulaire_du_poste(m.pays, m.proprietaire_poste, m.proprietaire_poste_ville) END
  FROM public.pnj_membres m WHERE m.id = p_id;
$$;

-- MORT GENERIQUE. Fige la position, tue, delie, depose au sol, informe le proprietaire.
-- SERVEUR SEUL : c'est le metier qui decide qu'un PNJ meurt, jamais le client.
CREATE OR REPLACE FUNCTION public.pnj_mourir(p_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m record; pe record; v_n integer := 0; o record;
BEGIN
  SELECT * INTO m FROM public.pnj_membres WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF m.statut = 'mort' THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_mort', 'deposes', 0); END IF;

  SELECT * INTO pe FROM public.pnj_position_effective(p_id);

  -- Delier AVANT d'ecrire la position propre : I1 interdit les deux a la fois.
  UPDATE public.pnj_membres
     SET statut = 'mort', leader_pj = NULL, leader_pnj_id = NULL,
         ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
   WHERE id = p_id;

  -- Possessions au sol, une ligne par objet, dans la table canonique deja utilisee par le jeu.
  -- On ne reutilise PAS la RPC inventaire_abandonner : elle exige exiger_acteur (un PNJ n'est
  -- pas un acteur), lit l'inventaire d'un PJ et refuse un lieu vide.
  -- Une position de rue est encodee comme le jeu le fait deja : building 'rue-centrale'.
  FOR o IN SELECT * FROM public.pnj_possessions WHERE pnj_id = p_id LOOP
    INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
    VALUES ('objet-abandonne-' || replace(gen_random_uuid()::text, '-', ''),
            pe.pays, COALESCE(pe.ville, 'inconnue'),
            COALESCE(pe.building_id, 'rue-centrale'),
            COALESCE(pe.room_id, COALESCE(pe.rue_noeud_id, 'inconnu')),
            (o.objet || jsonb_build_object('id',
               'objet-abandonne-' || replace(gen_random_uuid()::text, '-', '')))::text);
    v_n := v_n + 1;
  END LOOP;
  DELETE FROM public.pnj_possessions WHERE pnj_id = p_id;

  INSERT INTO public.pnj_evenements (pnj_id, pnj_nom, famille, type, pays, proprietaire_pj,
      proprietaire_poste, proprietaire_poste_ville, ville, building_id, room_id)
  VALUES (m.id, m.nom, m.famille, 'mort', m.pays, m.proprietaire_pj, m.proprietaire_poste,
      m.proprietaire_poste_ville, pe.ville, pe.building_id, pe.room_id);

  RETURN jsonb_build_object('ok', true, 'deposes', v_n, 'ville', pe.ville,
                            'building_id', pe.building_id, 'room_id', pe.room_id);
END; $$;

-- PRIMITIVE DE DEBIT DE PA. FOURNIE par le socle, APPELEE PAR LE METIER -- le socle ne
-- l'appelle jamais de lui-meme. Suivre son leader, se deplacer, changer de groupe : aucun
-- cout. pnj_suivre_leader() n'est jamais pnj_perdre_pa().
-- Elle borne a 0 (jamais de PA negatifs) et declenche la mort generique a 0.
CREATE OR REPLACE FUNCTION public.pnj_pa_debiter(p_ids text[], p_cout integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; v_morts integer := 0; v_touches integer := 0; v_reste integer;
BEGIN
  IF p_cout IS NULL OR p_cout < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_invalide'); END IF;
  FOR r IN SELECT id, pa FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    v_reste := greatest(0, r.pa - p_cout);
    UPDATE public.pnj_membres SET pa = v_reste WHERE id = r.id;
    v_touches := v_touches + 1;
    IF v_reste = 0 THEN PERFORM public.pnj_mourir(r.id); v_morts := v_morts + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'touches', v_touches, 'morts', v_morts);
END; $$;

-- QUI EST ICI : remplace militaire_detachement_ici, agents_couverture_ici et les predicats
-- clients de la police. Un seul endroit resout la presence.
CREATE OR REPLACE FUNCTION public.pnj_membres_ici(
  p_pays text, p_ville text, p_building text, p_room text, p_rue_noeud text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', m.id, 'nom', m.nom, 'famille', m.famille, 'pa', m.pa,
           'liquide', m.liquide, 'statut', m.statut,
           'leader_pj', m.leader_pj, 'leader_pnj_id', m.leader_pnj_id,
           'porte', pe.porte,
           'proprietaire_pj', m.proprietaire_pj,
           'proprietaire_poste', m.proprietaire_poste) ORDER BY m.id), '[]'::jsonb)
    FROM public.pnj_membres m
    JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
   WHERE m.statut = 'actif' AND pe.pays = p_pays
     AND pe.ville IS NOT DISTINCT FROM p_ville
     AND pe.building_id IS NOT DISTINCT FROM p_building
     AND pe.room_id IS NOT DISTINCT FROM p_room
     AND (p_rue_noeud IS NULL OR pe.rue_noeud_id IS NOT DISTINCT FROM p_rue_noeud);
$$;

REVOKE ALL ON FUNCTION public.pnj_mourir(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_debiter(text[], integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_mourir(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_pa_debiter(text[], integer) TO service_role;

REVOKE ALL ON FUNCTION public.pnj_position_effective(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_titulaire_du_poste(text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_administrateur(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pnj_membres_ici(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pnj_position_effective(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_titulaire_du_poste(text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_administrateur(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pnj_membres_ici(text, text, text, text, text) TO authenticated, service_role;