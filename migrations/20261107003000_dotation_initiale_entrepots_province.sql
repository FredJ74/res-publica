-- DOTATION INITIALE DES ENTREPOTS DE PROVINCE (Claude, 07/11/2026, decision de Fred)
--
-- Constat : les entrepots de PSM et Montrouge n'ont que leur part de 40 % des recettes
-- municipales ; leur caisse est tombee a 2 FR et la passe des livraisons les trouve « sans
-- tresorerie » (cereales et viande a 0, seules matieres qui se vident chaque jour).
-- Decision de Fred : une dotation initiale pour qu'ils tournent avec des stocks pleins.
--
-- Montant (choix technique de Claude) : caisse portee a 10 000 FR, comme les entrepots de
-- Sovarka. Remplir le stock coute ~550 FR ce soir ; le reste couvre plusieurs semaines de
-- reapprovisionnement. Une seule fois : ne verse que si la caisse est sous 10 000 FR, et
-- jamais deux fois (journal 'dotation_initiale'). Journalisee dans entrepot_journal.

DO $migration$
DECLARE
  v_ent text; v_caisse text; v_solde numeric; v_delta numeric; v_rep jsonb;
BEGIN
  FOR v_ent, v_caisse IN VALUES
    ('republic_ville_a_entrepot-logistique-psm', 'republic_entrepot_ville_a'),
    ('republic_ville_b_entrepot-logistique-montrouge', 'republic_entrepot_ville_b')
  LOOP
    IF EXISTS (SELECT 1 FROM public.entrepot_journal
                WHERE entrepot_id = v_ent AND operation = 'dotation_initiale') THEN
      CONTINUE;
    END IF;
    SELECT (data->>'solde')::numeric INTO v_solde FROM public.caisses_batiments
     WHERE id = v_caisse FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'caisse absente : %', v_caisse;
    END IF;
    v_delta := 10000 - coalesce(v_solde, 0);
    IF v_delta <= 0 THEN CONTINUE; END IF;
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement(v_caisse, v_delta, true);
    PERFORM set_config('rp.caisse_interne', '', true);
    IF (v_rep->>'ok')::boolean IS NOT TRUE THEN
      RAISE EXCEPTION 'dotation refusee pour % : %', v_caisse, v_rep;
    END IF;
    INSERT INTO public.entrepot_journal (entrepot_id, jour, operation, sens, contrepartie, montant, statut)
    VALUES (v_ent, (now() AT TIME ZONE 'Europe/Paris')::date, 'dotation_initiale', 'entree',
            'Etat de Republia', v_delta, 'livre');
  END LOOP;
END
$migration$;
