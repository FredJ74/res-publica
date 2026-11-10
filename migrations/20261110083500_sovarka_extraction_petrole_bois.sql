-- SOVARKA : LIEUX D'EXTRACTION (decision de Fred du 09/11/2026 au soir, reponse 5 ; GAME-DESIGN-NOVOMIRSK.md).
-- La zone de production de Starovka est la Compagnie Nationale du Petrole, celle de Krasnov l'exploitation
-- forestiere : les PJ y extraient du petrole (Starovka) et du bois (Krasnov), matieres economiques reelles
-- (cles `petrole` et `bois`), revendables aux entrepots. Les anciennes matieres sans valeur economique de ces
-- deux villes (Minerai de fer, Charbon, Ble, Cuir : objets « legacy ») ne s'y recoltent plus.
-- Patch en place de recolte_effectuer, par remplacement cible verifie ; aucun autre changement.
BEGIN;
DO $raccord$
DECLARE d text; avant text; apres text;
BEGIN
  d := pg_get_functiondef('public.recolte_effectuer(text,integer,integer)'::regprocedure);
  IF position('sovarka_extraction_v1' IN d) = 0 THEN
    avant := E'WHEN ''soviet:ville_a'' THEN ARRAY[''Minerai de fer'', ''Charbon''] WHEN ''soviet:ville_b'' THEN ARRAY[''Blé'', ''Cuir'']';
    apres := E'WHEN ''soviet:ville_a'' THEN ARRAY[''Pétrole''] WHEN ''soviet:ville_b'' THEN ARRAY[''Bois''] /* sovarka_extraction_v1 */';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'recolte_effectuer : ancrage villes introuvable'; END IF;
    d := replace(d, avant, apres);
    avant := E'WHEN ''Bois'' THEN ''bois'' END;';
    apres := E'WHEN ''Bois'' THEN ''bois'' WHEN ''Pétrole'' THEN ''petrole'' END;';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'recolte_effectuer : ancrage cle introuvable'; END IF;
    d := replace(d, avant, apres);
    avant := E'WHEN ''charbon'' THEN ''ti-flame'' ELSE ''ti-trees'' END';
    apres := E'WHEN ''charbon'' THEN ''ti-flame'' WHEN ''petrole'' THEN ''ti-droplet'' ELSE ''ti-trees'' END';
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'recolte_effectuer : ancrage icone introuvable'; END IF;
    EXECUTE replace(d, avant, apres);
  END IF;
  d := pg_get_functiondef('public.recolte_effectuer(text,integer,integer)'::regprocedure);
  IF position('ARRAY[''Pétrole''] WHEN ''soviet:ville_b'' THEN ARRAY[''Bois'']' IN d) = 0
     OR position('WHEN ''Pétrole'' THEN ''petrole''' IN d) = 0 THEN
    RAISE EXCEPTION 'recolte_effectuer : patch absent apres application';
  END IF;
END $raccord$;
COMMIT;
