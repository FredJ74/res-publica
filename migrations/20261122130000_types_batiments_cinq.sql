-- Refonte des types de bâtiments, 7 → 5 (Fred, 22/11/2026, nuit, point 6). Exception accordée : les fonctions communes
-- nécessaires sont modifiées entièrement (Codex ne touche pas à la base).
-- • Hangar 30 000 / 6 j / 300 h, sans subdivision. • Commerce standard 60 000 / 12 j / 600 h, sans subdivision.
-- • Commerce premium 90 000 / 18 j / 900 h ; boutiques de 600 m² minimum.
-- • Logement 90 000 / 18 j / 900 h ; 6 appartements (3 petits de 45 m², 3 grands de 75 m²).
-- • Building (mixte) 120 000 / 24 j / 1 200 h ; commerces ≥ 300 m², appartements ≥ 150 m², au plus 6 commerces et
--   14 appartements, somme des lots ≤ surface du terrain. Remplace la barre.
-- • Supprimés : logements sociaux petit et barre ; l'ancien « moyen » devient le type Logement unique.
-- • Catégorie selon le donneur d'ordre (Logement et Building) : mairie = logements sociaux (attribués par le maire, loyer
--   bas fixé par le jeu, bonus de moral et de santé au sommeil) ; joueur = logements classiques (loyer et attribution libres).
-- • Le chantier d'Arnie (building, terrain 3 de Luthécia) n'est pas modifié. Vérifié le 22/11 : aucun terrain, permis ni
--   dossier n'utilise les anciens types de logements.
-- Aucun objet du goulag touché.
BEGIN;

-- 1. Paliers : Logement remplace les trois paliers de logements sociaux.
INSERT INTO public.chantiers_paliers (palier, label, duree_jours, cout_total, cout_materiaux, cout_travail, heures_totales, apport_minimal, gabarit)
SELECT 'logement', 'Logement', 18, 90000, 27000, 63000, 900, 31500, gabarit || '{"niveau":"logement"}'::jsonb
  FROM public.chantiers_paliers WHERE palier = 'commerce_premium'
ON CONFLICT (palier) DO NOTHING;
DELETE FROM public.chantiers_paliers WHERE palier IN ('logements_petit', 'logements_moyen', 'logements_barre')
  AND NOT EXISTS (SELECT 1 FROM public.terrains_etat t WHERE t.data::jsonb->'permis'->>'palierDemande' LIKE 'logements_%'
                     OR t.data::jsonb->'chantier'->>'niveau' LIKE 'logements_%' OR t.niveau_construction LIKE 'logements_%');

-- 2. Logements sociaux (mairie) : 6 appartements pour Logement ; les anciens noms restent lus (filet de sécurité).
CREATE OR REPLACE FUNCTION public.logements_sociaux_lots_interne(p_niveau text)
 RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE n int := CASE p_niveau WHEN 'logement' THEN 6 WHEN 'logements_moyen' THEN 6 WHEN 'logements_petit' THEN 4 WHEN 'logements_barre' THEN 10 END;
  sortie jsonb := '[]'; i int;
BEGIN
  IF n IS NULL THEN RAISE EXCEPTION 'palier_invalide'; END IF;
  FOR i IN 1..n/2 LOOP
    sortie := sortie || jsonb_build_array(jsonb_build_object('id','logement-petit-'||i,'label','Petit appartement n°'||i,'surface',45,
      'destination','logement_social','typeLogement','petit','locataire',NULL,'loyer',30,'logementSocial',true,'bonusMoralSommeil',3,'bonusSanteSommeil',4));
  END LOOP;
  FOR i IN 1..n/2 LOOP
    sortie := sortie || jsonb_build_array(jsonb_build_object('id','logement-grand-'||i,'label','Grand appartement n°'||i,'surface',75,
      'destination','logement_social','typeLogement','grand','locataire',NULL,'loyer',60,'logementSocial',true,'bonusMoralSommeil',5,'bonusSanteSommeil',7));
  END LOOP;
  RETURN sortie;
END $function$;

