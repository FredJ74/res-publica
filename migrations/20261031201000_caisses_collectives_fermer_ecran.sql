-- CAISSES DES CLUBS ET DES ORGANISATIONS : FERMETURE DES ÉCRITURES DIRECTES (#295)
-- Claude, 31/10/2026. ÉTAPE 2 SUR 2 — À APPLIQUER APRÈS le déploiement (Vercel READY) de l'écran
-- qui passe par les portes de 20261031200000. Aucune donnée de joueur modifiée.
--
-- 1. budgets_clubs : plus aucune écriture de l'écran (toutes passent par une fonction serveur).
--    INSERT et UPDATE retirés à anon/authenticated, politiques d'écriture supprimées.
-- 2. organisations : DELETE réservé au chef ou au fondateur (dissolution, repli de
--    sbDeleteOrganisation tant que la commande serveur « dissoudre » n'existe pas). INSERT/UPDATE restent
--    nécessaires aux commandes d'adhésion, de grades et d'élection tant que les contrats serveur de
--    Codex (#219 : organisation_commande_membres / _administrative / _evenement) ne sont pas en
--    production. Le déclencheur organisations_finances_garder protège, pour TOUTE écriture directe
--    du navigateur (current_user anon/authenticated ; une fonction SECURITY DEFINER s'exécute sous
--    son propriétaire et n'est pas concernée) :
--      * la caisse : conserve la valeur du serveur (création à 0) — un blob périmé ou forgé ne
--        peut ni créer ni détruire d'argent ;
--      * le trésorier : seul le chef le nomme ou le révoque ;
--      * la direction (chef, chefEstPnj, fondateur) : seul le chef la transmet, ou la clôture
--        d'une élection en cours dont le vainqueur est celui que donnent les votes enregistrés ;
--      * les grades des membres existants : seul le chef les change (et le vainqueur d'élection) ;
--      * les membres : un non-chef n'entre qu'au grade 0 et ne retire que lui-même ; un membre
--        absent d'un blob périmé est conservé au lieu d'être effacé ;
--      * les votes : un non-chef ne vote que pour lui-même.
--    Le déclencheur des partis (organisations_politique_autorite) reste en place et s'applique
--    après celui-ci (ordre alphabétique des déclencheurs).
-- 3. transferts_clubs : l'écran n'écrit plus que les étapes de négociation qui lui reviennent
--    (offre du président d'arrivée, réponse du président de départ, refus du joueur). Le
--    règlement passe par club_transfert_conclure.
-- Banc : outils/bancs/banc-caisses-collectives-local.py --local-jetable (PostgreSQL jetable).
BEGIN;

-- ------------------------------------------------------------------------- 1. budgets_clubs
REVOKE INSERT, UPDATE, DELETE ON public.budgets_clubs FROM anon, authenticated;
DROP POLICY IF EXISTS budgets_clubs_ecriture_acteur ON public.budgets_clubs;
DROP POLICY IF EXISTS budgets_clubs_maj_acteur ON public.budgets_clubs;

-- -------------------------------------------------------------------------- 2. organisations
DROP POLICY IF EXISTS organisations_suppression_acteur ON public.organisations;
DROP POLICY IF EXISTS organisations_suppression_chef ON public.organisations;
CREATE POLICY organisations_suppression_chef ON public.organisations FOR DELETE TO authenticated
  USING (public.mon_personnage() IS NOT NULL AND (data IS JSON OBJECT)
         AND public.mon_personnage() IN (data::jsonb->>'chef', data::jsonb->>'fondateur'));

CREATE OR REPLACE FUNCTION public.organisation_vainqueur_election(p_election jsonb) RETURNS text
LANGUAGE plpgsql IMMUTABLE SET search_path = public, pg_temp AS $$
-- Même décompte que verifierElectionsOrganisations : candidats dans l'ordre, le premier qui
-- dépasse strictement le maximum courant l'emporte.
DECLARE c jsonb; v_voix integer; v_max integer := -1; v_vainqueur text;
BEGIN
  FOR c IN SELECT e FROM jsonb_array_elements(coalesce(p_election->'candidats', '[]'::jsonb)) e LOOP
    SELECT count(*) INTO v_voix FROM jsonb_each_text(coalesce(p_election->'votes', '{}'::jsonb)) v
     WHERE v.value = c->>'nom';
    IF v_voix > v_max THEN v_max := v_voix; v_vainqueur := c->>'nom'; END IF;
  END LOOP;
  RETURN v_vainqueur;
END $$;

CREATE OR REPLACE FUNCTION public.organisations_finances_garder() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_av jsonb; v_ap jsonb; v_chef_av text; v_est_chef boolean; v_election boolean := false;
        v_vainqueur text; m jsonb; a jsonb; v_membres jsonb := '[]'::jsonb; v_cle text;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN RETURN NEW; END IF;
  IF NEW.data IS NULL OR NOT (NEW.data IS JSON OBJECT) THEN
    RAISE EXCEPTION 'organisation_donnees_illisibles' USING ERRCODE = '42501';
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RAISE EXCEPTION 'organisation_acteur_non_authentifie' USING ERRCODE = '42501'; END IF;
  v_ap := NEW.data::jsonb;

  IF TG_OP = 'INSERT' THEN
    IF coalesce((v_ap->>'caisse')::numeric, 0) <> 0 THEN
      RAISE EXCEPTION 'organisation_caisse_initiale_interdite' USING ERRCODE = '42501';
    END IF;
    IF nullif(btrim(coalesce(v_ap->>'tresorier', '')), '') IS NOT NULL THEN
      RAISE EXCEPTION 'organisation_tresorier_initial_interdit' USING ERRCODE = '42501';
    END IF;
    IF NOT ((v_ap->>'fondateur') = v_moi AND (v_ap->>'chef') = v_moi)
       AND NOT (coalesce((v_ap->>'chefEstPnj')::boolean, false)
                AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_ap->>'chef')) THEN
      RAISE EXCEPTION 'organisation_fondateur_usurpe' USING ERRCODE = '42501';
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_ap->'membres', '[]'::jsonb)) x
                WHERE x->>'nom' IS DISTINCT FROM v_moi) THEN
      RAISE EXCEPTION 'organisation_fondee_avec_des_membres' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  v_av := CASE WHEN OLD.data IS JSON OBJECT THEN OLD.data::jsonb ELSE '{}'::jsonb END;
  v_chef_av := v_av->>'chef';
  v_est_chef := v_chef_av IS NOT NULL AND v_chef_av = v_moi;

  -- La caisse est TOUJOURS celle du serveur.
  v_ap := jsonb_set(v_ap, '{caisse}', coalesce(v_av->'caisse', '0'::jsonb));

  -- Clôture d'élection : seule voie de changement de direction sans le chef.
  IF (v_ap->>'chef') IS DISTINCT FROM v_chef_av AND NOT v_est_chef THEN
    v_vainqueur := public.organisation_vainqueur_election(v_av->'election');
    v_election := coalesce((v_av->'election'->>'enCours')::boolean, false)
                  AND (v_av->'election'->>'phase') = 'vote'
                  AND v_vainqueur IS NOT NULL AND (v_ap->>'chef') = v_vainqueur
                  AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av->'membres', '[]'::jsonb)) x
                               WHERE x->>'nom' = v_vainqueur);
    IF NOT v_election THEN
      RAISE EXCEPTION 'organisation_direction_non_autorisee' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF NOT v_est_chef THEN
    FOREACH v_cle IN ARRAY ARRAY['tresorier', 'fondateur'] LOOP
      IF v_av ? v_cle THEN v_ap := jsonb_set(v_ap, ARRAY[v_cle], v_av->v_cle); ELSE v_ap := v_ap - v_cle; END IF;
    END LOOP;
    IF NOT v_election THEN
      IF v_av ? 'chefEstPnj' THEN v_ap := jsonb_set(v_ap, '{chefEstPnj}', v_av->'chefEstPnj'); END IF;
    END IF;

    -- Membres : grades conservés, entrée au grade 0 pour soi seulement, aucun retrait d'autrui.
    FOR m IN SELECT e FROM jsonb_array_elements(coalesce(v_ap->'membres', '[]'::jsonb)) e LOOP
      SELECT e INTO a FROM jsonb_array_elements(coalesce(v_av->'membres', '[]'::jsonb)) e WHERE e->>'nom' = m->>'nom' LIMIT 1;
      IF a IS NOT NULL THEN
        IF NOT (v_election AND m->>'nom' = v_vainqueur) THEN
          m := m || jsonb_build_object('grade', a->'grade', 'gradeIdx', a->'gradeIdx');
        END IF;
      ELSIF m->>'nom' = v_moi THEN
        IF coalesce((m->>'gradeIdx')::integer, 0) <> 0 THEN
          RAISE EXCEPTION 'organisation_grade_non_autorise' USING ERRCODE = '42501';
        END IF;
      ELSIF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = m->>'nom') THEN
        RAISE EXCEPTION 'organisation_adhesion_non_autorisee' USING ERRCODE = '42501';
      END IF;
      v_membres := v_membres || jsonb_build_array(m);
      a := NULL;
    END LOOP;
    FOR a IN SELECT e FROM jsonb_array_elements(coalesce(v_av->'membres', '[]'::jsonb)) e LOOP
      IF a->>'nom' IS DISTINCT FROM v_moi
         AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_membres) x WHERE x->>'nom' = a->>'nom') THEN
        v_membres := v_membres || jsonb_build_array(a);   -- blob périmé : le membre reste
      END IF;
    END LOOP;
    v_ap := jsonb_set(v_ap, '{membres}', v_membres);

    -- Votes : chacun le sien.
    IF jsonb_typeof(v_ap->'election'->'votes') = 'object' THEN
      IF EXISTS (SELECT 1 FROM jsonb_each(v_ap->'election'->'votes') n
                  WHERE n.key <> v_moi AND (v_av->'election'->'votes'->n.key) IS DISTINCT FROM n.value)
         AND NOT v_election THEN
        RAISE EXCEPTION 'organisation_vote_pour_autrui' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  NEW.data := v_ap::text;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_organisations_finances_garder ON public.organisations;
