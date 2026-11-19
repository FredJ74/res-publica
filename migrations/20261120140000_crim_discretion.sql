-- CRIMINALITÉ — correctifs de discrétion du 20/11/2026 (décidés par Fred ; GAME-DESIGN-CRIMINALITE.md § 1).
-- 1. Rapports de combat : un participant masqué n'est jamais nommé ; il est « Individu masqué n°X », avec le même numéro que
--    dans la liste des présents (crim_presents). Le moteur de combat ne change pas :
--    • numérotation commune crim_masques_piece_interne(pays, ville, bâtiment, pièce), indépendante de celui qui regarde,
--      utilisée par crim_presents et par crim_designation_interne(nom) ;
--    • crim_combat_ouvrir_interne fige à l'ouverture les désignations des masqués engagés (batailles.contexte.crim_designations,
--      raccord crim_designations_v1) ;
--    • lecture : militaire_bataille_etat nomme l'adversaire d'un combat civil par crim_designation_bataille_interne
--      (raccords crim_designation_adversaire_v1 / crim_designation_chef_v1) ;
--    • batailles, batailles_engagements, batailles_groupes ne sont plus lisibles directement par l'API (ils portent les vrais
--      noms : leader_a, contexte.acteur, personnage) ; l'écran passe uniquement par les RPC militaire_*.
-- 2. Fiche d'un masqué : aucune RPC sociale (conversation, groupe, courrier) n'accepte de jeton de masqué ; correctif écran seul.
-- 3. Vue personnages : position (current_city, current_building, current_room) masquée pour les autres joueurs, comme
--    l'inventaire. Lisible par le propriétaire, la clé de service et le code serveur (fonctions SECURITY DEFINER : current_user
--    n'y est plus anon/authenticated). resources = {dis, inf, pop} : pas d'inventaire ni d'argent, laissé tel quel.
--    Politique personnages_lecture de personnages_donnees resserrée à la ligne du propriétaire (table non accordée à l'API).

-- ── 1. Numérotation commune des masqués d'une pièce ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_masques_piece_interne(p_pays text, p_ville text, p_bat text, p_piece text)
RETURNS TABLE (nom text, numero integer) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p.name, (row_number() OVER (ORDER BY md5(p.name || p_bat || p_piece)))::integer
    FROM public.presences p
   WHERE p.country = p_pays AND p.city = p_ville AND p.building_id = p_bat AND p.room_id = p_piece
     AND p.updated_at > now() - interval '5 minutes'
     AND public.crim_masque_interne(p.name) AND NOT public.crim_cache_interne(p.name);
$$;

-- Désignation publique d'un PJ : son nom, ou « Individu masqué n°X » (numéro de sa pièce actuelle) s'il est masqué.
CREATE OR REPLACE FUNCTION public.crim_designation_interne(p_nom text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; n integer;
BEGIN
  IF p_nom IS NULL OR NOT public.crim_masque_interne(p_nom) THEN RETURN p_nom; END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = p_nom;
  SELECT m.numero INTO n FROM public.crim_masques_piece_interne(d.country, d.current_city, d.current_building, d.current_room) m
   WHERE m.nom = p_nom;
  RETURN 'Individu masqué' || coalesce(' n°' || n, '');
END $$;

-- Désignations figées des masqués engagés dans une bataille (numéros de la pièce du combat).
CREATE OR REPLACE FUNCTION public.crim_designations_bataille_interne(p_bataille bigint)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(jsonb_object_agg(e.personnage, 'Individu masqué' || coalesce(' n°' || m.numero, '')), '{}'::jsonb)
    FROM public.batailles b
    JOIN public.batailles_engagements e ON e.bataille_id = b.id AND e.personnage IS NOT NULL
    LEFT JOIN public.crim_masques_piece_interne(b.pays, b.ville, b.batiment, b.piece) m ON m.nom = e.personnage
   WHERE b.id = p_bataille AND public.crim_masque_interne(e.personnage);
$$;

-- Lecture d'un nom dans un rapport de combat : désignation figée, sinon désignation actuelle.
CREATE OR REPLACE FUNCTION public.crim_designation_bataille_interne(p_bataille bigint, p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT b.contexte -> 'crim_designations' ->> p_nom FROM public.batailles b WHERE b.id = p_bataille),
                  public.crim_designation_interne(p_nom));
$$;

-- Présents : même affichage qu'avant, numérotation désormais commune (le numéro ne dépend plus de qui regarde).
CREATE OR REPLACE FUNCTION public.crim_presents()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = a;
  IF coalesce(d.current_building, '') = '' OR coalesce(d.current_room, '') = '' THEN RETURN jsonb_build_object('ok', true, 'presents', '[]'::jsonb); END IF;
  WITH m AS (
    SELECT * FROM public.crim_masques_piece_interne(d.country, d.current_city, d.current_building, d.current_room)
  ), pr AS (
    SELECT p.name, p.updated_at, p.groupe_pnj,
           (p.name <> a AND public.crim_cache_interne(p.name)) AS cache,
           CASE WHEN p.name <> a THEN m.numero END AS numero
      FROM public.presences p LEFT JOIN m ON m.nom = p.name
     WHERE p.country = d.country AND p.city = d.current_city AND p.building_id = d.current_building AND p.room_id = d.current_room
       AND p.updated_at > now() - interval '5 minutes'
  ), vis AS (
    SELECT pr.*, (numero IS NOT NULL) AS masque FROM pr WHERE NOT cache
  )
  SELECT coalesce(jsonb_agg(CASE WHEN masque THEN
           jsonb_build_object('name', 'Individu masqué n°' || numero, 'masque', true, 'numero', numero, 'updated_at', updated_at,
                              'jeton', (SELECT jeton FROM public.crim_jetons_masque j WHERE j.personnage = vis.name),
                              'groupe_pnj', (SELECT coalesce(jsonb_agg(g - 'photoUrl'), '[]'::jsonb)
                                               FROM jsonb_array_elements(CASE WHEN jsonb_typeof(groupe_pnj) = 'array' THEN groupe_pnj ELSE '[]'::jsonb END) g))
         ELSE jsonb_build_object('name', name, 'masque', false, 'updated_at', updated_at, 'groupe_pnj', groupe_pnj) END
         ORDER BY masque, numero, name), '[]'::jsonb)
    INTO v FROM vis;
  RETURN jsonb_build_object('ok', true, 'presents', v, 'mode', public.crim_mode_action_interne(a));
END $$;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Ouverture commune (Neutraliser, vol, cambriolage) : désignations figées des masqués engagés.
SELECT pg_temp.rp_raccorder('public.crim_combat_ouvrir_interne(text,jsonb,jsonb,text,uuid)'::regprocedure,
  $a$jsonb_build_object('crim_affaire', (r ->> 'affaire')::bigint, 'crim_mode', r ->> 'mode')$a$,
  $b$jsonb_build_object('crim_affaire', (r ->> 'affaire')::bigint, 'crim_mode', r ->> 'mode',
             'crim_designations', public.crim_designations_bataille_interne((v_comb ->> 'bataille')::bigint)) /* crim_designations_v1 */$b$,
  'crim_designations_v1');

-- Lecture du rapport : l'adversaire d'un combat civil est nommé par sa désignation (masqué → « Individu masqué n°X »).
SELECT pg_temp.rp_raccorder('public.militaire_bataille_etat(bigint)'::regprocedure,
  $a$'adversaire_nom', CASE WHEN b.contexte->>'type' IN ('faune','garde_acces') THEN (SELECT m.nom FROM public.pnj_membres m WHERE m.id = b.contexte->>'cible') END,$a$,
  $b$'adversaire_nom', CASE WHEN b.contexte->>'type' IN ('faune','garde_acces') THEN (SELECT m.nom FROM public.pnj_membres m WHERE m.id = b.contexte->>'cible')
      WHEN b.contexte->>'type' = 'civil' THEN coalesce(
        public.crim_designation_bataille_interne(b.id, CASE WHEN v_camp = b.camp_a THEN b.leader_b ELSE b.leader_a END),
        (SELECT m.nom FROM public.pnj_membres m WHERE m.id = b.contexte->>'cible')) END, /* crim_designation_adversaire_v1 */$b$,
  'crim_designation_adversaire_v1');

SELECT pg_temp.rp_raccorder('public.militaire_bataille_etat(bigint)'::regprocedure,
  $a$'mon_chef', g.leader,$a$,
  $b$'mon_chef', CASE WHEN g.leader = v_moi THEN g.leader ELSE public.crim_designation_bataille_interne(b.id, g.leader) END, /* crim_designation_chef_v1 */$b$,
  'crim_designation_chef_v1');

-- Les tables de bataille portent les vrais noms : plus de lecture directe par l'API (aucun écran ne les lit).
REVOKE SELECT ON public.batailles, public.batailles_engagements, public.batailles_groupes FROM anon, authenticated;

-- ── 3. Vue personnages : position masquée pour les autres joueurs ─────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.personnages AS
 SELECT id,
    name,
    country,
    photo_url,
    bio,
    archetype,
    career,
    origin,
    school,
    free_pts_restants,
    stats,
    resources,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN arg
            ELSE NULL::integer
        END AS arg,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN liquide
            ELSE NULL::integer
        END AS liquide,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN banque
            ELSE NULL::integer
        END AS banque,
    hp,
    pa,
    moral,
    poste,
    poste_depute,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() OR CURRENT_USER NOT IN ('anon', 'authenticated') THEN current_city
            ELSE NULL::text
        END AS current_city,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() OR CURRENT_USER NOT IN ('anon', 'authenticated') THEN current_building
            ELSE NULL::text
        END AS current_building,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() OR CURRENT_USER NOT IN ('anon', 'authenticated') THEN current_room
            ELSE NULL::text
        END AS current_room,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN inventory
            ELSE NULL::jsonb
        END AS inventory,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN informateurs
            ELSE NULL::jsonb
        END AS informateurs,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN contacts
            ELSE NULL::jsonb
        END AS contacts,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN historique_crimes
            ELSE NULL::jsonb
        END AS historique_crimes,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN enquetes_en_cours
            ELSE NULL::jsonb
        END AS enquetes_en_cours,
    domicile,
    employes,
    escort_active,
    locations_actives,
    poison_actif,
    day,
    recherche,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN reputation_criminelle
            ELSE NULL::integer
        END AS reputation_criminelle,
    salutations_du_jour,
    invitation_sociale_en_attente,
    convocations,
    est_emprisonne,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN detention_qhs
            ELSE NULL::jsonb
        END AS detention_qhs,
    hospitalisation,
    stats_affaiblies,
    regen_jour,
    requisition,
    demandeur_emploi,
    carte_postale_moral_jour,
    motto,
    licence_sportive,
    performance_sportive,
    blessure_sportive,
    signature_html,
    signature_blocks,
    quete_accueil,
    enigme1,
    maxence,
    succes_maxence,
        CASE
            WHEN user_id = auth.uid() OR est_appel_serveur() THEN journal
            ELSE NULL::jsonb
        END AS journal,
    excommunie,
    reservation_hotel,
    qualifications,
    effets_actifs,
    bonus_lobbyiste,
    dernier_dormir,
    salaire_touche,
    dernier_objet_trouve_jour,
    photo_pos,
    user_id,
    created_at,
    updated_at,
    quete_carriere,
    NULL::jsonb AS fiche_base,
    nationalite
   FROM personnages_donnees d;

-- personnages_donnees n'est pas accordée à l'API ; sa politique de lecture se limite désormais à la ligne du propriétaire.
ALTER POLICY personnages_lecture ON public.personnages_donnees USING (user_id = auth.uid());

-- ── Droits ──────────────────────────────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['crim_masques_piece_interne(text,text,text,text)', 'crim_designation_interne(text)',
    'crim_designations_bataille_interne(bigint)', 'crim_designation_bataille_interne(bigint,text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
END $$;
