-- =====================================================================================
-- AMENDE DE FAUSSE DÉCLARATION ATTACHÉE À LA CAISSE (#433, règle de Fred du 04/11/2026)
--
-- L'expéditeur, souvent étranger, échappe à la loi républienne : il peut ignorer l'injonction
-- de payer. L'amende n'est donc plus prélevée d'office sur lui (contrat des sanctions) : elle
-- reste due SUR LA CAISSE (`amende_due`).
--   * l'expéditeur peut la régler (fret_caisse_commande 'amende_payer') ;
--   * sinon le destinataire qui veut sa commande la paie avec le dédouanement (fret_dedouaner) ;
--     ce qu'il règle ensuite avec le vendeur ne se code pas ;
--   * si personne ne paie, la caisse non réclamée passe en vente (J15, passe de minuit) et le
--     produit de la vente va au Trésor au lieu de la caisse du port.
-- Montant inchangé : 2 × 10 % × valeur de référence de ce qui n'est pas déclaré.
-- Banc : outils/bancs/banc-fret-amende-caisse.sql.
-- =====================================================================================

ALTER TABLE public.caisses_fret ADD COLUMN IF NOT EXISTS amende_due integer NOT NULL DEFAULT 0;
ALTER TABLE public.caisses_fret ADD COLUMN IF NOT EXISTS amende_payee boolean NOT NULL DEFAULT false;

-- Crédit du Trésor national (même réserve que le contrat commun des sanctions).
CREATE OR REPLACE FUNCTION public.fret_tresor_crediter_interne(p_pays text, p_montant numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE nat jsonb;
BEGIN
  IF coalesce(p_montant, 0) <= 0 THEN RETURN jsonb_build_object('ok', true, 'montant', 0); END IF;
  SELECT data INTO nat FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'tresor_introuvable'); END IF;
  UPDATE public.budgets_nationaux
     SET data = jsonb_set(coalesce(nat, '{}'::jsonb), '{reserveJour}', to_jsonb(coalesce((nat->>'reserveJour')::numeric, 0) + p_montant)),
         updated_at = now()
   WHERE id = p_pays;
  RETURN jsonb_build_object('ok', true, 'montant', p_montant);
END; $$;
REVOKE ALL ON FUNCTION public.fret_tresor_crediter_interne(text, numeric) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.fret_inspecter_interne(p_caisse uuid, p_origine text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c public.caisses_fret%ROWTYPE; l record; v_pays text; v_saisis jsonb := '[]'::jsonb;
  v_valeur numeric := 0; v_amende integer := 0; v_dep text; v_noms text;
  v_jour integer; v_heure integer;
BEGIN
  SELECT * INTO c FROM public.caisses_fret WHERE id = p_caisse FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  v_pays := coalesce(CASE WHEN c.statut = 'arrivee' THEN c.pays_destination ELSE c.pays_origine END, 'republic');
  FOR l IN SELECT * FROM public.contenu_caisses_fret WHERE caisse_id = p_caisse AND quantite > 0 ORDER BY date_depot, id FOR UPDATE LOOP
    IF (coalesce((l.objet->>'legal')::boolean, true) = false
        OR public.assemblee_loi_en_vigueur(v_pays, l.objet, now()) IS NOT NULL)
       AND NOT public.inventaire_objet_protege(NULL, l.objet) THEN
      v_saisis := v_saisis || jsonb_build_array(jsonb_build_object('ligne', l.id, 'deposant', l.deposant,
        'nom', coalesce(l.objet->>'name', l.objet->>'type', '?'), 'type', l.objet->>'type', 'quantite', l.quantite));
      INSERT INTO public.confiscations_douanieres(id, personne, objet_nom, objet_type, quantite, pays, ville, building_id, room_id, reference)
      VALUES ('conf-' || gen_random_uuid()::text, l.deposant, coalesce(l.objet->>'name', '?'), l.objet->>'type', l.quantite,
        v_pays, coalesce(CASE WHEN c.statut = 'arrivee' THEN c.ville_destination ELSE c.ville_origine END, 'ville_a'),
        coalesce(CASE WHEN c.statut = 'arrivee' THEN c.building_destination ELSE c.building_origine END, 'port-sainte-marie'),
        'douanes', 'fret-' || p_caisse::text);
      UPDATE public.contenu_caisses_fret SET quantite = 0 WHERE id = l.id;
    ELSIF NOT l.declaree THEN
      v_valeur := v_valeur + public.fret_valeur_reference_interne(l.objet, l.quantite);
    END IF;
  END LOOP;

  SELECT coalesce(day, 1), extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer
    INTO v_jour, v_heure FROM public.personnages_donnees WHERE name = c.leader;
  FOR v_dep, v_noms IN SELECT s->>'deposant', string_agg(s->>'nom', ', ') FROM jsonb_array_elements(v_saisis) s GROUP BY 1 LOOP
    UPDATE public.personnages_donnees SET convocations = coalesce(convocations, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
      'id', 'conv-' || replace(gen_random_uuid()::text, '-', ''), 'motif', 'possession_illegale_douane',
      'jourEmission', coalesce(v_jour, 1), 'heureEmission', v_heure, 'jourLimite', coalesce(v_jour, 1) + 1, 'heureLimite', v_heure,
      'traitee', false, 'limiteTs', to_char((now() + interval '24 hours') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
     WHERE name = v_dep;
    PERFORM public.mail_systeme_poser_interne('Chef des Douanes', v_dep, 'Convocation officielle',
      'Un contrôle douanier a détecté et confisqué du contenu prohibé dans une caisse de fret que vous avez approvisionnée ('
      || v_noms || '). Présentez-vous au commissariat sous 24h pour vous justifier, faute de quoi vous serez arrêté(e).');
  END LOOP;

  -- L'amende reste due sur la caisse (règle de Fred du 04/11).
  v_amende := floor(2 * 0.10 * v_valeur)::integer;
  IF v_amende > 0 THEN
    UPDATE public.caisses_fret SET amende_due = coalesce(amende_due, 0) + v_amende, amende_payee = false WHERE id = p_caisse;
    PERFORM public.mail_systeme_poser_interne('Douanes du port', c.leader, 'Injonction de payer une amende',
      'Une inspection de votre caisse de fret a révélé des marchandises non déclarées. Amende : ' || v_amende
      || ' FR au Trésor (double des droits de douane sur leur valeur), payable au port. À défaut, le destinataire devra la régler pour retirer la caisse ; si personne ne paie, la caisse sera saisie et vendue au profit du Trésor.');
  END IF;

  RETURN jsonb_build_object('ok', true, 'origine', p_origine, 'saisis', v_saisis,
    'valeur_non_declaree', v_valeur, 'amende', v_amende);
END; $$;
REVOKE ALL ON FUNCTION public.fret_inspecter_interne(uuid, text) FROM PUBLIC, anon, authenticated;

-- L'expéditeur (ou le destinataire) règle l'amende due sur la caisse.
DO $patch$
DECLARE d text; f text := E'  RETURN jsonb_build_object(''ok'', false, ''raison'', ''action_inconnue'');';
BEGIN
  d := pg_get_functiondef('public.fret_caisse_commande_interne(text,text,uuid,jsonb)'::regprocedure);
  IF position('amende_payer' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, f, ''))) / length(f) <> 1 THEN RAISE EXCEPTION 'fragment_action_inconnue_introuvable'; END IF;
  d := replace(d, f, E'  IF p_action = ''amende_payer'' THEN\n'
    || E'    IF p_acteur IS DISTINCT FROM c.leader AND p_acteur IS DISTINCT FROM c.destinataire THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_concerne''); END IF;\n'
    || E'    IF coalesce(c.amende_due, 0) <= 0 OR c.amende_payee THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''aucune_amende''); END IF;\n'
    || E'    IF c.statut NOT IN (''fermee'', ''en_transit'', ''arrivee'') THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''caisse_saisie''); END IF;\n'
    || E'    IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, c.amende_due) THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''fonds_insuffisants'', ''requis'', c.amende_due); END IF;\n'
    || E'    v := public.fret_tresor_crediter_interne(coalesce(c.pays_destination, c.pays_origine, ''republic''), c.amende_due);\n'
    || E'    IF coalesce((v->>''ok'')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION ''amende_tresor_non_creditee''; END IF;\n'
    || E'    UPDATE public.caisses_fret SET amende_payee = true WHERE id = c.id;\n'
    || E'    RETURN jsonb_build_object(''ok'', true, ''amende'', c.amende_due);\n'
    || E'  END IF;\n' || f);
  EXECUTE d;
END $patch$;

-- Dédouanement : l'amende encore due s'ajoute aux droits et va au Trésor.
CREATE OR REPLACE FUNCTION public.fret_dedouaner(p_caisse_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; c record; v_val numeric; v_jours int; v_factures int;
  v_douane numeric; v_gard numeric; v_amende numeric; v_total numeric; v_caisse text; v_mvt jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO c FROM public.caisses_fret WHERE id = p_caisse_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  IF c.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire');
  END IF;
  IF COALESCE(c.dedouanee, false) THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'deja_dedouanee');
  END IF;
  IF COALESCE(c.statut, '') <> 'arrivee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide', 'statut', c.statut);
  END IF;

  v_val := GREATEST(0, COALESCE(c.valeur_declaree, 0));
  v_douane := round(v_val * 10 / 100.0);
  v_gard := 0;
  IF c.date_arrivee_reelle IS NOT NULL THEN
    v_jours := floor(EXTRACT(epoch FROM (now() - c.date_arrivee_reelle)) / 86400)::int;
    v_factures := GREATEST(0, v_jours - 7);
    IF v_factures > 0 THEN v_gard := round(v_val * 1 / 100.0 * v_factures); END IF;
  END IF;
  v_amende := CASE WHEN COALESCE(c.amende_payee, false) THEN 0 ELSE GREATEST(0, COALESCE(c.amende_due, 0)) END;
  v_total := v_douane + v_gard + v_amende;

  IF v_total > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, v_total) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total,
                                'douane', v_douane, 'gardiennage', v_gard, 'amende', v_amende);
    END IF;
    -- Droits et gardiennage à la caisse du port, amende au Trésor, dans la même transaction.
    v_caisse := c.pays_destination || '_' || c.building_destination;
    IF v_douane + v_gard > 0 THEN
      v_mvt := public.caisse_institution_mouvement(v_caisse, v_douane + v_gard, false);
      IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN
        RAISE EXCEPTION 'credit_caisse_port_impossible: %', COALESCE(v_mvt->>'raison','?');
      END IF;
    END IF;
    IF v_amende > 0 THEN
      v_mvt := public.fret_tresor_crediter_interne(c.pays_destination, v_amende);
      IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'amende_tresor_non_creditee'; END IF;
    END IF;
  END IF;

  UPDATE public.caisses_fret
     SET dedouanee = true, date_dedouanement = now(), amende_payee = (amende_payee OR v_amende > 0)
   WHERE id = p_caisse_id;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'douane', v_douane,
    'gardiennage', v_gard, 'amende', v_amende, 'jours_factures', COALESCE(v_factures, 0), 'caisse', v_caisse,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END; $function$;

-- Vente d'une caisse non réclamée dont l'amende reste impayée : au profit du Trésor.
DO $patch$
DECLARE d text; f text := E'v:=public.caisse_institution_mouvement(c.pays_destination||''_''||c.building_destination,prix,false);';
BEGIN
  d := pg_get_functiondef('public.fret_objet_agir(uuid,uuid,text,uuid,integer,integer,bigint)'::regprocedure);
  IF position('fret_tresor_crediter_interne' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, f, ''))) / length(f) <> 1 THEN RAISE EXCEPTION 'fragment_vente_introuvable'; END IF;
  d := replace(d, f, E'IF coalesce(c.amende_due,0)>0 AND NOT coalesce(c.amende_payee,false) THEN v:=public.fret_tresor_crediter_interne(c.pays_destination,prix); ELSE '
    || f || E' END IF;');
  EXECUTE d;
END $patch$;
