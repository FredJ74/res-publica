-- NON APPLIQUÉE — Fred, mission images du 22/11/2026.
-- Claude seul intervient en production. Préparation pour la réconciliation ultérieure.
-- Images uniquement : aucun coût, droit, ordre, inventaire quantitatif, seed ni fonction métier.
-- Remplace des chaînes JSON ENTIÈRES, jamais le contenu narratif d’une chaîne.
-- Idempotente : aucune ancienne valeur => aucune écriture. Une transaction à l’application future.
DO $images$
DECLARE r record; v_anciennes text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('escorts_catalogue','portrait','text','images/escort-h-1-costume-beige.png','images/escort-h-1-costume-beige.webp'),
    ('escorts_catalogue','portrait','text','images/escort-republic.png','images/escort-republic.webp'),
    ('escorts_catalogue','portrait','text','images/escort-f-1-robe-verte.png','images/escort-f-1-robe-verte.webp'),
    ('inventaire_actions_recus','resultat','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-fusil-republic.png','images/arme-fusil-republic.webp'),
    ('journal_editions','faits_sources','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-brise-mariannaise.png','images/stade-brise-mariannaise.webp'),
    ('journal_editions','faits_sources','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/stade-olympique-luthecia.png','images/stade-olympique-luthecia.webp'),
    ('journal_editions','faits_sources','jsonb','images/stade-brise-mariannaise.png','images/stade-brise-mariannaise.webp'),
    ('journal_editions','faits_sources','jsonb','images/stade-olympique-luthecia.png','images/stade-olympique-luthecia.webp'),
    ('objets_modeles','objet','jsonb','images/arme-baionnette-soviet.png','images/arme-baionnette-soviet.webp'),
    ('objets_modeles','objet','jsonb','images/arme-makarov-soviet.png','images/arme-makarov-soviet.webp'),
    ('objets_modeles','objet','jsonb','images/arme-kalachnikov-soviet.png','images/arme-kalachnikov-soviet.webp'),
    ('personnages_donnees','inventory','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/calepin-enigme-musee.png','images/calepin-enigme-musee.webp'),
    ('personnages_donnees','inventory','jsonb','images/calepin-enigme-musee.png','images/calepin-enigme-musee.webp'),
    ('personnages_donnees','inventory','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-fusil-republic.png','images/arme-fusil-republic.webp'),
    ('pnj_possessions','objet','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-mitraillette-militaire.png','images/arme-mitraillette-militaire.webp'),
    ('pnj_possessions','objet','jsonb','https://raw.githubusercontent.com/FredJ74/res-publica/main/images/arme-pistolet-militaire.png','images/arme-pistolet-militaire.webp')
  ) AS corrections(table_name,column_name,column_type,ancienne,nouvelle)
  LOOP
    IF r.column_type = 'text' THEN
      EXECUTE format('UPDATE public.%I SET %I = $2 WHERE %I = $1',
        r.table_name,r.column_name,r.column_name) USING r.ancienne,r.nouvelle;
    ELSE
      EXECUTE format('UPDATE public.%I SET %I = replace(%I::text,to_jsonb($1::text)::text,to_jsonb($2::text)::text)::jsonb WHERE strpos(%I::text,to_jsonb($1::text)::text) > 0',
        r.table_name,r.column_name,r.column_name,r.column_name) USING r.ancienne,r.nouvelle;
    END IF;
  END LOOP;
END
$images$;
