-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029210313.
-- Archivage documentaire seulement ; ne pas rejouer.
-- A APPLIQUER JUSTE APRES LA LIVRAISON DE LA PR #213, avec 20261028210000 et 20261028210500.
-- Le vol de materiaux passe desormais entier par crime_voler_materiaux (jet, stock, depot, trace).
-- L'ancien acte « chantier_materiaux_voler » de terrain_chantier_acte retirait du stock la quantite
-- demandee par l'ecran, sans jet ni PA : il est ferme. Seul cet acte change ; la porte et ses
-- autres actes (chantier de Codex) sont intacts.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.terrain_chantier_acte(text,text,text,integer,integer)'::regprocedure);
  IF position('vol_par_le_serveur' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'  -- VOL DE MATERIAUX\n',
      E'  -- VOL DE MATERIAUX : par crime_voler_materiaux depuis le 28/10/2026 (chantier inventaire).\n'
      || E'  IF p_acte = ''chantier_materiaux_voler'' THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''vol_par_le_serveur''); END IF;\n');
    IF position('vol_par_le_serveur' IN v_def) = 0 THEN RAISE EXCEPTION 'terrain_chantier_acte : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
