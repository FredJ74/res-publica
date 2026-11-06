-- Prêts Helvetia : colonne pret_id ambiguë (06/11/2026, Claude).
--
-- Depuis la passe du 01/11, traiter_prets_helvetia_quotidien() échoue chaque nuit avec
-- « column reference "pret_id" is ambiguous » (cron_journal : _passe en échec,
-- sbRpc:traiter_prets_helvetia_quotidien). La fonction renvoie TABLE(pret_id, action) :
-- la variable de sortie pret_id masque la colonne biens_saisis_helvetia.pret_id dans les
-- deux sous-requêtes qui excluent les biens déjà saisis. Résultat : aucun prélèvement,
-- aucun contentieux ni aucune saisie Helvetia n'a été traité depuis le 01/11 (la transaction
-- entière est annulée).
--
-- Correctif minimal : qualifier la colonne par un alias de table dans ces deux sous-requêtes.
-- Le reste de la fonction est repris tel quel depuis la définition en production (patch en
-- place, même méthode que 20261031235500). Le marqueur jour_dernier_prelevement empêche tout
-- double prélèvement si la passe est rejouée le même jour.

DO $$
DECLARE
  v_def text;
  v_nouveau text;
  v_ancien constant text := 'SELECT terrain_id FROM public.biens_saisis_helvetia WHERE pret_id = v_pret.id';
  v_correct constant text := 'SELECT b.terrain_id FROM public.biens_saisis_helvetia b WHERE b.pret_id = v_pret.id';
BEGIN
  v_def := pg_get_functiondef('public.traiter_prets_helvetia_quotidien()'::regprocedure);
  IF position(v_ancien IN v_def) = 0 THEN
    IF position(v_correct IN v_def) > 0 THEN
      RAISE NOTICE 'traiter_prets_helvetia_quotidien déjà corrigée';
      RETURN;
    END IF;
    RAISE EXCEPTION 'Fragment attendu introuvable : définition modifiée, patch refusé';
  END IF;
  v_nouveau := replace(v_def, v_ancien, v_correct);
  IF (length(v_def) - length(replace(v_def, v_ancien, ''))) / length(v_ancien) <> 2 THEN
    RAISE EXCEPTION 'Nombre d''occurrences inattendu (2 attendues), patch refusé';
  END IF;
  EXECUTE v_nouveau;
END $$;
