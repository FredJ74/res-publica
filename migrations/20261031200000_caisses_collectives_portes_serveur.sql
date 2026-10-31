-- CAISSES DES CLUBS ET DES ORGANISATIONS : CHAQUE MOUVEMENT PAR UNE PORTE SERVEUR (#295)
-- Claude, 31/10/2026. ÉTAPE 1 SUR 2 : compatible avec l'écran en ligne (n'ajoute que des fonctions
-- et une table de reçus) ; aucune donnée de joueur modifiée ; aucune règle de jeu changée.
--
-- Jusqu'ici l'écran calculait lui-même chaque mouvement de caisse collective puis réécrivait le
-- blob entier (sbSaveBudgetClub / sbSaveOrganisation) : collecte tirée par Math.random, dividendes,
-- adhésion des dockers, cotisation des supporters, sponsoring, transfert de joueur, salaires,
-- subvention ministérielle. Chaque mouvement passe désormais par une fonction qui vérifie
-- l'autorité, prélève le joueur et crédite la caisse DANS LA MÊME TRANSACTION, et ne s'exécute
-- qu'une fois par identifiant de requête (reçu dans caisses_collectives_operations).
--
-- Règles reprises telles quelles (sources) :
--   * caisse d'organisation : le trésorier s'il existe, sinon le chef (arbitrage du 7/09/2026,
--     plateau-gouvernement.js, verdictAutoriteCaisseOrga) ;
--   * orga_collecte (religieuse, 2 PA) : don de 200 à 699 FR versé à la caisse ;
--   * orga_dividendes (économique, 1 PA) : 30 % de la caisse versés à celui qui l'exécute, refus
--     sous 10 FR ;
--   * se_syndiquer (dockers de PSM, 1 PA + 50 FR) : les 50 FR vont à la caisse du syndicat ;
--   * rejoindre_club_supporters (1 PA + 50 FR) : les 50 FR vont à la caisse du club ;
--   * sponsoriser_club (1 PA) : paliers 500 / 1 500 / 3 000 FR, +2 / +5 / +10 INF ;
--   * transfert : le club d'arrivée paie prixClub au club de départ quand le joueur accepte ;
--   * salaires : réservés au président du club ;
--   * subvention ministérielle (min_fin, 1 à 5 000 FR, versement partiel toléré comme pour le
--     citoyen) à un club ou une organisation.
-- Changement voulu : un club d'arrivée qui n'a pas de quoi payer un transfert voit l'opération
-- refusée ; l'écran mettait sa caisse à zéro et créait la différence.
-- Banc : outils/bancs/banc-caisses-collectives-local.py --local-jetable (PostgreSQL jetable).
BEGIN;

