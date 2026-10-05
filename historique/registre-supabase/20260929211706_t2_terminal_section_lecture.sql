-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260929211706
-- Nom original      : t2_terminal_section_lecture
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-29 21:17:06 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 652dce0dd31cc6df203ed73fa34183b5
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
create or replace function public.militaire_objet_signature(p_objet jsonb)
returns text language sql immutable as $fn$
  SELECT lower(btrim(coalesce(nullif(btrim(coalesce(p_objet->>'produitMilitaire','')), ''),
                              p_objet->>'name', '?')))
      || '|' || lower(coalesce(p_objet->>'type', ''));
$fn$;

comment on function public.militaire_objet_signature(jsonb) is
  'Signature d''interchangeabilite d''un objet : coalesce(produitMilitaire, name) + type, la meme convention que militaire_armes_bonus utilise pour reconnaitre une arme. Deux objets de meme signature sont comptables ensemble ; c''est ce qui permet de transferer N unites sans exiger que les objets soient empilables.';

create or replace function public.militaire_unites_objet(p_objet jsonb)
returns integer language sql immutable as $fn$
  SELECT greatest(1, floor(coalesce((p_objet->>'qty')::numeric, 1))::integer);
$fn$;

create or replace function public.militaire_terminal_section()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_pa_max          constant integer := 12;
  c_par_tente       constant integer := 13;
  c_max_ration_jour constant integer := 2;
  g record; v_sec jsonb; v_jour text;
  v_ville text; v_bat text; v_room text; v_pays text;
  v_radio_moi boolean; v_tentes integer; v_pj_groupe integer;
  v_soldats jsonb; v_inv jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(g.o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = g.o_section;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  SELECT country, current_city, current_building, current_room
    INTO v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;

  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
           jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                     THEN pd.inventory ELSE '[]'::jsonb END) i
           WHERE pd.name = g.o_moi AND i->>'produitMilitaire' = 'radio') INTO v_radio_moi;

  SELECT coalesce((
    SELECT count(*) FROM public.personnages_donnees pd,
           jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                     THEN pd.inventory ELSE '[]'::jsonb END) i
     WHERE i->>'produitMilitaire' = 'tente'
       AND (pd.name = g.o_moi
            OR (pd.current_city = v_ville AND pd.current_building IS NOT DISTINCT FROM v_bat
                AND pd.current_room IS NOT DISTINCT FROM v_room
                AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
                             WHERE coalesce((s->>'pj')::boolean,false) AND s->>'nom' = pd.name)))
  ), 0) + coalesce((
    SELECT count(*) FROM public.pnj_possessions p
      JOIN public.pnj_membres m ON m.id = p.pnj_id
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND m.leader_pj = g.o_moi
       AND p.objet->>'produitMilitaire' = 'tente'
  ), 0) INTO v_tentes;

  SELECT 1 + coalesce((
    SELECT count(*) FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
      JOIN public.personnages_donnees pd ON pd.name = s->>'nom'
     WHERE coalesce((s->>'pj')::boolean,false) AND s->>'nom' <> g.o_moi
       AND pd.current_city = v_ville
       AND pd.current_building IS NOT DISTINCT FROM v_bat
       AND pd.current_room IS NOT DISTINCT FROM v_room), 0) INTO v_pj_groupe;

  SELECT coalesce(jsonb_agg(t.ligne ORDER BY t.nom), '[]'::jsonb) INTO v_inv
    FROM (
      SELECT min(coalesce(i->>'name','?')) AS nom,
             jsonb_build_object(
               'signature', public.militaire_objet_signature(i),
               'name', min(coalesce(i->>'name','?')),
               'icon', min(coalesce(i->>'icon','ti-package')),
               'type', min(coalesce(i->>'type','')),
               'qte', sum(public.militaire_unites_objet(i))::integer,
               'arme', bool_or(i->>'type' = 'arme')) AS ligne
        FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                       THEN pd.inventory ELSE '[]'::jsonb END) i
       WHERE pd.name = g.o_moi
       GROUP BY public.militaire_objet_signature(i)
    ) t;

  SELECT coalesce(jsonb_agg(x.ligne ORDER BY x.matricule), '[]'::jsonb) INTO v_soldats
    FROM (
      SELECT sm.matricule,
             jsonb_build_object(
               'matricule', sm.matricule,
               'pa', m.pa, 'pa_max', c_pa_max,
               'arme', coalesce(sm.arme, 'corps_a_corps'),
               'arme_feu', EXISTS (SELECT 1 FROM public.militaire_armes_bonus b
                                    WHERE b.cle = coalesce(sm.arme,'corps_a_corps') AND b.mode='feu'),
               'avec_moi', (m.leader_pj = g.o_moi),
               'leader', m.leader_pj,
               'ville', CASE WHEN m.leader_pj = g.o_moi THEN NULL ELSE pe.ville END,
               'copresent', public.pnj_co_present(g.o_moi, m.id),
               'radio', EXISTS (SELECT 1 FROM public.pnj_possessions p
                                 WHERE p.pnj_id = m.id AND p.objet->>'produitMilitaire' = 'radio'),
               'a_ration', EXISTS (SELECT 1 FROM public.pnj_possessions p
                                    WHERE p.pnj_id = m.id
                                      AND p.objet->>'produitMilitaire' = 'ration_combat'),
               'rations_jour', CASE WHEN coalesce(b.sol->>'dernier_ration','') = v_jour
                                    THEN coalesce((b.sol->>'nb_ration')::integer, 1) ELSE 0 END,
               'max_ration_jour', c_max_ration_jour,
               'a_dormi', (coalesce(sm.dernier_sommeil,'') = v_jour),
               'possessions', coalesce((
                  SELECT jsonb_agg(q.ligne ORDER BY q.nom)
                    FROM (SELECT min(coalesce(p2.objet->>'name','?')) AS nom,
                                 jsonb_build_object(
                                   'signature', public.militaire_objet_signature(p2.objet),
                                   'name', min(coalesce(p2.objet->>'name','?')),
                                   'icon', min(coalesce(p2.objet->>'icon','ti-package')),
                                   'type', min(coalesce(p2.objet->>'type','')),
                                   'qte', sum(public.militaire_unites_objet(p2.objet))::integer) AS ligne
                            FROM public.pnj_possessions p2 WHERE p2.pnj_id = m.id
                           GROUP BY public.militaire_objet_signature(p2.objet)) q
                  ), '[]'::jsonb)
             ) AS ligne
        FROM public.pnj_soldats_metier sm
        JOIN public.pnj_membres m ON m.id = sm.pnj_id
        LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
        LEFT JOIN LATERAL (
          SELECT s AS sol FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
           WHERE s->>'matricule' = sm.matricule LIMIT 1) b ON true
       WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
         AND m.statut = 'actif' AND coalesce(sm.en_reserve, false) = false
    ) x;

  RETURN jsonb_build_object('ok', true,
    'moi', g.o_moi, 'pays', v_pays,
    'ma_ville', v_ville, 'suis_a_la_caserne', (v_bat = 'caserne-militaire'),
    'radio_moi', coalesce(v_radio_moi, false),
    'tentes', coalesce(v_tentes, 0),
    'capacite_tente', coalesce(v_tentes,0) * c_par_tente,
    'par_tente', c_par_tente,
    'places_pj', v_pj_groupe,
    'places_tente_libres', greatest(0, coalesce(v_tentes,0) * c_par_tente - v_pj_groupe),
    'mon_inventaire', v_inv,
    'soldats', v_soldats,
    'effectif', jsonb_array_length(v_soldats));
END; $fn$;

comment on function public.militaire_terminal_section() is
  'Tout ce que le terminal du Lieutenant affiche, en UN appel : ses soldats PNJ (matricule, PA, arme deduite, position reduite a la VILLE, possessions regroupees par signature, radio, compteurs du jour), son propre inventaire regroupe par signature, et la capacite reelle sous tente. Ne rend QUE la section dont l''appelant est le Lieutenant.';

revoke all on function public.militaire_terminal_section() from public, anon, authenticated;
grant execute on function public.militaire_terminal_section() to authenticated, service_role;