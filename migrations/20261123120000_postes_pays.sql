-- Le pays d'un poste est celui du registre, jamais celui où se trouve son titulaire (Claude, 23/11/2026,
-- GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, partie B, points 15 et 16). ÉCRITE, NON APPLIQUÉE.
-- Écrite à partir des définitions de PRODUCTION du 22/11/2026 au soir (pg_get_functiondef, lecture seule ; chaque ancrage
-- compté en production avant écriture : 66 remplacements, 0 écart). Rejouable, sans BEGIN/COMMIT. Rien du goulag.
-- AUCUNE donnée modifiée : ni ligne de postes_attribues, ni personnages_donnees.poste.
--
-- Constat (Fred) : Arnie, ministre de la Défense de Républia (postes_attribues : republic_min_def_national, country =
-- republic ; fiche : nationalite = republic, country = soviet car il est à Krasnov, poste = {"id":"min_def"} sans pays)
-- apparaissait dans l'organigramme de Sovarka et, côté serveur, de nombreuses portes lui prêtaient les pouvoirs du
-- ministre de la Défense soviétique : elles lisaient personnages_donnees.country (la POSITION) comme pays du poste, ou
-- comparaient poste->>'id' sans pays. Les identifiants de ville étant partagés entre pays (ville_b = Montrouge et
-- Krasnov), un maire, un commissaire ou un directeur d'entrepôt en voyage obtenait aussi l'autorité de la ville homonyme.
--
-- RÈGLE (documentée dans AGENTS.md, « Pays d'un poste ») :
--   R1. Le pays (et la ville) d'un poste est lu dans son registre : postes_attribues (country, city) pour les postes
--       nommés ; cycles_electoraux (country, city, eluId / elus) pour les postes élus ; la compagnie
--       (compagnie-<pays>-…) pour les grades militaires. Jamais personnages_donnees.country (position), jamais la
--       nationalité. Une ligne du registre ne vaut que si la fiche du titulaire porte ce même poste (une seule fonction
--       nommée à la fois) : une ligne orpheline ne donne rien.
--   R2. Un pouvoir ne s'exerce que sur le pays de son poste. Un personnage en voyage garde son poste, son salaire, sa
--       place dans les organigrammes de SON pays, et n'obtient jamais aucun pouvoir du pays où il se trouve.
--   R3. Un ordre réservé passé depuis un lieu se passe dans le pays du poste (règle du 05/11, inchangée :
--       exiger_poste, poste_autorite_de, ordre_generique_executer « hors_de_son_pays »).
-- Trois fonctions serveur uniques :
--   poste_detenu(nom, poste, pays, ville DEFAULT NULL) : « ce personnage détient-il ce poste dans ce pays (cette ville) ».
--   poste_pays_de(nom) : pays du poste porté par la fiche, selon R1 ; NULL si le poste n'est attesté nulle part.
--   poste_exerce(nom) : identifiant du poste si le personnage se trouve dans le pays de son poste, sinon NULL (R3).
-- Équivalent navigateur unique : posteDetenu / paysDuPoste / posteExerceIci (plateau-organisations-quetes.js).

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Les trois fonctions uniques
-- ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.poste_detenu(p_nom text, p_poste text, p_pays text, p_city text DEFAULT NULL)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- postes_pays_v1 : la seule réponse à « X détient-il le poste P dans le pays C (la ville V) ». p_city NULL : toute ville.
  SELECT coalesce(nullif(p_nom, '') IS NOT NULL AND nullif(p_poste, '') IS NOT NULL AND nullif(p_pays, '') IS NOT NULL
    AND CASE
      WHEN p_poste IN ('president', 'maire', 'chef_syndicat') THEN EXISTS (
        SELECT 1 FROM public.cycles_electoraux c
         WHERE c.country = p_pays AND c.poste_id = p_poste
           AND (p_city IS NULL OR c.city IS NOT DISTINCT FROM p_city)
           AND CASE WHEN left(btrim(c.data), 1) = '{' THEN c.data::jsonb ->> 'eluId' END = p_nom)
      WHEN p_poste = 'depute' THEN
        (p_pays = 'soviet' AND EXISTS (
          SELECT 1 FROM public.cycles_electoraux c,
                 jsonb_each(CASE WHEN left(btrim(c.data), 1) = '{' THEN coalesce(c.data::jsonb -> 'gloire' -> 'deputes', '{}'::jsonb)
                                 ELSE '{}'::jsonb END) l
           WHERE c.id = 'soviet_gloire_partis' AND jsonb_typeof(l.value) = 'array' AND l.value ? p_nom))
        OR EXISTS (
          SELECT 1 FROM public.cycles_electoraux c
           WHERE c.country = p_pays AND c.poste_id = 'depute'
             AND (p_city IS NULL OR c.city IS NOT DISTINCT FROM p_city)
             AND coalesce(CASE WHEN left(btrim(c.data), 1) = '{' THEN (c.data::jsonb -> 'elus') ? p_nom END, false))
      WHEN p_poste = 'capitaine' THEN EXISTS (
        SELECT 1 FROM public.compagnies_militaires m
         WHERE (m.id LIKE 'compagnie-' || p_pays || '-%' OR m.data ->> 'pays' = p_pays) AND m.data ->> 'capitaineNom' = p_nom)
      WHEN p_poste = 'lieutenant' THEN EXISTS (
        SELECT 1 FROM public.compagnies_militaires m,
               jsonb_array_elements(coalesce(m.data -> 'sections', '[]'::jsonb)) s
         WHERE (m.id LIKE 'compagnie-' || p_pays || '-%' OR m.data ->> 'pays' = p_pays) AND s ->> 'lieutenantNom' = p_nom)
      ELSE EXISTS (
        SELECT 1 FROM public.postes_attribues a
         WHERE a.titulaire = p_nom AND a.poste_id = p_poste AND a.country = p_pays
           AND (p_city IS NULL OR a.city IS NOT DISTINCT FROM p_city)
           -- Une ligne orpheline (la fiche porte un autre poste) ne vaut rien. La présidence de l'Assemblée n'est
           -- portée par aucune fiche : son registre suffit.
           AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees d
                            WHERE d.name = a.titulaire AND a.poste_id <> 'president_assemblee'
                              AND (CASE WHEN jsonb_typeof(d.poste) = 'object' THEN d.poste ->> 'id' END) IS DISTINCT FROM a.poste_id))
    END, false);
