-- MATERIELS PAR COMBINAISON : TELEPHONE CELLULAIRE (decision de Fred du 31/10/2026, GAME-DESIGN-EQUIPEMENTS.md) :
-- le telephone cellulaire est l'equivalent civil de la radio militaire, exactement le meme fonctionnement : rappel d'un
-- groupe de PNJ employes, ou d'un groupe dirige par un PNJ employe (pnj_rappeler_radio), meme ville uniquement.
-- Patch ancre de pnj_rappeler_radio : l'appelant doit porter une radio OU un telephone (generique
-- `telephone-portable-cellulaire`, vendu par la boutique d'electronique) ; au moins un membre de l'unite aussi.
-- Le telephone se donne a un employe par le transfert d'objet existant (pnj_objet_transferer).
-- Aucune donnee de joueur touchee. Rejouable.
BEGIN;
DO $tel$
DECLARE d text; a1 text; b1 text; a2 text; b2 text;
BEGIN
  d := pg_get_functiondef('public.pnj_rappeler_radio(text)'::regprocedure);
  IF position('telephone_cellulaire_v1' IN d) > 0 THEN RETURN; END IF;
  a1 := $a$    WHERE (o->>'produitMilitaire'='radio' OR o->>'id'='radio')$a$;
  b1 := $b$    WHERE (o->>'produitMilitaire'='radio' OR o->>'id'='radio'
           OR o->>'generique_id'='telephone-portable-cellulaire') -- telephone_cellulaire_v1 (Fred, 31/10/2026)$b$;
  a2 := $a$   AND (p.objet->>'produitMilitaire'='radio' OR p.objet->>'id'='radio')$a$;
  b2 := $b$   AND (p.objet->>'produitMilitaire'='radio' OR p.objet->>'id'='radio'
        OR p.objet->>'generique_id'='telephone-portable-cellulaire')$b$;
  IF (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1
     OR (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 THEN
    RAISE EXCEPTION 'pnj_rappeler_radio : ancrage introuvable';
  END IF;
  EXECUTE replace(replace(d, a1, b1), a2, b2);
END $tel$;
DO $$
BEGIN
  IF (SELECT count(*) FROM regexp_matches(pg_get_functiondef('public.pnj_rappeler_radio(text)'::regprocedure),
        'telephone-portable-cellulaire', 'g')) <> 2 THEN
    RAISE EXCEPTION 'telephone_cellulaire_rappel : controle structurel en echec';
  END IF;
END $$;
COMMIT;
