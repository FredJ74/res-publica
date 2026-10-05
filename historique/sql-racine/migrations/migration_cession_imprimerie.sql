-- =====================================================================
-- CESSION D'UNE IMPRIMERIE DE REPUBLIA A UN PJ (12 septembre 2026)
-- =====================================================================
-- Arbitrage : le prix de cession (180 000 FR) est verse dans la CAISSE DU MINISTERE DES FINANCES
-- de Republia. Ni argent detruit, ni recette de l'imprimerie, ni recette du journal, ni recette du
-- notaire. La caisse concernee existe deja et n'est PAS recreee ici : c'est la ligne
-- caisses_batiments '<pays>_gouvernement-min_fin', deja alimentee par la preemption d'Etat et lue
-- par le Bureau du Ministre des Finances. Le pays est celui inscrit dans la ligne de propriete,
-- jamais un parametre client.
--
-- POURQUOI UNE RPC ET PAS DU CODE CLIENT : le pipeline notarial faisait deux ecritures REST
-- independantes (debit du joueur, puis ecriture de la propriete), et le prix n'etait credite
-- nulle part. Sur 180 000 FR, chaque defaillance est inacceptable :
--   - propriete transferee sans paiement  -> l'imprimerie serait gratuite ;
--   - paiement sans propriete transferee  -> le joueur perdrait 180 000 FR ;
--   - credit partiel ou double credit     -> creation/destruction de monnaie.
-- Le credit de la caisse ET l'inscription de la propriete ont donc lieu dans UNE SEULE
-- transaction : soit les deux, soit aucun. Le double-clic et la concurrence sont couverts par
-- l'idempotence sur l'id de requete (assemblee_requetes) : un rejeu renvoie le resultat de la
-- premiere execution sans rien recrediter. La ligne entreprises est verrouillee (FOR UPDATE), et
-- l'etat du compromis est reverifie serveur, si bien que deux acheteurs simultanes ne peuvent pas
-- tous deux finaliser.
--
-- LE PRIX N'EST PAS UN PARAMETRE DE CONFIANCE : le serveur porte sa propre constante et refuse
-- tout montant different. L'acompte de 1 000 FR deja verse reste deduit du solde reclame au
-- joueur (179 000 FR) : le joueur paie 180 000 FR au total, jamais 181 000, et la caisse recoit
-- exactement le prix de cession, une seule fois.
--
-- CE QUI N'EST PAS TOUCHE : la mecanique commune du compromis (acompte a la signature, perte a
-- l'expiration, remboursement en cas de refus de pret par le cron) est inchangee ; les caisses de
-- l'imprimerie et de la redaction (batiments_etat) ne sont ni lues ni modifiees ici.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.imprimerie_cession_finaliser(
  p_requete       text,
  p_acheteur      text,
  p_imprimerie_id text,
  p_prix          numeric,
  p_jour          integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  -- Prix de cession fait autorite cote serveur (PRIX_RACHAT_IMPRIMERIE cote client).
  c_prix     constant numeric := 180000;
  v_rej      jsonb;
  v_data     jsonb;
  v_pays     text;
  v_caisse   text;
  v_acompte  numeric;
  v_expire   numeric;
  v_mvt      jsonb;
  v_hist     jsonb;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_acheteur, 'cession_imprimerie');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_imprimerie_id), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'imprimerie_invalide'));
  END IF;
  IF p_prix IS DISTINCT FROM c_prix THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'prix_invalide', 'prix', c_prix));
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_imprimerie_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'imprimerie_introuvable'));
  END IF;
  IF v_data ->> 'type' IS DISTINCT FROM 'imprimerie' THEN
    -- Cette RPC ne finalise QUE des imprimeries : elle ne doit pas devenir un chemin de rachat
    -- generique pour les armureries ou les commerces, qui ont leur propre circuit.
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'bien_non_imprimerie'));
  END IF;
  IF v_data ->> 'proprietaire' IS DISTINCT FROM 'PNJ' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vendue',
                                                                        'proprietaire', v_data ->> 'proprietaire'));
  END IF;
  IF COALESCE((v_data -> 'compromis')::text, 'false') <> 'true'
     OR v_data ->> 'compromisPar' IS DISTINCT FROM p_acheteur THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'compromis_invalide'));
  END IF;
  -- compromisExpireAt est un epoch en millisecondes (Date.now() cote client).
  v_expire := CASE WHEN jsonb_typeof(v_data -> 'compromisExpireAt') = 'number'
                   THEN (v_data ->> 'compromisExpireAt')::numeric ELSE NULL END;
  IF v_expire IS NOT NULL AND v_expire < extract(epoch FROM now()) * 1000 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'compromis_expire'));
  END IF;

  v_pays := COALESCE(NULLIF(btrim(v_data ->> 'country'), ''), 'republic');
  v_caisse := v_pays || '_gouvernement-min_fin';
  v_acompte := CASE WHEN jsonb_typeof(v_data -> 'acompte') = 'number'
                    THEN (v_data ->> 'acompte')::numeric ELSE 0 END;

  -- Credit de la caisse du Ministere des Finances. exiger_existant = true : si cette caisse
  -- n'existait pas, la cession est refusee plutot que de creer une caisse fantome.
  v_mvt := public.caisse_institution_mouvement(v_caisse, c_prix, true);
  IF COALESCE((v_mvt -> 'ok')::text, 'false') <> 'true' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'caisse_etat_indisponible', 'detail', v_mvt -> 'raison'));
  END IF;

  -- Propriete inscrite dans la MEME transaction que le credit.
  v_hist := CASE WHEN jsonb_typeof(v_data -> 'historique') = 'array' THEN v_data -> 'historique' ELSE '[]'::jsonb END;
  v_hist := v_hist || jsonb_build_array(jsonb_build_object(
    'jour', COALESCE(p_jour, 1), 'montant', 0,
    'motif', 'Rachat de l''entreprise par ' || p_acheteur || ' (acte notarié)'));
  IF jsonb_array_length(v_hist) > 50 THEN
    v_hist := (SELECT jsonb_agg(e) FROM (
      SELECT e FROM jsonb_array_elements(v_hist) WITH ORDINALITY t(e, n)
       ORDER BY n OFFSET jsonb_array_length(v_hist) - 50) s);
  END IF;

  UPDATE public.entreprises
     SET data = (v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt' - 'compromisExpireAt')
                || jsonb_build_object('proprietaire', p_acheteur, 'historique', v_hist),
         updated_at = now()
   WHERE id = p_imprimerie_id;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'prix', c_prix, 'acompte', v_acompte, 'solde', c_prix - v_acompte,
    'caisse_id', v_caisse, 'caisse_solde', v_mvt -> 'solde', 'proprietaire', p_acheteur));
END;
$$;

REVOKE ALL ON FUNCTION public.imprimerie_cession_finaliser(text, text, text, numeric, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.imprimerie_cession_finaliser(text, text, text, numeric, integer) TO anon, authenticated, service_role;