$function$;
REVOKE ALL ON FUNCTION public.poste_detenu(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_detenu(text, text, text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.poste_pays_de(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- postes_pays_v1 : pays du poste porté par la fiche, lu dans son registre (R1). Jamais la position ni la nationalité.
  SELECT CASE WHEN jsonb_typeof(d.poste) = 'object' AND coalesce(d.poste ->> 'id', '') <> '' THEN coalesce(
    (SELECT a.country FROM public.postes_attribues a
      WHERE a.titulaire = d.name AND a.poste_id = d.poste ->> 'id'
        AND (nullif(d.poste ->> 'city', '') IS NULL OR a.city IS NULL OR a.city = d.poste ->> 'city')
      ORDER BY a.updated_at DESC NULLS LAST LIMIT 1),
    (SELECT c.country FROM public.cycles_electoraux c
      WHERE d.poste ->> 'id' IN ('president', 'maire', 'chef_syndicat') AND c.poste_id = d.poste ->> 'id'
        AND (nullif(d.poste ->> 'city', '') IS NULL OR c.city IS NOT DISTINCT FROM d.poste ->> 'city')
        AND CASE WHEN left(btrim(c.data), 1) = '{' THEN c.data::jsonb ->> 'eluId' END = d.name
      ORDER BY c.updated_at DESC NULLS LAST LIMIT 1),
    CASE WHEN d.poste ->> 'id' IN ('capitaine', 'lieutenant', 'soldat') AND d.poste ->> 'compagnieId' LIKE 'compagnie-%-%'
         THEN nullif(split_part(d.poste ->> 'compagnieId', '-', 2), '') END,
    (SELECT coalesce(m.data ->> 'pays', nullif(split_part(m.id, '-', 2), '')) FROM public.compagnies_militaires m
      WHERE d.poste ->> 'id' = 'capitaine' AND m.data ->> 'capitaineNom' = d.name LIMIT 1))
  END
    FROM public.personnages_donnees d WHERE d.name = p_nom;
$function$;
REVOKE ALL ON FUNCTION public.poste_pays_de(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_pays_de(text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.poste_exerce(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- postes_pays_v1 : le poste qu'on peut exercer ICI ET MAINTENANT (R3) — celui de la fiche, si son titulaire se trouve
  -- dans le pays de ce poste ; sinon NULL. Le poste n'est pas perdu : il ne s'exerce simplement pas à l'étranger.
  SELECT CASE WHEN d.country IS NOT NULL AND public.poste_pays_de(d.name) = d.country
              THEN nullif(d.poste ->> 'id', '') END
    FROM public.personnages_donnees d WHERE d.name = p_nom;
$function$;
REVOKE ALL ON FUNCTION public.poste_exerce(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_exerce(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Portes communes réécrites (même signature, mêmes attributs, mêmes droits)
-- ---------------------------------------------------------------------------------------------------------------
-- acteur_poste_courant : le repli « p.country » (la position) disparaît. Pays = registre (R1) ; tutelle municipale :
-- le pays du ministre, déjà vérifié dans le registre par maire_tutelle_ici_interne. Un poste attesté nulle part n'a pas
-- de pays : les 40 portes qui la lisent refusent (exiger_poste, poste_autorite_de, caisse_refus_autorite…).
CREATE OR REPLACE FUNCTION public.acteur_poste_courant()
 RETURNS TABLE(nom text, poste_id text, poste_city text, pays text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- postes_pays_v1
  SELECT p.name,
         CASE WHEN public.maire_tutelle_ici_interne(p.name) IS NOT NULL THEN 'maire' ELSE p.poste->>'id' END,
         coalesce(public.maire_tutelle_ici_interne(p.name), p.poste->>'city'),
         CASE WHEN public.maire_tutelle_ici_interne(p.name) IS NOT NULL THEN p.country
              ELSE public.poste_pays_de(p.name) END
    FROM public.personnages_donnees p
   WHERE p.user_id = auth.uid()
   LIMIT 1;
$function$;

-- mon_poste_est : « je détiens ce poste » (dans le pays de mon poste).
CREATE OR REPLACE FUNCTION public.mon_poste_est(p_poste text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- postes_pays_v1
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') = p_poste
       AND public.poste_detenu(d.name, p_poste, public.poste_pays_de(d.name))
  );
$function$;

-- mon_poste_est_dans : « je détiens ce poste DANS CE PAYS » (registre ; pays NULL : celui de mon poste). Ses 15 appelants
-- (bne_caisse_*, diplomatie_repondre, manifestation_*, etat_urgence_decider, port_*, indice_diplomatique_ordre,
-- usine_virer_vers_ministere…) passent le pays où se trouve l'acteur : un ministre en voyage n'y a plus aucun pouvoir.
CREATE OR REPLACE FUNCTION public.mon_poste_est_dans(p_poste text, p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- postes_pays_v1
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') = p_poste
       AND public.poste_detenu(d.name, p_poste, coalesce(p_pays, public.poste_pays_de(d.name)))
  );
$function$;

-- guerre_acteur_poste : rendait la position (et 'republic' par défaut). Désormais : le pays du poste, si l'acteur s'y
-- trouve (R3) ; sinon rien.
CREATE OR REPLACE FUNCTION public.guerre_acteur_poste(p_poste text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- postes_pays_v1
  SELECT d.country
    FROM public.personnages_donnees d
   WHERE d.user_id = auth.uid() AND public.poste_exerce(d.name) = p_poste
   LIMIT 1;
$function$;

-- crim_force_ordre_interne : un commissaire en voyage n'est pas force de l'ordre à l'étranger.
CREATE OR REPLACE FUNCTION public.crim_force_ordre_interne(p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- postes_pays_v1
  SELECT coalesce((SELECT CASE WHEN poste ->> 'id' = 'commissaire' THEN public.poste_exerce(name) = 'commissaire'
                               ELSE poste ->> 'id' ~ '^(commissaire|policier|agent_securite|maitre_chien)' END
                     FROM public.personnages_donnees WHERE name = p_nom), false);
$function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Remplacements contrôlés (texte de production, ancrage compté, marque unique « pp_… »)
-- ---------------------------------------------------------------------------------------------------------------

-- admin_pnj_titulaire : PJ titulaire cherché par la position (d.country) : registre filtré sur le pays
SELECT pg_temp.rp_remplacer('public.admin_pnj_titulaire(text,text,text)'::regprocedure,
  $r$WHERE d.country = p_pays AND (d.poste ->> 'id') = p_poste$r$,
  $r$WHERE public.poste_detenu(d.name, p_poste, p_pays, p_ville) /*pp_admin_pnj*/ AND (d.poste ->> 'id') = p_poste$r$, 1, 'pp_admin_pnj');

-- justice_juge_titulaire : juge cherché par la position : registre filtré sur pays et ville
SELECT pg_temp.rp_remplacer('public.justice_juge_titulaire(text,text)'::regprocedure,
  $r$WHERE d.country = p_pays AND (d.poste ->> 'id') = 'juge'$r$,
  $r$WHERE public.poste_detenu(d.name, 'juge', p_pays, p_ville) /*pp_juge_tit*/ AND (d.poste ->> 'id') = 'juge'$r$, 1, 'pp_juge_tit');

-- piratage_titulaire_interne : titulaire visé par le piratage cherché par la position
SELECT pg_temp.rp_remplacer('public.piratage_titulaire_interne(text,text)'::regprocedure,
  $r$WHERE poste->>'id' = p_poste AND country = p_pays$r$,
  $r$WHERE poste->>'id' = p_poste AND public.poste_detenu(name, p_poste, p_pays) /*pp_piratage*/$r$, 1, 'pp_piratage');

-- juge_moi : juge PJ rendu avec d.country (position) comme pays de juridiction
SELECT pg_temp.rp_remplacer('public.juge_moi()'::regprocedure,
  $r$WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'juge'$r$,
  $r$WHERE d.user_id = auth.uid() AND public.poste_exerce(d.name) = 'juge' /*pp_juge_moi*/$r$, 1, 'pp_juge_moi');

-- parquet_moi : procureur PJ rendu avec d.country (position) comme pays
SELECT pg_temp.rp_remplacer('public.parquet_moi()'::regprocedure,
  $r$WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'procureur'$r$,
  $r$WHERE d.user_id = auth.uid() AND public.poste_exerce(d.name) = 'procureur' /*pp_parquet_moi*/$r$, 1, 'pp_parquet_moi');

-- sovarka_greffe_autorite_interne : un juge/commissaire étranger présent en Sovarka obtenait la greffe soviétique
SELECT pg_temp.rp_remplacer('public.sovarka_greffe_autorite_interne(text)'::regprocedure,
  $r$WHERE d.name = p_nom AND d.country = 'soviet' AND (d.poste ->> 'id') IN ('juge', 'commissaire'))$r$,
  $r$WHERE d.name = p_nom AND (d.poste ->> 'id') IN ('juge', 'commissaire') AND public.poste_detenu(d.name, d.poste ->> 'id', 'soviet') /*pp_sov_greffe*/)$r$, 1, 'pp_sov_greffe');

-- sovarka_justice_acte_autorite_interne : idem pour les actes de justice soviétiques
SELECT pg_temp.rp_remplacer('public.sovarka_justice_acte_autorite_interne(text)'::regprocedure,
  $r$WHERE d.name = p_nom AND d.country = 'soviet' AND (d.poste ->> 'id') IN ('juge', 'commissaire'))$r$,
  $r$WHERE d.name = p_nom AND (d.poste ->> 'id') IN ('juge', 'commissaire') AND public.poste_detenu(d.name, d.poste ->> 'id', 'soviet') /*pp_sov_justice*/)$r$, 1, 'pp_sov_justice');

-- assemblee_gouvernement_actuel : gouvernement d’un pays = ministres présents dans ce pays
SELECT pg_temp.rp_remplacer('public.assemblee_gouvernement_actuel(text)'::regprocedure,
  $r$WHERE pd.country = p_country$r$,
  $r$WHERE public.poste_detenu(pd.name, pd.poste ->> 'id', p_country) /*pp_gouv_actuel*/$r$, 1, 'pp_gouv_actuel');

-- assemblee_peut_deposer : un député étranger présent pouvait déposer une loi
SELECT pg_temp.rp_remplacer('public.assemblee_peut_deposer(text,text)'::regprocedure,
  $r$(p.poste_depute IS NOT NULL AND p.poste_depute->>'id' = 'depute')$r$,
  $r$(p.poste_depute IS NOT NULL AND p.poste_depute->>'id' = 'depute' AND public.poste_detenu(p.name, 'depute', p_country) /*pp_deposer_dep*/)$r$, 1, 'pp_deposer_dep');
--   (suite) un ministre étranger présent pouvait déposer une loi
SELECT pg_temp.rp_remplacer('public.assemblee_peut_deposer(text,text)'::regprocedure,
  $r$OR (p.poste IS NOT NULL AND p.poste->>'id' IN$r$,
  $r$OR (p.poste IS NOT NULL AND public.poste_detenu(p.name, p.poste->>'id', p_country) /*pp_deposer_min*/ AND p.poste->>'id' IN$r$, 1, 'pp_deposer_min');

-- entrepot_du_directeur : entrepôt du directeur joint sur la position (même identifiant de ville dans deux pays)
SELECT pg_temp.rp_remplacer('public.entrepot_du_directeur(text)'::regprocedure,
  $r$WHERE p.name = p_acteur AND p.poste->>'id' = 'directeur_entrepot';$r$,
  $r$WHERE p.name = p_acteur AND public.poste_exerce(p.name) = 'directeur_entrepot' /*pp_entrepot_dir*/;$r$, 1, 'pp_entrepot_dir');

-- crim_qhs_pays_mandat_interne : repli sur la position quand le registre ne répond pas
SELECT pg_temp.rp_remplacer('public.crim_qhs_pays_mandat_interne(text)'::regprocedure,
  $r$ORDER BY a.updated_at DESC NULLS LAST LIMIT 1), p.country)$r$,
  $r$ORDER BY a.updated_at DESC NULLS LAST LIMIT 1), public.poste_pays_de(p.name) /*pp_qhs_mandat*/)$r$, 1, 'pp_qhs_mandat');

-- bail_autorite_municipale : maire d’une ville homonyme d’un autre pays autorisé
SELECT pg_temp.rp_remplacer('public.bail_autorite_municipale(jsonb)'::regprocedure,
  $r$AND (d.poste ->> 'id') IN ('maire', 'maire_adjoint')$r$,
  $r$AND public.poste_exerce(d.name) IN ('maire', 'maire_adjoint') /*pp_bail*/$r$, 1, 'pp_bail');

-- affaire_autorite_de : juge/commissaire d’une ville homonyme d’un autre pays autorisé
SELECT pg_temp.rp_remplacer('public.affaire_autorite_de(text)'::regprocedure,
  $r$AND (d.poste ->> 'id') IN ('juge', 'commissaire')$r$,
  $r$AND public.poste_exerce(d.name) IN ('juge', 'commissaire') /*pp_affaire*/$r$, 1, 'pp_affaire');

-- blocus_nuit_effets : maire cherché par la position
SELECT pg_temp.rp_remplacer('public.blocus_nuit_effets()'::regprocedure,
  $r$WHERE coalesce(country, 'republic') = r.country AND poste->>'id' = 'maire' AND poste->>'city' = r.city$r$,
  $r$WHERE public.poste_detenu(name, 'maire', r.country, r.city) /*pp_blocus_nuit*/ AND poste->>'id' = 'maire'$r$, 1, 'pp_blocus_nuit');

-- club_electeurs : maire cherché par la position
SELECT pg_temp.rp_remplacer('public.club_electeurs(text)'::regprocedure,
  $r$AND coalesce(d.country, 'republic') = c.country$r$,
  $r$AND public.poste_detenu(d.name, 'maire', c.country, c.city) /*pp_club*/$r$, 1, 'pp_club');

-- candidature_entrepot_modification_autorisee : maire cherché par la position
SELECT pg_temp.rp_remplacer('public.candidature_entrepot_modification_autorisee(text,jsonb,jsonb)'::regprocedure,
  $r$WHERE d.country = p_pays AND d.poste ->> 'id' = 'maire'$r$,
  $r$WHERE public.poste_detenu(d.name, 'maire', p_pays, v_ville) /*pp_cand_entrepot*/ AND d.poste ->> 'id' = 'maire'$r$, 1, 'pp_cand_entrepot');

-- catastrophe_declarer : un pm étranger présent pouvait déclarer la catastrophe
SELECT pg_temp.rp_remplacer('public.catastrophe_declarer(bigint,boolean)'::regprocedure,
  $r$WHERE name = a AND country = e.pays AND poste->>'id' = 'pm'$r$,
  $r$WHERE name = a AND country = e.pays AND poste->>'id' = 'pm' AND public.poste_detenu(name, 'pm', e.pays) /*pp_cata_decl*/$r$, 1, 'pp_cata_decl');

-- catastrophe_proposer : un ministre de l’Intérieur étranger présent pouvait proposer
SELECT pg_temp.rp_remplacer('public.catastrophe_proposer(bigint)'::regprocedure,
  $r$WHERE name = a AND country = e.pays AND poste->>'id' = 'min_int'$r$,
  $r$WHERE name = a AND country = e.pays AND poste->>'id' = 'min_int' AND public.poste_detenu(name, 'min_int', e.pays) /*pp_cata_prop*/$r$, 1, 'pp_cata_prop');
--   (suite) pm destinataire cherché par la position
SELECT pg_temp.rp_remplacer('public.catastrophe_proposer(bigint)'::regprocedure,
  $r$WHERE country = e.pays AND poste->>'id' = 'pm' LIMIT 1$r$,
  $r$WHERE poste->>'id' = 'pm' AND public.poste_detenu(name, 'pm', e.pays) /*pp_cata_pm*/ LIMIT 1$r$, 1, 'pp_cata_pm');

-- catastrophe_etat : poste lu sans pays, pays = position
SELECT pg_temp.rp_remplacer('public.catastrophe_etat(bigint)'::regprocedure,
  $r$SELECT poste->>'id', country INTO v_poste, v_pays FROM public.personnages_donnees WHERE name = a;$r$,
  $r$SELECT public.poste_exerce(name) /*pp_cata_etat*/, country INTO v_poste, v_pays FROM public.personnages_donnees WHERE name = a;$r$, 1, 'pp_cata_etat');

-- cellule_alerter_ministre : ministre destinataire cherché par la position
SELECT pg_temp.rp_remplacer('public.cellule_alerter_ministre(text,text,text,text)'::regprocedure,
  $r$WHERE d.country = v_pays AND d.poste ->> 'id' = v_min LIMIT 1;$r$,
  $r$WHERE d.poste ->> 'id' = v_min AND public.poste_detenu(d.name, v_min, v_pays) /*pp_cellule_alerte*/ LIMIT 1;$r$, 1, 'pp_cellule_alerte');

-- climat_crue_appliquer_interne : ministre de l’Intérieur cherché par la position
SELECT pg_temp.rp_remplacer('public.climat_crue_appliquer_interne(climat_evenements)'::regprocedure,
  $r$WHERE country = e.pays AND poste->>'id' = 'min_int' LIMIT 1;$r$,
  $r$WHERE poste->>'id' = 'min_int' AND public.poste_detenu(name, 'min_int', e.pays) /*pp_crue_min*/ LIMIT 1;$r$, 1, 'pp_crue_min');

-- controle_couvre_feu_interne : exemption de couvre-feu accordée par un poste étranger
SELECT pg_temp.rp_remplacer('public.controle_couvre_feu_interne(text)'::regprocedure,
  $r$OR coalesce(p.poste ->> 'id', '') IN ('lieutenant', 'capitaine', 'commandant', 'min_def')$r$,
  $r$OR coalesce(public.poste_exerce(p_nom), '') /*pp_cf_ctrl*/ IN ('lieutenant', 'capitaine', 'commandant', 'min_def')$r$, 1, 'pp_cf_ctrl');

-- couvre_feu_patrouille : idem
SELECT pg_temp.rp_remplacer('public.couvre_feu_patrouille()'::regprocedure,
  $r$OR coalesce(p.poste ->> 'id', '') IN ('lieutenant', 'capitaine', 'commandant', 'min_def')$r$,
  $r$OR coalesce(public.poste_exerce(v_moi), '') /*pp_cf_patr*/ IN ('lieutenant', 'capitaine', 'commandant', 'min_def')$r$, 1, 'pp_cf_patr');

-- militaire_recruteur_de_moi : un officier en voyage recrutait pour le pays où il se trouve
SELECT pg_temp.rp_remplacer('public.militaire_recruteur_de_moi()'::regprocedure,
  $r$SELECT coalesce(country,'republic'), poste INTO o_pays, v_poste$r$,
  $r$SELECT coalesce(country,'republic'), CASE WHEN public.poste_exerce(name) IS NOT NULL THEN poste END /*pp_recruteur*/ INTO o_pays, v_poste$r$, 1, 'pp_recruteur');

-- effort_commande_annuler : poste sans pays, pays = position
SELECT pg_temp.rp_remplacer('public.effort_commande_annuler(text)'::regprocedure,
  $r$SELECT coalesce(country, 'republic'), poste ->> 'id'$r$,
  $r$SELECT coalesce(country, 'republic'), public.poste_exerce(name) /*pp_effort_annuler*/$r$, 1, 'pp_effort_annuler');

-- effort_commande_creer : poste sans pays, pays = position
SELECT pg_temp.rp_remplacer('public.effort_commande_creer(text,integer)'::regprocedure,
  $r$SELECT coalesce(country, 'republic'), poste ->> 'id'$r$,
  $r$SELECT coalesce(country, 'republic'), public.poste_exerce(name) /*pp_effort_creer*/$r$, 1, 'pp_effort_creer');

-- militaire_compagnies_lisibles : lecture des compagnies du pays où l’on se trouve au lieu de celles de son pays
SELECT pg_temp.rp_remplacer('public.militaire_compagnies_lisibles()'::regprocedure,
  $r$SELECT pd.country, pd.poste->>'id' INTO v_pays, v_poste$r$,
  $r$SELECT coalesce(public.poste_pays_de(pd.name), pd.country) /*pp_cie_lisibles*/, pd.poste->>'id' INTO v_pays, v_poste$r$, 1, 'pp_cie_lisibles');

-- militaire_inspection_perimetre : un ministre de la Défense étranger inspectait l’armée du pays visité
SELECT pg_temp.rp_remplacer('public.militaire_inspection_perimetre()'::regprocedure,
  $r$SELECT pd.country, pd.poste->>'id' INTO v_pays, v_poste$r$,
  $r$SELECT pd.country, public.poste_exerce(pd.name) /*pp_inspection*/ INTO v_pays, v_poste$r$, 1, 'pp_inspection');

-- budget_repartition_fixer : poste sans pays, pays = position
SELECT pg_temp.rp_remplacer('public.budget_repartition_fixer(text,text,numeric)'::regprocedure,
  $r$SELECT coalesce(country,'republic'), poste->>'id' INTO v_pays, v_poste$r$,
  $r$SELECT coalesce(country,'republic'), public.poste_exerce(name) /*pp_budget_rep*/ INTO v_pays, v_poste$r$, 1, 'pp_budget_rep');

-- dementi_executer : poste sans pays, pays = position
SELECT pg_temp.rp_remplacer('public.dementi_executer(text,integer,integer)'::regprocedure,
  $r$SELECT poste ->> 'id', country INTO v_poste, v_pays FROM public.personnages_donnees WHERE name = v_moi;$r$,
  $r$SELECT public.poste_exerce(name) /*pp_dementi*/, country INTO v_poste, v_pays FROM public.personnages_donnees WHERE name = v_moi;$r$, 1, 'pp_dementi');
--   (suite) membre du gouvernement visé reconnu par sa position
SELECT pg_temp.rp_remplacer('public.dementi_executer(text,integer,integer)'::regprocedure,
  $r$SELECT poste ->> 'id' INTO v_poste_cible FROM public.personnages_donnees WHERE name = v_cible AND country = v_pays;$r$,
  $r$SELECT CASE WHEN public.poste_detenu(name, poste ->> 'id', v_pays) THEN poste ->> 'id' END /*pp_dementi_cible*/ INTO v_poste_cible FROM public.personnages_donnees WHERE name = v_cible AND (country = v_pays OR public.poste_pays_de(name) = v_pays);$r$, 1, 'pp_dementi_cible');

-- enquete_ouvrir : poste sans pays, caisse du pays visité
SELECT pg_temp.rp_remplacer('public.enquete_ouvrir(text,text,text)'::regprocedure,
  $r$SELECT country, poste ->> 'id' INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;$r$,
  $r$SELECT country, public.poste_exerce(name) /*pp_enquete*/ INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;$r$, 1, 'pp_enquete');

-- vote_confiance_declencher : poste sans pays
SELECT pg_temp.rp_remplacer('public.vote_confiance_declencher(integer,integer)'::regprocedure,
  $r$SELECT country, poste ->> 'id' INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;$r$,
  $r$SELECT country, public.poste_exerce(name) /*pp_vc_decl*/ INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;$r$, 1, 'pp_vc_decl');
--   (suite) députés convoqués par leur position
SELECT pg_temp.rp_remplacer('public.vote_confiance_declencher(integer,integer)'::regprocedure,
  $r$WHERE country = v_pays AND (poste_depute ->> 'id') = 'depute' LOOP$r$,
  $r$WHERE (poste_depute ->> 'id') = 'depute' AND public.poste_detenu(name, 'depute', v_pays) /*pp_vc_deputes*/ LOOP$r$, 1, 'pp_vc_deputes');

-- vote_confiance_voter : un député étranger présent votait la confiance
SELECT pg_temp.rp_remplacer('public.vote_confiance_voter(text,text)'::regprocedure,
  $r$SELECT country, poste_depute ->> 'id' INTO v_pays, v_depute$r$,
  $r$SELECT country, CASE WHEN public.poste_detenu(name, 'depute', country) THEN poste_depute ->> 'id' END /*pp_vc_voter*/ INTO v_pays, v_depute$r$, 1, 'pp_vc_voter');

-- fixer_prix_entrepot : poste sans pays
SELECT pg_temp.rp_remplacer('public.fixer_prix_entrepot(text,text,jsonb)'::regprocedure,
  $r$SELECT poste->>'id', poste->>'city' INTO v_poste, v_ville$r$,
  $r$SELECT public.poste_exerce(name) /*pp_prix_entrepot*/, poste->>'city' INTO v_poste, v_ville$r$, 1, 'pp_prix_entrepot');

-- fixer_prix_vente_directe : poste sans pays, usine du pays visité
SELECT pg_temp.rp_remplacer('public.fixer_prix_vente_directe(text,text,jsonb)'::regprocedure,
  $r$SELECT poste->>'id' INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;$r$,
  $r$SELECT public.poste_exerce(name) /*pp_prix_usine*/ INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;$r$, 1, 'pp_prix_usine');

-- fixer_repartition_production : idem
SELECT pg_temp.rp_remplacer('public.fixer_repartition_production(text,text,numeric)'::regprocedure,
  $r$SELECT poste->>'id' INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;$r$,
  $r$SELECT public.poste_exerce(name) /*pp_repartition*/ INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;$r$, 1, 'pp_repartition');

-- percevoir_salaire_directeur : salaire du directeur cherché dans le pays visité
SELECT pg_temp.rp_remplacer('public.percevoir_salaire_directeur(text,text,text,text,text,text,numeric)'::regprocedure,
  $r$SELECT poste->>'id', poste->>'city', coalesce(country,'republic'),$r$,
  $r$SELECT poste->>'id', poste->>'city', coalesce(public.poste_pays_de(name), country,'republic') /*pp_salaire_dir*/,$r$, 1, 'pp_salaire_dir');

-- jauges_ordre_executer : ordres min_info / min_def / president / commissaire / min_int exécutés sur le pays visité
SELECT pg_temp.rp_remplacer('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure,
  $r$a.poste->>'id'$r$,
  $r$public.poste_exerce(a.name)/*pp_jauges*/$r$, 8, 'pp_jauges');

-- batiment_etat_sous_cle_ecrire : commissaire / chef des douanes écrivant les effectifs d’un bâtiment d’un autre pays
SELECT pg_temp.rp_remplacer('public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb)'::regprocedure,
  $r$SELECT p.name, p.poste INTO v_moi, v_poste$r$,
  $r$SELECT p.name, CASE WHEN public.poste_detenu(p.name, p.poste->>'id', CASE WHEN p_pays = 'global' THEN public.poste_pays_de(p.name) ELSE p_pays END) THEN p.poste END /*pp_sous_cle*/ INTO v_moi, v_poste$r$, 1, 'pp_sous_cle');

-- blocus_syndical_intervenir : commissaire d’une ville homonyme d’un autre pays
SELECT pg_temp.rp_remplacer('public.blocus_syndical_intervenir(text,text,text)'::regprocedure,
  $r$IF (p.poste->>'id') IS DISTINCT FROM 'commissaire' OR$r$,
  $r$IF NOT public.poste_detenu(p.name, 'commissaire', v_pays, p_ville) /*pp_blocus_comm*/ OR (p.poste->>'id') IS DISTINCT FROM 'commissaire' OR$r$, 1, 'pp_blocus_comm');

-- douane_payer_effectifs : chef des douanes étranger présent payait les effectifs
SELECT pg_temp.rp_remplacer('public.douane_payer_effectifs(text)'::regprocedure,
  $r$SELECT (poste->>'id') INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;$r$,
  $r$SELECT CASE WHEN public.poste_detenu(name, poste->>'id', p_pays) THEN poste->>'id' END /*pp_douane_paie*/ INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;$r$, 1, 'pp_douane_paie');

-- police_payer_effectifs : ministre de l’Intérieur étranger présent payait la police
SELECT pg_temp.rp_remplacer('public.police_payer_effectifs(text)'::regprocedure,
  $r$SELECT (poste->>'id') INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;$r$,
  $r$SELECT CASE WHEN public.poste_detenu(name, poste->>'id', p_pays) THEN poste->>'id' END /*pp_police_paie*/ INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;$r$, 1, 'pp_police_paie');

-- terrain_permis_decider : adjoint d’une ville homonyme d’un autre pays
SELECT pg_temp.rp_remplacer('public.terrain_permis_decider(text,boolean,text,uuid)'::regprocedure,
  $r$IF p.poste->>'id' IS DISTINCT FROM 'maire_adjoint' THEN$r$,
  $r$IF public.poste_exerce(moi) /*pp_permis*/ IS DISTINCT FROM 'maire_adjoint' THEN$r$, 1, 'pp_permis');

-- mairie_campagne_securite_interne : maire d’une ville homonyme d’un autre pays
SELECT pg_temp.rp_remplacer('public.mairie_campagne_securite_interne(text)'::regprocedure,
  $r$IF a.poste->>'id'IS DISTINCT FROM 'maire'$r$,
  $r$IF public.poste_exerce(a.name)/*pp_campagne*/IS DISTINCT FROM 'maire'$r$, 1, 'pp_campagne');

-- sacs_sable_poser : directeur d’entrepôt étranger
SELECT pg_temp.rp_remplacer('public.sacs_sable_poser(uuid)'::regprocedure,
  $r$AND d.poste->>'id' = 'directeur_entrepot')$r$,
  $r$AND public.poste_exerce(d.name) = 'directeur_entrepot' /*pp_sacs*/)$r$, 1, 'pp_sacs');

-- assemblee_mettre_en_application : ministre de l’Intérieur étranger présent appliquait les lois
SELECT pg_temp.rp_remplacer('public.assemblee_mettre_en_application(text,text,text)'::regprocedure,
  $r$SELECT pd.poste ->> 'id' INTO v_poste FROM public.personnages_donnees pd WHERE pd.name = p_acteur;$r$,
  $r$SELECT public.poste_exerce(pd.name) /*pp_mise_appli*/ INTO v_poste FROM public.personnages_donnees pd WHERE pd.name = p_acteur;$r$, 1, 'pp_mise_appli');

-- budget_national_epingler : un ministre modifiait les champs du budget national d’un autre pays
SELECT pg_temp.rp_remplacer('public.budget_national_epingler()'::regprocedure,
  $r$SELECT (d.poste ->> 'id') INTO v_poste$r$,
  $r$SELECT CASE WHEN public.poste_detenu(d.name, d.poste ->> 'id', NEW.id) THEN d.poste ->> 'id' END /*pp_budget_epingler*/ INTO v_poste$r$, 1, 'pp_budget_epingler');

-- forum_publication_jauges_interne : forums présidence / gouvernement du pays visité
SELECT pg_temp.rp_remplacer('public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure,
  $r$a.poste->>'id'$r$,
  $r$public.poste_exerce(a.name)/*pp_forum*/$r$, 2, 'pp_forum');

-- assemblee_occupation_sieges : un député en voyage perdait son siège à l’affichage
SELECT pg_temp.rp_remplacer('public.assemblee_occupation_sieges(text)'::regprocedure,
  $r$WHERE p.country = p_country$r$,
  $r$WHERE public.poste_detenu(p.name, 'depute', p_country) /*pp_sieges*/$r$, 1, 'pp_sieges');
--   (suite) idem
SELECT pg_temp.rp_remplacer('public.assemblee_occupation_sieges(text)'::regprocedure,
  $r$public.poste_est_atteste(p.name, p.poste_depute, p.country)$r$,
  $r$public.poste_est_atteste(p.name, p.poste_depute, p_country) /*pp_sieges_att*/$r$, 1, 'pp_sieges_att');

-- personnage_ajuster_pop_inf : poste sans pays
SELECT pg_temp.rp_remplacer('public.personnage_ajuster_pop_inf(text,text,integer,integer,text)'::regprocedure,
  $r$SELECT pd.poste->>'id', pd.country INTO v_poste, v_pays$r$,
  $r$SELECT public.poste_exerce(pd.name) /*pp_pop_inf*/, pd.country INTO v_poste, v_pays$r$, 1, 'pp_pop_inf');

-- fraude_electorale_tenter : maire/commissaire/juge étranger truquant une élection du pays visité
SELECT pg_temp.rp_remplacer('public.fraude_electorale_tenter(text,text,text,text,integer)'::regprocedure,
  $r$poste ->> 'id' AS poste$r$,
  $r$public.poste_exerce(name) /*pp_fraude*/ AS poste$r$, 1, 'pp_fraude');

-- minuit_couvre_feu_recherche : gouvernement frappé par sa position
SELECT pg_temp.rp_remplacer('public.minuit_couvre_feu_recherche(text)'::regprocedure,
  $r$WHERE d.country = p_pays$r$,
  $r$WHERE public.poste_pays_de(d.name) = p_pays /*pp_cf_minuit*/$r$, 1, 'pp_cf_minuit');
--   (suite) commandant cherché par la position
SELECT pg_temp.rp_remplacer('public.minuit_couvre_feu_recherche(text)'::regprocedure,
  $r$WHERE country = p_pays AND poste ->> 'id' = 'commandant' LIMIT 1;$r$,
  $r$WHERE poste ->> 'id' = 'commandant' AND public.poste_detenu(name, 'commandant', p_pays) /*pp_cf_cmd*/ LIMIT 1;$r$, 1, 'pp_cf_cmd');

-- rumeur_lancer : ministres visés par leur position
SELECT pg_temp.rp_remplacer('public.rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure,
  $r$WHERE country = p_cible AND poste ->> 'id' IN$r$,
  $r$WHERE public.poste_pays_de(name) = p_cible /*pp_rumeur1*/ AND poste ->> 'id' IN$r$, 1, 'pp_rumeur1');
--   (suite) idem
SELECT pg_temp.rp_remplacer('public.rumeur_lancer(text,text,text,text,integer,integer)'::regprocedure,
  $r$WHERE country = p_cible AND name <> v_moi AND poste ->> 'id' IN$r$,
  $r$WHERE public.poste_pays_de(name) = p_cible /*pp_rumeur2*/ AND name <> v_moi AND poste ->> 'id' IN$r$, 1, 'pp_rumeur2');

-- sovarka_entrepots_passe : un directeur en voyage perdait ses consignes
SELECT pg_temp.rp_remplacer('public.sovarka_entrepots_passe(date,text[])'::regprocedure,
  $r$WHERE p.name = v_ent->>'desiderataPar' AND p.country = 'soviet'$r$,
  $r$WHERE p.name = v_ent->>'desiderataPar' /*pp_sov_entrepots*/$r$, 1, 'pp_sov_entrepots');
--   (suite) idem
SELECT pg_temp.rp_remplacer('public.sovarka_entrepots_passe(date,text[])'::regprocedure,
  $r$AND p.poste->>'id' = 'directeur_entrepot' AND p.poste->>'city' = c_villes[v_i]$r$,
  $r$AND public.poste_detenu(p.name, 'directeur_entrepot', 'soviet', c_villes[v_i]) /*pp_sov_entrepots_dir*/$r$, 1, 'pp_sov_entrepots_dir');

-- casier_extrait_enquete : magistrat étranger enquêtant au greffe du pays visité
SELECT pg_temp.rp_remplacer('public.casier_extrait_enquete(text)'::regprocedure,
  $r$IF v_poste.poste_id IS NULL OR v_poste.poste_id NOT IN ('juge', 'commissaire', 'procureur') THEN$r$,
  $r$IF v_poste.poste_id IS NULL OR v_poste.pays IS DISTINCT FROM v_pays /*pp_casier*/ OR v_poste.poste_id NOT IN ('juge', 'commissaire', 'procureur') THEN$r$, 1, 'pp_casier');

-- militaire_decorer : décoration au nom du pays visité
SELECT pg_temp.rp_remplacer('public.militaire_decorer(text,text,text)'::regprocedure,
  $r$SELECT country INTO v_pays_moi   FROM public.personnages_donnees WHERE name = v_moi;$r$,
  $r$SELECT public.poste_pays_de(name) /*pp_decorer*/ INTO v_pays_moi FROM public.personnages_donnees WHERE name = v_moi;$r$, 1, 'pp_decorer');

-- crime_detecter_interne : immunité présidentielle / ministérielle valable dans le pays visité
SELECT pg_temp.rp_remplacer('public.crime_detecter_interne(text,text,boolean,text)'::regprocedure,
  $r$SELECT poste ->> 'id' AS poste, resources INTO d$r$,
  $r$SELECT public.poste_exerce(name) /*pp_crime_detect*/ AS poste, resources INTO d$r$, 1, 'pp_crime_detect');

-- personnages_poste_perdu : la ligne du registre n’était effacée que si le titulaire se trouvait dans le pays du poste
SELECT pg_temp.rp_remplacer('public.personnages_poste_perdu()'::regprocedure,
  $r$AND country = OLD.country$r$,
  $r$/*pp_poste_perdu*/$r$, 1, 'pp_poste_perdu');

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Contrôle final : toutes les marques sont en place
-- ---------------------------------------------------------------------------------------------------------------
DO $$
DECLARE r record; v_manque text := '';
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.admin_pnj_titulaire(text,text,text)', 'pp_admin_pnj'),
    ('public.justice_juge_titulaire(text,text)', 'pp_juge_tit'),
    ('public.piratage_titulaire_interne(text,text)', 'pp_piratage'),
    ('public.juge_moi()', 'pp_juge_moi'),
    ('public.parquet_moi()', 'pp_parquet_moi'),
    ('public.sovarka_greffe_autorite_interne(text)', 'pp_sov_greffe'),
    ('public.sovarka_justice_acte_autorite_interne(text)', 'pp_sov_justice'),
    ('public.assemblee_gouvernement_actuel(text)', 'pp_gouv_actuel'),
    ('public.assemblee_peut_deposer(text,text)', 'pp_deposer_dep'),
    ('public.assemblee_peut_deposer(text,text)', 'pp_deposer_min'),
    ('public.entrepot_du_directeur(text)', 'pp_entrepot_dir'),
    ('public.crim_qhs_pays_mandat_interne(text)', 'pp_qhs_mandat'),
    ('public.bail_autorite_municipale(jsonb)', 'pp_bail'),
    ('public.affaire_autorite_de(text)', 'pp_affaire'),
    ('public.blocus_nuit_effets()', 'pp_blocus_nuit'),
    ('public.club_electeurs(text)', 'pp_club'),
    ('public.candidature_entrepot_modification_autorisee(text,jsonb,jsonb)', 'pp_cand_entrepot'),
    ('public.catastrophe_declarer(bigint,boolean)', 'pp_cata_decl'),
    ('public.catastrophe_proposer(bigint)', 'pp_cata_prop'),
    ('public.catastrophe_proposer(bigint)', 'pp_cata_pm'),
    ('public.catastrophe_etat(bigint)', 'pp_cata_etat'),
    ('public.cellule_alerter_ministre(text,text,text,text)', 'pp_cellule_alerte'),
    ('public.climat_crue_appliquer_interne(climat_evenements)', 'pp_crue_min'),
    ('public.controle_couvre_feu_interne(text)', 'pp_cf_ctrl'),
    ('public.couvre_feu_patrouille()', 'pp_cf_patr'),
    ('public.militaire_recruteur_de_moi()', 'pp_recruteur'),
    ('public.effort_commande_annuler(text)', 'pp_effort_annuler'),
    ('public.effort_commande_creer(text,integer)', 'pp_effort_creer'),
    ('public.militaire_compagnies_lisibles()', 'pp_cie_lisibles'),
    ('public.militaire_inspection_perimetre()', 'pp_inspection'),
    ('public.budget_repartition_fixer(text,text,numeric)', 'pp_budget_rep'),
    ('public.dementi_executer(text,integer,integer)', 'pp_dementi'),
    ('public.dementi_executer(text,integer,integer)', 'pp_dementi_cible'),
    ('public.enquete_ouvrir(text,text,text)', 'pp_enquete'),
    ('public.vote_confiance_declencher(integer,integer)', 'pp_vc_decl'),
    ('public.vote_confiance_declencher(integer,integer)', 'pp_vc_deputes'),
    ('public.vote_confiance_voter(text,text)', 'pp_vc_voter'),
    ('public.fixer_prix_entrepot(text,text,jsonb)', 'pp_prix_entrepot'),
    ('public.fixer_prix_vente_directe(text,text,jsonb)', 'pp_prix_usine'),
    ('public.fixer_repartition_production(text,text,numeric)', 'pp_repartition'),
    ('public.percevoir_salaire_directeur(text,text,text,text,text,text,numeric)', 'pp_salaire_dir'),
    ('public.jauges_ordre_executer(text,uuid,jsonb)', 'pp_jauges'),
    ('public.batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb)', 'pp_sous_cle'),
    ('public.blocus_syndical_intervenir(text,text,text)', 'pp_blocus_comm'),
    ('public.douane_payer_effectifs(text)', 'pp_douane_paie'),
    ('public.police_payer_effectifs(text)', 'pp_police_paie'),
    ('public.terrain_permis_decider(text,boolean,text,uuid)', 'pp_permis'),
    ('public.mairie_campagne_securite_interne(text)', 'pp_campagne'),
    ('public.sacs_sable_poser(uuid)', 'pp_sacs'),
    ('public.assemblee_mettre_en_application(text,text,text)', 'pp_mise_appli'),
    ('public.budget_national_epingler()', 'pp_budget_epingler'),
    ('public.forum_publication_jauges_interne(text,uuid,jsonb)', 'pp_forum'),
    ('public.assemblee_occupation_sieges(text)', 'pp_sieges'),
    ('public.assemblee_occupation_sieges(text)', 'pp_sieges_att'),
    ('public.personnage_ajuster_pop_inf(text,text,integer,integer,text)', 'pp_pop_inf'),
    ('public.fraude_electorale_tenter(text,text,text,text,integer)', 'pp_fraude'),
    ('public.minuit_couvre_feu_recherche(text)', 'pp_cf_minuit'),
    ('public.minuit_couvre_feu_recherche(text)', 'pp_cf_cmd'),
    ('public.rumeur_lancer(text,text,text,text,integer,integer)', 'pp_rumeur1'),
    ('public.rumeur_lancer(text,text,text,text,integer,integer)', 'pp_rumeur2'),
    ('public.sovarka_entrepots_passe(date,text[])', 'pp_sov_entrepots'),
    ('public.sovarka_entrepots_passe(date,text[])', 'pp_sov_entrepots_dir'),
    ('public.casier_extrait_enquete(text)', 'pp_casier'),
    ('public.militaire_decorer(text,text,text)', 'pp_decorer'),
    ('public.crime_detecter_interne(text,text,boolean,text)', 'pp_crime_detect'),
    ('public.personnages_poste_perdu()', 'pp_poste_perdu')
  ) AS t(fn, marque) LOOP
    IF position(r.marque IN pg_get_functiondef(r.fn::regprocedure)) = 0 THEN v_manque := v_manque || ' ' || r.fn || ':' || r.marque; END IF;
  END LOOP;
  IF v_manque <> '' THEN RAISE EXCEPTION 'postes_pays : marques absentes :%', v_manque; END IF;
END $$;
