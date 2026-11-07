-- Partis de Sovarka : un parti démarre à 0 POP, à lui de faire monter sa popularité
-- (décision de Fred, 07/11/2026 ; remplace la valeur provisoire 50 de 20261107184000).
-- Aucune ligne existante à régulariser (aucun parti de Sovarka en production au 07/11, 23 h 35).
-- Patch en place, sous empreinte : refus si le nombre de fragments attendus n'est pas exact.
DO $m$
DECLARE d text; ancien text; nouveau text; n int;
BEGIN
  -- 1. Lecture (liste et « Mon parti ») : défaut 50 -> 0, deux occurrences.
  d := pg_get_functiondef('public.sovarka_partis_liste()'::regprocedure);
  IF position('->>''pop'')::numeric, 50)' in d) = 0 AND position('->>''pop'')::numeric, 0)' in d) > 0 THEN
    RAISE NOTICE 'liste déjà appliquée';
  ELSE
    n := (length(d) - length(replace(d, '->>''pop'')::numeric, 50)', ''))) / length('->>''pop'')::numeric, 50)');
    IF n <> 2 THEN RAISE EXCEPTION 'empreinte_inattendue_sovarka_partis_liste (%)', n; END IF;
    EXECUTE replace(d, '->>''pop'')::numeric, 50)', '->>''pop'')::numeric, 0)');
  END IF;

  -- 2. Commandes : fondation à 0 et défaut du refus à 0.
  d := pg_get_functiondef('public.sovarka_parti_commande(uuid,text,text,jsonb)'::regprocedure);
  ancien := '''prixAdhesion'', 0, ''pop'', 50,';
  nouveau := '''prixAdhesion'', 0, ''pop'', 0,';
  IF position(nouveau in d) > 0 THEN
    RAISE NOTICE 'commande déjà appliquée';
  ELSE
    IF (length(d) - length(replace(d, ancien, ''))) / length(ancien) <> 1
       OR (length(d) - length(replace(d, '(d->>''pop'')::numeric, 50)', ''))) / length('(d->>''pop'')::numeric, 50)') <> 1 THEN
      RAISE EXCEPTION 'empreinte_inattendue_sovarka_parti_commande';
    END IF;
    EXECUTE replace(replace(d, ancien, nouveau), '(d->>''pop'')::numeric, 50)', '(d->>''pop'')::numeric, 0)');
  END IF;
END $m$;