-- 3. Logements classiques (joueur) : les mêmes 6 appartements, loyer et attribution libres.
CREATE OR REPLACE FUNCTION public.logements_classiques_lots_interne()
 RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE sortie jsonb := '[]'; i int;
BEGIN
  FOR i IN 1..3 LOOP
    sortie := sortie || jsonb_build_array(jsonb_build_object('id','logement-petit-'||i,'label','Petit appartement n°'||i,'surface',45,
      'destination','appartement','typeLogement','petit','locataire',NULL,'loyer',0));
  END LOOP;
  FOR i IN 1..3 LOOP
    sortie := sortie || jsonb_build_array(jsonb_build_object('id','logement-grand-'||i,'label','Grand appartement n°'||i,'surface',75,
      'destination','appartement','typeLogement','grand','locataire',NULL,'loyer',0));
  END LOOP;
  RETURN sortie;
END $function$;

-- 4. Découpage des lots (fonction commune, réécrite) : Logement fixe ; Building plafonné ; catégorie selon le donneur d'ordre.
CREATE OR REPLACE FUNCTION public.chantier_plan_normaliser_interne(p_etat jsonb, p_niveau text, p_plan jsonb)
 RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE lot jsonb;sortie jsonb:='[]';vus text[]:=ARRAY[]::text[];idlot text;dest text;s numeric;total numeric:=0;minimum numeric;
        nc integer:=0; na integer:=0; communal boolean := public.logements_sociaux_terrain_communal(p_etat); /* types_batiments_cinq_v1 */
BEGIN
 IF p_niveau IN('logement','logements_petit','logements_moyen','logements_barre') THEN
  RETURN CASE WHEN communal THEN public.logements_sociaux_lots_interne(p_niveau) ELSE public.logements_classiques_lots_interne() END;
 END IF;
 IF jsonb_typeof(p_plan) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'plan_invalide';END IF;
 FOR lot IN SELECT value FROM jsonb_array_elements(p_plan) LOOP
  idlot:=nullif(btrim(lot->>'id'),'');dest:=coalesce(lot->>'destination','commerce');s:=(lot->>'surface')::numeric;
  IF dest IN ('logement_social','logement') THEN dest:='appartement'; END IF;
  minimum:=CASE WHEN p_niveau='commerce_premium' AND dest='commerce' THEN 600 WHEN p_niveau='building' AND dest='commerce' THEN 300 WHEN p_niveau='building' AND dest='appartement' THEN 150 END;
  total:=total+s;
  IF dest='commerce' THEN nc:=nc+1; ELSE na:=na+1; END IF;
  IF idlot IS NULL OR idlot=ANY(vus) OR minimum IS NULL OR s IS NULL OR s<minimum OR nullif(p_etat->>'surface','') IS NULL OR total>(p_etat->>'surface')::numeric
     OR (p_niveau='building' AND (nc>6 OR na>14)) THEN RAISE EXCEPTION 'plan_invalide';END IF;
  vus:=array_append(vus,idlot);
  IF dest='appartement' AND communal THEN
   sortie:=sortie||jsonb_build_array(jsonb_build_object('id',idlot,'label',coalesce(nullif(btrim(lot->>'label'),''),'Appartement'),'surface',s,
     'destination','logement_social','typeLogement','grand','locataire',NULL,'loyer',60,'logementSocial',true,'bonusMoralSommeil',5,'bonusSanteSommeil',7));
  ELSE
   sortie:=sortie||jsonb_build_array(jsonb_build_object('id',idlot,'label',coalesce(nullif(btrim(lot->>'label'),''),'Lot'),'surface',s,'destination',dest,'locataire',NULL,'loyer',0));
  END IF;
 END LOOP;
 RETURN sortie;
END $function$;

-- Remplacement textuel contrôlé dans une fonction commune : nombre d'occurrences attendu, marque d'idempotence.
CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- 5. Dépôt du permis : Logement ouvert aux joueurs (logements classiques) comme à la mairie (logements sociaux).
SELECT pg_temp.rp_remplacer('public.terrain_permis_deposer(text,text,uuid)'::regprocedure,
  $a$WHEN 'building' THEN 7 WHEN 'logements_petit' THEN 4 WHEN 'logements_moyen' THEN 6 WHEN 'logements_barre' THEN 7 END;$a$,
  $b$WHEN 'building' THEN 7 WHEN 'logement' THEN 6 END; /* types_batiments_cinq_v1 */$b$, 1, 'types_batiments_cinq_v1');