CREATE TABLE IF NOT EXISTS public.caisses_collectives_operations (
  requete   text PRIMARY KEY,
  acteur    text NOT NULL,
  operation text NOT NULL,
  cible     text NOT NULL,
  resultat  jsonb NOT NULL,
  cree_le   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.caisses_collectives_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.caisses_collectives_operations FROM anon, authenticated;

-- ---------------------------------------------------------------------------------- reçus
CREATE OR REPLACE FUNCTION public.caisse_collective_recu_interne(p_requete text, p_acteur text,
  p_operation text, p_cible text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE r record;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^[a-z]+-[A-Za-z0-9-]{8,100}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('caisse_collective:' || p_requete));
  SELECT * INTO r FROM public.caisses_collectives_operations WHERE requete = p_requete;
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF r.acteur <> p_acteur OR r.operation <> p_operation OR r.cible <> p_cible THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_deja_utilisee');
  END IF;
  RETURN r.resultat || jsonb_build_object('rejeu', true);
END $$;

CREATE OR REPLACE FUNCTION public.caisse_collective_recu_noter_interne(p_requete text, p_acteur text,
  p_operation text, p_cible text, p_resultat jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  INSERT INTO public.caisses_collectives_operations(requete, acteur, operation, cible, resultat)
  VALUES (p_requete, p_acteur, p_operation, p_cible, p_resultat);
  RETURN p_resultat;
END $$;

-- ------------------------------------------------------------------- caisse d'organisation
-- Seule écriture de la caisse d'une organisation : verrou, contrôle de solde, aucun solde négatif.
CREATE OR REPLACE FUNCTION public.organisation_caisse_ajuster_interne(p_orga text, p_delta numeric)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_txt text; v_json jsonb; v_solde numeric;
BEGIN
  SELECT data INTO v_txt FROM public.organisations WHERE id = p_orga FOR UPDATE;
  IF NOT FOUND OR v_txt IS NULL OR NOT (v_txt IS JSON OBJECT) THEN
    RAISE EXCEPTION 'organisation_introuvable: %', p_orga;
  END IF;
  v_json := v_txt::jsonb;
  v_solde := CASE WHEN jsonb_typeof(v_json->'caisse') = 'number' THEN (v_json->>'caisse')::numeric ELSE 0 END;
  IF v_solde + p_delta < 0 THEN RETURN NULL; END IF;
  UPDATE public.organisations
     SET data = jsonb_set(v_json, '{caisse}', to_jsonb(v_solde + p_delta))::text
   WHERE id = p_orga;
  RETURN v_solde + p_delta;
END $$;

-- -------------------------------------------------------------------------- caisse de club
-- Même convention d'historique que crediterBudgetClub et subvention_caisse_crediter :
-- {jour, montant, motif} en queue, 50 derniers conservés. Ligne créée vide si le club n'en a pas.
CREATE OR REPLACE FUNCTION public.club_caisse_ajuster_interne(p_club text, p_delta numeric,
  p_motif text, p_jour integer) RETURNS numeric
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_data jsonb; v_solde numeric; v_hist jsonb; v_n integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.clubs_football WHERE id = p_club) THEN
    RAISE EXCEPTION 'club_introuvable: %', p_club;
  END IF;
  INSERT INTO public.budgets_clubs(id, data, updated_at)
  VALUES (p_club, jsonb_build_object('clubId', p_club, 'caisse', 0, 'historique', '[]'::jsonb,
          'salaires', jsonb_build_object('titulaire', 100, 'remplacant', 50, 'primeVictoire', 150)), now())
  ON CONFLICT (id) DO NOTHING;
  SELECT data INTO v_data FROM public.budgets_clubs WHERE id = p_club FOR UPDATE;
  v_solde := CASE WHEN jsonb_typeof(v_data->'caisse') = 'number' THEN (v_data->>'caisse')::numeric ELSE 0 END;
  IF v_solde + p_delta < 0 THEN RETURN NULL; END IF;
  v_hist := coalesce(CASE WHEN jsonb_typeof(v_data->'historique') = 'array' THEN v_data->'historique' END, '[]'::jsonb)
            || jsonb_build_array(jsonb_build_object('jour', p_jour, 'montant', p_delta, 'motif', p_motif));
  v_n := jsonb_array_length(v_hist);
  IF v_n > 50 THEN
    SELECT jsonb_agg(e ORDER BY n) INTO v_hist
      FROM jsonb_array_elements(v_hist) WITH ORDINALITY t(e, n) WHERE n > v_n - 50;
  END IF;
  UPDATE public.budgets_clubs
     SET data = jsonb_set(jsonb_set(v_data, '{caisse}', to_jsonb(v_solde + p_delta)), '{historique}', v_hist),
         updated_at = now()
   WHERE id = p_club;
  RETURN v_solde + p_delta;
END $$;

-- -------------------------------------------- 1. ordres financiers d'organisation
CREATE OR REPLACE FUNCTION public.organisation_ordre_financier(p_requete text, p_orga text, p_fn text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_recu jsonb; v_json jsonb; v_type text; v_gest text; v_cout record;
        v_paie jsonb; v_solde numeric; v_montant numeric; v_nouveau numeric; v_res jsonb; v_fiche jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_fn NOT IN ('orga_collecte', 'orga_dividendes') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu');
  END IF;
  v_recu := public.caisse_collective_recu_interne(p_requete, v_moi, p_fn, coalesce(p_orga, ''));
  IF v_recu IS NOT NULL THEN RETURN v_recu; END IF;

  SELECT data::jsonb INTO v_json FROM public.organisations WHERE id = p_orga FOR UPDATE;
  IF v_json IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'organisation_introuvable'); END IF;
  v_type := v_json->>'type';
  IF (p_fn = 'orga_collecte' AND v_type IS DISTINCT FROM 'religieuse')
     OR (p_fn = 'orga_dividendes' AND v_type IS DISTINCT FROM 'economique') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_hors_type');
  END IF;
  v_gest := coalesce(nullif(btrim(coalesce(v_json->>'tresorier', '')), ''), v_json->>'chef');
  IF v_gest IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'organisation_sans_responsable'); END IF;
  IF v_gest <> v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_gestionnaire_caisse', 'gestionnaire', v_gest);
  END IF;

  v_solde := CASE WHEN jsonb_typeof(v_json->'caisse') = 'number' THEN (v_json->>'caisse')::numeric ELSE 0 END;
  IF p_fn = 'orga_dividendes' AND floor(v_solde * 0.3) < 10 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide', 'solde', v_solde);
  END IF;

  SELECT pa, cost INTO v_cout FROM public.ordres_couts WHERE fn = p_fn ORDER BY pa, cost LIMIT 1;
  v_paie := public.payer_ordre(v_moi, p_fn, v_cout.pa, v_cout.cost);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  IF p_fn = 'orga_collecte' THEN
    v_montant := 200 + floor(random() * 500);
    v_nouveau := public.organisation_caisse_ajuster_interne(p_orga, v_montant);
  ELSE
    v_montant := floor(v_solde * 0.3);
    v_nouveau := public.organisation_caisse_ajuster_interne(p_orga, -v_montant);
    IF v_nouveau IS NULL THEN RAISE EXCEPTION 'dividendes: caisse insuffisante'; END IF;
    v_fiche := public.assemblee_crediter_joueur(v_moi, v_montant::integer);
  END IF;

  v_res := jsonb_build_object('ok', true, 'ordre', p_fn, 'montant', v_montant, 'caisse', v_nouveau,
                              'paiement', v_paie, 'fiche', v_fiche);
  RETURN public.caisse_collective_recu_noter_interne(p_requete, v_moi, p_fn, p_orga, v_res);