CREATE TRIGGER trg_organisations_finances_garder BEFORE INSERT OR UPDATE ON public.organisations
  FOR EACH ROW EXECUTE FUNCTION public.organisations_finances_garder();

-- ------------------------------------------------------------------------ 3. transferts_clubs
CREATE OR REPLACE FUNCTION public.transferts_clubs_garder() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_n jsonb; v_o jsonb; v_pres_dep text; v_pres_arr text;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN RETURN NEW; END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RAISE EXCEPTION 'transfert_acteur_non_authentifie' USING ERRCODE = '42501'; END IF;
  v_n := NEW.data;
  IF NEW.statut IS DISTINCT FROM v_n->>'statut' THEN
    RAISE EXCEPTION 'transfert_statut_incoherent' USING ERRCODE = '42501';
  END IF;
  IF NEW.statut = 'termine' AND v_n ? 'concluPar' AND (TG_OP = 'INSERT' OR NOT OLD.data ? 'concluPar') THEN
    RAISE EXCEPTION 'transfert_reglement_reserve_au_serveur' USING ERRCODE = '42501';
  END IF;
  v_pres_arr := (SELECT data->>'president' FROM public.presidents_clubs WHERE id = v_n->>'clubArriveeId');

  IF TG_OP = 'INSERT' THEN
    IF NEW.statut <> 'propose' OR v_n->>'proposePar' IS DISTINCT FROM v_moi OR v_pres_arr IS DISTINCT FROM v_moi
       OR jsonb_typeof(v_n->'prixClub') <> 'number' OR (v_n->>'prixClub')::numeric <= 0 THEN
      RAISE EXCEPTION 'transfert_offre_non_autorisee' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  v_o := OLD.data;
  IF (v_n->>'joueur', v_n->>'clubDepartId', v_n->>'clubArriveeId', v_n->>'proposePar', v_n->'prixJoueur')
     IS DISTINCT FROM (v_o->>'joueur', v_o->>'clubDepartId', v_o->>'clubArriveeId', v_o->>'proposePar', v_o->'prixJoueur') THEN
    RAISE EXCEPTION 'transfert_termes_immuables' USING ERRCODE = '42501';
  END IF;
  v_pres_dep := (SELECT data->>'president' FROM public.presidents_clubs WHERE id = v_o->>'clubDepartId');

  IF OLD.statut = 'propose' AND v_pres_dep = v_moi
     AND NEW.statut IN ('termine', 'contre_offre', 'attente_joueur')
     AND ((v_n->'prixClub') = (v_o->'prixClub')
          OR (NEW.statut = 'contre_offre' AND jsonb_typeof(v_n->'prixClub') = 'number' AND (v_n->>'prixClub')::numeric > 0)) THEN
    RETURN NEW;
  END IF;
  IF OLD.statut = 'contre_offre' AND v_pres_arr = v_moi AND NEW.statut IN ('termine', 'attente_joueur')
     AND (v_n->'prixClub') = (v_o->'prixClub') THEN
    RETURN NEW;
  END IF;
  IF OLD.statut = 'attente_joueur' AND v_o->>'joueur' = v_moi AND NEW.statut = 'termine'
     AND (v_n->'prixClub') = (v_o->'prixClub') AND NOT v_n ? 'concluPar' THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'transfert_etape_non_autorisee' USING ERRCODE = '42501';
END $$;

DROP TRIGGER IF EXISTS trg_transferts_clubs_garder ON public.transferts_clubs;
CREATE TRIGGER trg_transferts_clubs_garder BEFORE INSERT OR UPDATE ON public.transferts_clubs
  FOR EACH ROW EXECUTE FUNCTION public.transferts_clubs_garder();
REVOKE DELETE ON public.transferts_clubs FROM anon, authenticated;

-- ------------------------------------------------------------------------------ preuves
DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.budgets_clubs', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.budgets_clubs', 'INSERT')
     OR EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'organisations' AND policyname = 'organisations_suppression_acteur') THEN
    RAISE EXCEPTION 'caisses_collectives: un droit direct subsiste';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_organisations_finances_garder')
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_transferts_clubs_garder') THEN
    RAISE EXCEPTION 'caisses_collectives: declencheur absent';
  END IF;
END $$;

COMMIT;