SELECT pg_temp.rp_remplacer('public.terrain_permis_deposer(text,text,uuid)'::regprocedure,
  $a$ IF p_palier LIKE 'logements_%' THEN
  IF NOT public.logements_sociaux_terrain_communal(etat) THEN RETURN jsonb_build_object('ok',false,'raison','logements_reserves_commune');END IF;
  IF (p_palier='logements_moyen' AND coalesce((etat->>'surface')::numeric,0)<2000) OR (p_palier='logements_barre' AND coalesce((etat->>'surface')::numeric,0)<=2200) THEN RETURN jsonb_build_object('ok',false,'raison','terrain_trop_petit');END IF;
 END IF;$a$,
  $b$ IF p_palier='logement' AND coalesce((etat->>'surface')::numeric,0)<2000 THEN RETURN jsonb_build_object('ok',false,'raison','terrain_trop_petit');END IF; /* types_batiments_cinq_depot_v1 */$b$,
  1, 'types_batiments_cinq_depot_v1');
SELECT pg_temp.rp_remplacer('public.terrain_permis_deposer(text,text,uuid)'::regprocedure,
  $a$WHEN 'commerce_premium' THEN 'Commerce premium' WHEN 'logements_petit' THEN 'Logements sociaux — petit bâtiment' WHEN 'logements_moyen' THEN 'Logements sociaux — bâtiment moyen' WHEN 'logements_barre' THEN 'Logements sociaux — barre d''immeuble' ELSE 'Building' END,$a$,
  $b$WHEN 'commerce_premium' THEN 'Commerce premium' WHEN 'logement' THEN 'Logement' ELSE 'Building' END /* types_batiments_cinq_libelle_v1 */,$b$,
  1, 'types_batiments_cinq_libelle_v1');

-- 6. Décision du permis : libellé.
SELECT pg_temp.rp_remplacer('public.terrain_permis_decider(text,boolean,text,uuid)'::regprocedure,
  $a$WHEN 'building' THEN 'Building' WHEN 'logements_petit' THEN 'Logements sociaux — petit bâtiment' WHEN 'logements_moyen' THEN 'Logements sociaux — bâtiment moyen' WHEN 'logements_barre' THEN 'Logements sociaux — barre d''immeuble' ELSE$a$,
  $b$WHEN 'building' THEN 'Building' WHEN 'logement' THEN 'Logement' /* types_batiments_cinq_v1 */ ELSE$b$, 1, 'types_batiments_cinq_v1');

-- 7. Acquisition de terrain avec permis : liste des paliers.
SELECT pg_temp.rp_remplacer('public.terrain_acquisition_commande(text,text,jsonb,uuid)'::regprocedure,
  $a$permis NOT IN('hangar','commerce_standard','commerce_premium','building','logements_petit','logements_moyen','logements_barre')$a$,
  $b$permis NOT IN('hangar','commerce_standard','commerce_premium','logement','building') /* types_batiments_cinq_v1 */$b$, 1, 'types_batiments_cinq_v1');

-- 8. Prêts d'Helvetia : la valeur des biens compte désormais les logements (comme un commerce premium, même coût).
SELECT pg_temp.rp_remplacer('public.traiter_prets_helvetia_quotidien()'::regprocedure,
  $a$WHEN 'commerce_premium' THEN 70000 WHEN 'building' THEN 100000$a$,
  $b$WHEN 'commerce_premium' THEN 70000 WHEN 'logement' THEN 70000 /* types_batiments_cinq_v1 */ WHEN 'building' THEN 100000$b$, 4, 'types_batiments_cinq_v1');

REVOKE ALL ON FUNCTION public.logements_classiques_lots_interne() FROM PUBLIC, anon, authenticated;
COMMIT;
