-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029122005.
-- Archivage documentaire seulement ; ne pas rejouer.
-- CHANTIER À L'ARRÊT FAUTE DE MATÉRIAUX : COURRIER AU MAÎTRE D'OUVRAGE (29/10/2026, Claude).
-- Décision de Fred (29/10) : comme pour le manque d'argent, le propriétaire reçoit un courrier
-- quand l'entrepôt ne peut pas fournir les matériaux de la journée. Un seul courrier par arrêt :
-- le marqueur `manqueMateriauxAvise` est posé au premier jour bloqué et retiré dès que le
-- chantier est de nouveau approvisionné. Un échec d'envoi ne bloque jamais la journée. Idempotente.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.chantier_jour_traiter(text)'::regprocedure);
  IF strpos(v_def, 'manqueMateriauxAvise') > 0 THEN RETURN; END IF;
  v_new := replace(v_def, $a$   SELECT valeur INTO taux FROM public.entreprises_constantes WHERE cle='chantier_taux_horaire';$a$,
    $n$   IF f<1 THEN
    IF ch->>'manqueMateriauxAvise' IS NULL THEN
     BEGIN
      PERFORM public.mail_systeme_poser_interne('Chantier', ch->>'maitreOuvrage', 'Chantier à l''arrêt : matériaux manquants',
        'L''entrepôt de la ville ne peut pas fournir assez de '
        || (SELECT string_agg(CASE m2 WHEN 'metal' THEN 'métal' ELSE m2 END, ', ') FROM unnest(ARRAY['bois','minerai','metal']) m2
             WHERE coalesce((besoin->>m2)::numeric,0) > coalesce((stock->>m2)::numeric,0))
        || ' pour la journée de travail. Le chantier reprendra dès que l''entrepôt sera réapprovisionné, ou si des matériaux sont apportés au chantier.', NULL);
     EXCEPTION WHEN others THEN NULL;
     END;
     ch:=ch||jsonb_build_object('manqueMateriauxAvise',jour);
    END IF;
   ELSIF ch ? 'manqueMateriauxAvise' THEN
    ch:=ch-'manqueMateriauxAvise';
   END IF;
   SELECT valeur INTO taux FROM public.entreprises_constantes WHERE cle='chantier_taux_horaire';$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch alerte materiaux non applique'; END IF;
  EXECUTE v_new;
END $mig$;
