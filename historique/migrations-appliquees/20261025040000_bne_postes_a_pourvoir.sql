-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261025181516.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 25/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025181516.
-- Eprouvee avant application en transaction annulee. Baseline NON reextrait (seed offres_emploi_bne perime : 0 ligne en production).
-- ============================================================================
-- BUREAU NATIONAL DE L'EMPLOI -- nouvelle formule, lot 1 (GAME-DESIGN-BNE.md, Fred 25/10/2026)
-- ============================================================================
-- 1. LES SEPT OFFRES FICTIVES D'AOUT SONT SUPPRIMEES. Les joueurs qui en occupent une recoivent
--    un mail du Bureau ; le registre des affectations est vide ; le catalogue miroir
--    offres_emploi_bne est vide (data.js : OFFRES_EMPLOI_BNE = {}). bne_agir reste en place
--    et refuse desormais toute prise ('offre_inconnue').
-- 2. bne_postes_a_pourvoir() : LE RECENSEMENT. Lecture seule. Rend :
--    - les postes metier, de justice et de police (jamais un poste politique) tenus par un
--      PNJ faute de joueur : la source est titulaires_pnj, le registre des PNJ en poste, et un
--      poste atteste par un joueur dans postes_attribues n'y figure jamais ;
--    - l'armee : capitaine de chaque compagnie sans capitaine, lieutenant de chaque section
--      constituee (soldats ou lieutenant) qui n'en a pas, et soldats PNJ des sections.
--    La candidature elle-meme passe par le circuit existant (decision de Fred : « on conserve
--    l'ancien fonctionnement en entier ») : poste nomme -> demanderNominationPoste /
--    poste_postuler ; capitaine et lieutenant -> militaire_candidature_deposer.
-- 3. militaire_candidature_deposer accepte aussi un candidat present au Bureau de l'Emploi
--    (« Postulez ici », decision de Fred). Le soldat s'engage toujours a la caserne.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

-- 1. Fin des offres fictives : un mail a chaque titulaire, puis registre et catalogue vides.
DO $mig$
DECLARE r record; v_etat jsonb;
BEGIN
  FOR r IN SELECT b.id, b.country, public.batiment_etat_lire(b.data) AS etat
             FROM public.batiments_etat b WHERE b.id LIKE '%\_national\_bne'
  LOOP
    PERFORM public.mail_systeme_poser_interne('Bureau National de l''Emploi', x.nom,
      'Le Bureau de l''Emploi change de formule',
      'Votre emploi « ' || x.offre || ' » n''existe plus : le Bureau ne propose plus d''emplois fictifs.<br><br>'
      || 'Désormais, il recense les <strong>vrais postes</strong> du pays tenus par des PNJ faute de joueur '
      || '(directeurs, port, douanes, justice, police, armée) et transmet votre candidature au recruteur officiel. '
      || 'Il affichera aussi les annonces des joueurs qui cherchent du monde.<br><br>'
      || 'Cet emploi n''était pas salarié : vous ne perdez rien, et votre revenu universel continue.<br><br>'
      || 'Le Bureau National de l''Emploi')
    FROM (SELECT DISTINCT e ->> 'pjNom' AS nom,
                 CASE o.key WHEN 'serveur_luthecia' THEN 'Serveur — Hôtel Républica'
                            WHEN 'docker_psm' THEN 'Docker — Port de Port-Sainte-Marie'
                            WHEN 'hotelier_montrouge' THEN 'Hôtelier — Hôtel du Mineur'
                            WHEN 'secretaire_nationale' THEN 'Secrétaire administratif'
                            WHEN 'commercant_national' THEN 'Commerçant itinérant'
                            WHEN 'banquier_national' THEN 'Conseiller bancaire'
                            WHEN 'hotesse_ambassade' THEN 'Hôtesse d''accueil diplomatique'
                            ELSE o.key END AS offre
            FROM jsonb_each(CASE WHEN jsonb_typeof(r.etat -> 'offres') = 'object' THEN r.etat -> 'offres' ELSE '{}'::jsonb END) o,
                 jsonb_array_elements(CASE WHEN jsonb_typeof(o.value) = 'array' THEN o.value ELSE '[]'::jsonb END) e
           WHERE e ->> 'pjNom' IS NOT NULL
             AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = e ->> 'pjNom')) x;
    v_etat := coalesce(r.etat, '{}'::jsonb) || jsonb_build_object('offres', '{}'::jsonb);
    UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now() WHERE id = r.id;
  END LOOP;