END $$;

-- --------------------------------------- 2. adhésion payante (syndicat des dockers)
CREATE OR REPLACE FUNCTION public.organisation_adhesion_payante(p_requete text, p_orga text, p_grade text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_recu jsonb; v_json jsonb; v_paie jsonb; v_cout record; v_nouveau numeric; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_orga IS DISTINCT FROM 'orga_syndicat_dockers_republic_ville_a' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'adhesion_payante_inconnue');
  END IF;
  v_recu := public.caisse_collective_recu_interne(p_requete, v_moi, 'se_syndiquer', p_orga);
  IF v_recu IS NOT NULL THEN RETURN v_recu; END IF;

  SELECT data::jsonb INTO v_json FROM public.organisations WHERE id = p_orga FOR UPDATE;
  IF v_json IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'organisation_introuvable'); END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_json->'membres', '[]'::jsonb)) m WHERE m->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_membre');
  END IF;

  SELECT pa, cost INTO v_cout FROM public.ordres_couts WHERE fn = 'se_syndiquer' ORDER BY pa, cost LIMIT 1;
  v_paie := public.payer_ordre(v_moi, 'se_syndiquer', v_cout.pa, v_cout.cost);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;

  v_json := jsonb_set(v_json, '{membres}', coalesce(v_json->'membres', '[]'::jsonb) || jsonb_build_array(
    jsonb_build_object('nom', v_moi, 'grade', left(coalesce(nullif(btrim(coalesce(p_grade, '')), ''), 'Adherent'), 60),
                       'gradeIdx', 0, 'rejointLe', coalesce((SELECT day FROM public.personnages_donnees WHERE name = v_moi), 1),
                       'derniereCotisationDate', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))));
  UPDATE public.organisations SET data = v_json::text WHERE id = p_orga;
  v_nouveau := public.organisation_caisse_ajuster_interne(p_orga, v_cout.cost);

  v_res := jsonb_build_object('ok', true, 'caisse', v_nouveau, 'paiement', v_paie);
  RETURN public.caisse_collective_recu_noter_interne(p_requete, v_moi, 'se_syndiquer', p_orga, v_res);
END $$;

-- --------------------------------------------- 3. cotisation au club de supporters
CREATE OR REPLACE FUNCTION public.club_supporters_cotiser(p_requete text, p_club text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_recu jsonb; v_cout record; v_paie jsonb; v_nouveau numeric; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.clubs_football WHERE id = p_club) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_introuvable');
  END IF;
  v_recu := public.caisse_collective_recu_interne(p_requete, v_moi, 'rejoindre_club_supporters', p_club);
  IF v_recu IS NOT NULL THEN RETURN v_recu; END IF;

  SELECT pa, cost INTO v_cout FROM public.ordres_couts WHERE fn = 'rejoindre_club_supporters' ORDER BY pa, cost LIMIT 1;
  v_paie := public.payer_ordre(v_moi, 'rejoindre_club_supporters', v_cout.pa, v_cout.cost);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;
  v_nouveau := public.club_caisse_ajuster_interne(p_club, v_cout.cost, 'Cotisation supporter',
                 coalesce((SELECT day FROM public.personnages_donnees WHERE name = v_moi), 1));
  v_res := jsonb_build_object('ok', true, 'caisse', v_nouveau, 'paiement', v_paie);
  RETURN public.caisse_collective_recu_noter_interne(p_requete, v_moi, 'rejoindre_club_supporters', p_club, v_res);
