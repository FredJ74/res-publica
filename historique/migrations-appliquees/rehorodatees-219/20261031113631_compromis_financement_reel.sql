-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261024123500_compromis_financement_reel.sql ; aucun changement de règle.
-- Reutilise le resolveur de compromis vivant ; dette et virement par le moteur national commun.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.compromis_expire_resoudre(text,text)');
IF h='d3e35ecf0edb0b1c2a6858f5ad6f1b81' THEN
d:=replace(d,$a$    IF v_arg >= v_montant * 0.10 OR random() < 0.5 THEN$a$,$b$    IF v_type='terrain' AND (NOT EXISTS(SELECT 1 FROM public.comptes_bancaires WHERE personnage=v_pret->>'demandeur' AND banque='nationale') OR EXISTS(SELECT 1 FROM public.prets WHERE emprunteur=v_pret->>'demandeur' AND type_pret='immobilier' AND statut='en_cours')) THEN v_refus:=true;END IF;
    IF v_arg >= v_montant * 0.10 OR random() < 0.5 THEN$b$);
d:=replace(d,$a$  -- LE VERROU SUR LE BIEN$a$,$b$  IF v_type='terrain' THEN
    PERFORM 1 FROM public.personnages_donnees WHERE name=(SELECT data::jsonb->>'compromisPar' FROM public.terrains_etat WHERE id=p_cible) FOR UPDATE;
  END IF;
  -- LE VERROU SUR LE BIEN$b$);
d:=replace(d,$a$IF v_arg >= v_montant * 0.10 OR random() < 0.5 THEN$a$,$b$IF NOT v_refus AND (v_arg >= v_montant * 0.10 OR random() < 0.5) THEN$b$);
d:=replace(d,$a$      IF coalesce(v_existe, false) THEN
        UPDATE public.personnages SET arg = coalesce(arg,0) + v_montant
         WHERE name = v_pret->>'demandeur';
        INSERT INTO public.prets (id, emprunteur, country, building_id, type_banque,
            montant_initial, montant_restant, duree_jours, mensualite, jours_impayes, statut)
        VALUES ('pret-' || v_type || '-' || p_cible || '-' || v_jour, v_pret->>'demandeur',
            v_pays, v_bat, 'nationale', v_montant, (v_pret->>'montantTotal')::numeric,
            (v_pret->>'duree')::integer, (v_pret->>'mensualite')::numeric, 0, 'en_cours')
        ON CONFLICT (id) DO NOTHING;
      END IF;
$a$,$b$      IF v_type='terrain' THEN
        IF NOT coalesce(v_existe,false) OR v_pret->>'demandeur' IS DISTINCT FROM v_data->>'compromisPar' THEN RAISE EXCEPTION 'demandeur_incoherent';END IF;
        PERFORM public.pret_national_creer_interne(v_pret->>'demandeur',v_montant,(v_pret->>'duree')::integer,'immobilier',v_bat,
          'acquisition-'||p_cible||'-'||coalesce(v_data->>'acquisitionRequete',v_data->>'compromisAt'),
          (SELECT (r.resultat->'pretCapture'->>'taux')::numeric FROM public.terrain_acquisitions_recus r WHERE r.acteur=v_pret->>'demandeur' AND r.terrain=p_cible AND r.requete::text=v_data->>'acquisitionRequete' AND r.action='compromis'));
      ELSE
      IF coalesce(v_existe, false) THEN
        UPDATE public.personnages SET arg = coalesce(arg,0) + v_montant
         WHERE name = v_pret->>'demandeur';
        INSERT INTO public.prets (id, emprunteur, country, building_id, type_banque,
            montant_initial, montant_restant, duree_jours, mensualite, jours_impayes, statut)
        VALUES ('pret-' || v_type || '-' || p_cible || '-' || v_jour, v_pret->>'demandeur',
            v_pays, v_bat, 'nationale', v_montant, (v_pret->>'montantTotal')::numeric,
            (v_pret->>'duree')::integer, (v_pret->>'mensualite')::numeric, 0, 'en_cours')
        ON CONFLICT (id) DO NOTHING;
      END IF;
      END IF;
$b$);
d:=replace(d,$a$    UPDATE public.personnages SET arg = coalesce(arg,0) + v_acompte WHERE name = v_par;$a$,$b$    IF v_type='terrain' THEN PERFORM public.helvetia_crediter_destination(v_par,v_acompte,'liquide');END IF;
    UPDATE public.personnages SET arg = coalesce(arg,0) + v_acompte WHERE name = v_par;$b$);
d:=replace(d,$a$v_prefixe || p_cible || '-' || v_jour$a$,$b$v_prefixe || p_cible || '-' || v_jour || coalesce('-'||(v_data->>'acquisitionRequete'),'')$b$);
EXECUTE d;ELSIF h IS DISTINCT FROM 'e683b9cda0a4080b545da328d2f6481c' THEN RAISE EXCEPTION 'definition_non_examinee: compromis_expire_resoudre';END IF;END;$g$;
COMMIT;
