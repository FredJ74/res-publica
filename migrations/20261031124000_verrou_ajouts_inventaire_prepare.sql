-- PRÉPARATION UNIQUEMENT : NE PAS APPLIQUER EN PRODUCTION sans recette d'intégration.
-- Bloquer les ajouts non reconnus à l'intérieur de la sauvegarde versionnée, sans toucher
-- à la décrémentation / suppression d'objets existants ni aux dépôts serveur.
-- Prévol exact sur la fonction de production observée le 31/10/2026.
DO $verrou$
DECLARE
  definition text;
  source text := $ancien$    -- VERROU, ETAPE 1 (observation) : un objet qui n'etait pas deja possede est inscrit.
    INSERT INTO public.inventaire_ecarts_observes (acteur, objet)
    SELECT p_acteur, x FROM jsonb_array_elements(public.inventaire_ajouts_interdits(v.inventory, p_inventory)) x;
    UPDATE public.personnages_donnees SET inventory=p_inventory WHERE name=p_acteur$ancien$;
  cible text := $nouveau$    -- VERROU, ETAPE 2 : le navigateur ne peut pas fabriquer de nouveaux objets.
    -- Les producteurs autorisés utilisent inventaire_deposer_interne et les RPC métier.
    -- Refus AVANT toute écriture, sans modification ni incrément de révision.
    IF jsonb_array_length(public.inventaire_ajouts_interdits(v.inventory, p_inventory)) > 0 THEN
      RETURN jsonb_build_object('ok',false,'raison','ajout_inventaire_interdit',
                                'revision',v.inventory_revision);
    END IF;
    UPDATE public.personnages_donnees SET inventory=p_inventory WHERE name=p_acteur$nouveau$;
BEGIN
  definition := pg_get_functiondef('public.inventaire_sauver_revision(text,bigint,jsonb)'::regprocedure);
  IF md5(definition) <> '57e01e4f842ef10ea8dd01dc99b3de9a' THEN
    RAISE EXCEPTION 'empreinte_inventaire_sauver_revision_inattendue: %',md5(definition);
  END IF;
  IF (length(definition)-length(replace(definition,source,'')))/length(source) <> 1 THEN
    RAISE EXCEPTION 'ancrage_verrou_inventaire_absent_ou_multiple';
  END IF;
  EXECUTE replace(definition,source,cible);
END $verrou$;