END $$;

-- ------------------------------------------------------------------ 4. sponsoring
CREATE OR REPLACE FUNCTION public.club_sponsoriser(p_requete text, p_club text, p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_recu jsonb; v_inf integer; v_label text; v_cout record; v_paie jsonb;
        v_dispo numeric; v_nouveau numeric; v_res_j jsonb; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_inf := CASE p_montant WHEN 500 THEN 2 WHEN 1500 THEN 5 WHEN 3000 THEN 10 END;
  v_label := CASE p_montant WHEN 500 THEN 'Sponsor bronze' WHEN 1500 THEN 'Sponsor argent' WHEN 3000 THEN 'Sponsor officiel' END;
  IF v_inf IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'palier_inconnu'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.clubs_football WHERE id = p_club) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_introuvable');
  END IF;
  v_recu := public.caisse_collective_recu_interne(p_requete, v_moi, 'sponsoriser_club', p_club);
  IF v_recu IS NOT NULL THEN RETURN v_recu; END IF;

  SELECT coalesce(pd.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires c
           WHERE c.personnage = v_moi AND c.banque = 'nationale'), 0)
    INTO v_dispo FROM public.personnages_donnees pd WHERE pd.name = v_moi;
  IF coalesce(v_dispo, 0) < p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'disponible', coalesce(v_dispo, 0));
  END IF;

  SELECT pa, cost INTO v_cout FROM public.ordres_couts WHERE fn = 'sponsoriser_club' ORDER BY pa, cost LIMIT 1;
  v_paie := public.payer_ordre(v_moi, 'sponsoriser_club', v_cout.pa, v_cout.cost);
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'), 'paiement', v_paie);
  END IF;
  IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, p_montant) THEN
    RAISE EXCEPTION 'sponsoring: fonds insuffisants apres controle';
  END IF;

  SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_res_j FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  v_res_j := jsonb_set(v_res_j, '{inf}', to_jsonb(least(100, coalesce((v_res_j->>'inf')::numeric, 0) + v_inf)));
  UPDATE public.personnages_donnees SET resources = v_res_j WHERE name = v_moi;

  v_nouveau := public.club_caisse_ajuster_interne(p_club, p_montant, v_label || ' — ' || v_moi,
                 coalesce((SELECT day FROM public.personnages_donnees WHERE name = v_moi), 1));
  v_res := jsonb_build_object('ok', true, 'caisse', v_nouveau, 'inf', v_res_j->'inf', 'paiement', v_paie,
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'solde_national', coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage = v_moi AND banque = 'nationale'), 0));
  RETURN public.caisse_collective_recu_noter_interne(p_requete, v_moi, 'sponsoriser_club', p_club, v_res);
END $$;

-- ------------------------------------------------------- 5. transfert conclu par le joueur
CREATE OR REPLACE FUNCTION public.club_transfert_conclure(p_transfert text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_row record; v_t jsonb; v_prix numeric; v_jour integer; v_arr numeric; v_dep numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_row FROM public.transferts_clubs WHERE id = p_transfert FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'transfert_introuvable'); END IF;
  v_t := v_row.data;
  IF v_t->>'joueur' IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_joueur');
  END IF;
  IF v_row.statut = 'termine' AND v_t->>'concluPar' = v_moi THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'transfert', v_t);
  END IF;
  IF v_row.statut IS DISTINCT FROM 'attente_joueur' OR v_t->>'statut' IS DISTINCT FROM 'attente_joueur' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'transfert_non_ouvert', 'statut', v_row.statut);
  END IF;
  v_prix := CASE WHEN jsonb_typeof(v_t->'prixClub') = 'number' THEN (v_t->>'prixClub')::numeric END;
  IF v_prix IS NULL OR v_prix < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  v_jour := coalesce((SELECT day FROM public.personnages_donnees WHERE name = v_moi), 1);

  -- Ordre des verrous stable (identifiant croissant) pour éviter l'interblocage entre deux transferts.
  PERFORM 1 FROM public.budgets_clubs WHERE id IN (v_t->>'clubDepartId', v_t->>'clubArriveeId') ORDER BY id FOR UPDATE;
  v_arr := public.club_caisse_ajuster_interne(v_t->>'clubArriveeId', -v_prix, 'Transfert de ' || v_moi, v_jour);
  IF v_arr IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_club_insuffisante');
  END IF;
  v_dep := public.club_caisse_ajuster_interne(v_t->>'clubDepartId', v_prix, 'Transfert de ' || v_moi, v_jour);

  v_t := v_t || jsonb_build_object('statut', 'termine', 'concluPar', v_moi, 'concluLe', now());
  UPDATE public.transferts_clubs SET statut = 'termine', data = v_t, updated_at = now() WHERE id = p_transfert;
  RETURN jsonb_build_object('ok', true, 'transfert', v_t, 'caisseArrivee', v_arr, 'caisseDepart', v_dep);