END $mig$;

DELETE FROM public.offres_emploi_bne;

-- 2. Le recensement.
CREATE OR REPLACE FUNCTION public.bne_postes_a_pourvoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_postes jsonb; v_armee jsonb;
  -- Postes metier, justice, police. JAMAIS un poste politique (decision de Fred, 25/10).
  v_metier text[] := ARRAY['directeur_entrepot','directeur_raffinerie','directeur_pharma',
                           'directeur_tabac_alcools','capitaine_port','chef_douanes',
                           'juge','procureur','commissaire','commandant'];
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'poste', z.poste_id, 'label', z.label, 'ville', z.ville, 'pnj', z.nom_pnj,
           'recruteur', z.recruteur, 'portee', z.scope)
         ORDER BY array_position(v_metier, z.poste_id), z.ville NULLS FIRST), '[]'::jsonb)
    INTO v_postes
    FROM (
      SELECT r.poste_id, r.label, r.scope, t.nom_pnj,
             CASE WHEN r.scope = 'ville'
                  THEN substr(t.id, length(v_pays || '_' || r.poste_id || '_') + 1) END AS ville,
             r.nomme_par AS recruteur
        FROM public.postes_nommes_regles r
        JOIN public.titulaires_pnj t
          ON (r.scope = 'ville' AND t.id LIKE v_pays || '\_' || r.poste_id || '\_%')
          OR (r.scope = 'pays' AND t.id IN (v_pays || '_' || r.poste_id || '_national',
                                            v_pays || '_' || r.poste_id))
       WHERE r.poste_id = ANY (v_metier)
    ) z
   WHERE NOT EXISTS (
     SELECT 1 FROM public.postes_attribues a
      WHERE a.country = v_pays AND a.poste_id = z.poste_id
        AND a.city IS NOT DISTINCT FROM z.ville
        AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = a.titulaire));

  -- L'armee, d'apres les unites qui existent reellement.
  SELECT jsonb_build_object(
    'capitaines', coalesce(sum(CASE WHEN coalesce(c.data ->> 'capitaineNom', '') = '' THEN 1 ELSE 0 END), 0),
    'lieutenants', coalesce(sum((SELECT count(*) FROM jsonb_array_elements(coalesce(c.data -> 'sections', '[]'::jsonb)) s
                                  WHERE coalesce(s ->> 'lieutenantNom', '') = ''
                                    AND jsonb_array_length(coalesce(s -> 'soldats', '[]'::jsonb)) > 0)), 0),
    'soldats', coalesce(sum((SELECT count(*) FROM jsonb_array_elements(coalesce(c.data -> 'sections', '[]'::jsonb)) s,
                                    jsonb_array_elements(coalesce(s -> 'soldats', '[]'::jsonb)) sol
                              WHERE NOT coalesce((sol ->> 'pj')::boolean, false))), 0),
    'compagnies', count(*))
    INTO v_armee
    FROM public.compagnies_militaires c
   WHERE c.data ->> 'pays' = v_pays;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'postes', v_postes, 'armee', v_armee);
END; $function$;
REVOKE ALL ON FUNCTION public.bne_postes_a_pourvoir() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bne_postes_a_pourvoir() TO authenticated;

-- 3. « Postulez ici » pour capitaine et lieutenant : le Bureau de l'Emploi vaut presence.
--    Lieux du Bureau : le batiment de Luthecia, et l'annexe du Centre d'affaires des autres villes.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  IF v_bat <> ''caserne-militaire'' THEN\n    RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_sur_place'');\n  END IF;\n';
  v_ajout text := E'  -- Bureau de l''Emploi (25/10/2026, decision de Fred) : on peut y postuler comme officier.\n  IF v_bat <> ''caserne-militaire''\n     AND NOT (p_grade IN (''capitaine'',''lieutenant'') AND v_bat IN (''bureau-national-emploi'',''centre-affaires'')) THEN\n    RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_sur_place'');\n  END IF;\n';
BEGIN
  v_def := pg_get_functiondef('public.militaire_candidature_deposer(text)'::regprocedure);
  IF position('bureau-national-emploi' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout);
  IF v_new = v_def THEN
    RAISE EXCEPTION 'patch non applique : fragment de militaire_candidature_deposer introuvable';
  END IF;
  EXECUTE v_new;
END $mig$;