END $$;

-- ------------------------------------------------------------- 6. salaires du club
CREATE OR REPLACE FUNCTION public.club_salaires_fixer(p_club text, p_titulaire integer,
  p_remplacant integer, p_prime integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_data jsonb; v_sal jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF (SELECT data->>'president' FROM public.presidents_clubs WHERE id = p_club) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_president');
  END IF;
  IF least(p_titulaire, p_remplacant, p_prime) < 0 OR greatest(p_titulaire, p_remplacant, p_prime) > 100000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;
  PERFORM public.club_caisse_ajuster_interne(p_club, 0, 'Salaires mis à jour',
            coalesce((SELECT day FROM public.personnages_donnees WHERE name = v_moi), 1));
  v_sal := jsonb_build_object('titulaire', p_titulaire, 'remplacant', p_remplacant, 'primeVictoire', p_prime);
  UPDATE public.budgets_clubs SET data = jsonb_set(data, '{salaires}', v_sal), updated_at = now()
   WHERE id = p_club RETURNING data INTO v_data;
  RETURN jsonb_build_object('ok', true, 'salaires', v_sal, 'caisse', v_data->'caisse');
END $$;

-- ------------------------------------- 7. subvention ministérielle à un club ou une organisation
CREATE OR REPLACE FUNCTION public.subvention_collective_verser(p_requete text, p_type text, p_id text, p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_moi text; v_recu jsonb; v_pays text; v_jour integer; v_caisse text; v_data jsonb;
        v_solde numeric; v_verse numeric; v_nouveau numeric; v_res jsonb;
BEGIN
  v_moi := public.exiger_poste('min_fin');
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_type NOT IN ('club_sportif', 'organisation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_non_couvert');
  END IF;
  IF p_montant IS NULL OR p_montant < 1 OR p_montant > 5000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;
  IF (p_type = 'club_sportif' AND NOT EXISTS (SELECT 1 FROM public.clubs_football WHERE id = p_id))
     OR (p_type = 'organisation' AND NOT EXISTS (SELECT 1 FROM public.organisations WHERE id = p_id)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_introuvable');
  END IF;
  v_recu := public.caisse_collective_recu_interne(p_requete, v_moi, 'subvention_' || p_type, p_id);
  IF v_recu IS NOT NULL THEN RETURN v_recu; END IF;

  SELECT country, coalesce(day, 1) INTO v_pays, v_jour FROM public.personnages_donnees WHERE name = v_moi;
  v_caisse := v_pays || '_gouvernement-min_fin';
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  v_solde := CASE WHEN jsonb_typeof(v_data->'solde') = 'number' THEN (v_data->>'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(coalesce(v_solde, 0), 0), p_montant);
  IF v_verse <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'verse', 0); END IF;
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse), updated_at = now()
   WHERE id = v_caisse;

  IF p_type = 'club_sportif' THEN
    v_nouveau := public.club_caisse_ajuster_interne(p_id, v_verse, 'Subvention ministérielle', v_jour);
  ELSE
    v_nouveau := public.organisation_caisse_ajuster_interne(p_id, v_verse);
  END IF;
  v_res := jsonb_build_object('ok', true, 'verse', v_verse, 'caisse', v_nouveau, 'beneficiaire', p_id);
  RETURN public.caisse_collective_recu_noter_interne(p_requete, v_moi, 'subvention_' || p_type, p_id, v_res);
END $$;

-- ------------------------------------------------------------------------------- droits
REVOKE ALL ON FUNCTION public.caisse_collective_recu_interne(text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.caisse_collective_recu_noter_interne(text, text, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.organisation_caisse_ajuster_interne(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.club_caisse_ajuster_interne(text, numeric, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.organisation_ordre_financier(text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.organisation_adhesion_payante(text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_supporters_cotiser(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_sponsoriser(text, text, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_transfert_conclure(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_salaires_fixer(text, integer, integer, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.subvention_collective_verser(text, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.organisation_ordre_financier(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.organisation_adhesion_payante(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_supporters_cotiser(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_sponsoriser(text, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_transfert_conclure(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_salaires_fixer(text, integer, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.subvention_collective_verser(text, text, text, integer) TO authenticated;

COMMIT;
