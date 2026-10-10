-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010010806 (UTC), nom `cotisation_le_club_se_resout_sur_le_miroir_genere`.
-- Le registre passe de 591 a 592 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 54a135b9edaf7c32d7a64c144d868e4e, 3318 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- COTISATION : LE CLUB SE RESOUT SUR LE MIROIR GENERE
--
-- La porte resolvait le club d'une ville sur `clubs_sportifs_regles`. FAIT MESURE : cette table est
un DOUBLON declare (baseline/CLASSIFICATION.md) qu'aucun generateur ne recalcule. Le miroir SQL
de CLUBS_SPORTIFS (data.js) est `clubs_football`, produit par un generateur et surveille par une
empreinte. Les 12 lignes coincident aujourd'hui (12/12 verifiees) ; s'appuyer sur le doublon
ferait divergere la taxe du jeu le jour ou un club bouge. Patch en place, trois fragments.
--
-- ELLE VA PAR PAIRE AVEC : `api/cron-minuit.js` (le commentaire de CLUBS_SPORTIFS_SERVEUR, qui disait encore
-- servir a retrouver la caisse d'un club).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA PORTE LISAIT LE DOUBLON, PAS LE MIROIR. cotisation_renouveler resolvait le club d'une ville
-- sur `clubs_sportifs_regles`. Fait mesure : cette table est un DOUBLON declare (voir
-- baseline/CLASSIFICATION.md, « Duplication constatee ») -- malgre son nom elle ne contient aucune
-- regle, et AUCUN generateur ne la recalcule. Le miroir SQL de CLUBS_SPORTIFS (data.js) est
-- `clubs_football`, produit par outils/generateurs/generer_clubs_football.py et surveille par une
-- empreinte. Les 12 lignes coincident aujourd'hui (12/12 verifiees : meme club_id, meme pays, meme
-- ville) -- mais s'appuyer sur le doublon ferait divergere la taxe du jeu le jour ou un club bouge
-- dans data.js. La porte lit desormais le miroir genere.
--
-- Mesure faite aussi : `clubs_football` a UN SEUL club par (pays, ville) -- 0 ville a deux clubs --
-- donc la resolution reste univoque, exactement comme le `.find()` cote JS qu'elle remplace.
--
-- PATCH EN PLACE, en trois fragments independants : le corps n'est jamais retape, et chaque
-- fragment absent ferait echouer la migration bruyamment.
DO $$
DECLARE v_def text; v_new text;
BEGIN
  SELECT pg_get_functiondef('public.cotisation_renouveler(text,text,integer)'::regprocedure)
    INTO v_def;
  v_new := replace(v_def, 'public.clubs_sportifs_regles c', 'public.clubs_football c');
  IF v_new = v_def THEN RAISE EXCEPTION 'fragment 1 (la table) introuvable'; END IF;
  v_def := v_new;
  v_new := replace(v_def, 'c.club_id INTO v_club', 'c.id INTO v_club');
  IF v_new = v_def THEN RAISE EXCEPTION 'fragment 2 (la colonne rendue) introuvable'; END IF;
  v_def := v_new;
  v_new := replace(v_def, 'c.country = v_pays AND c.city = v_ville',
                          'c.pays = v_pays AND c.ville = v_ville');
  IF v_new = v_def THEN RAISE EXCEPTION 'fragment 3 (le filtre) introuvable'; END IF;
  EXECUTE v_new;
END $$;

DO $$
DECLARE v_def text;
BEGIN
  SELECT pg_get_functiondef('public.cotisation_renouveler(text,text,integer)'::regprocedure)
    INTO v_def;
  IF v_def LIKE '%clubs_sportifs_regles%' THEN
    RAISE EXCEPTION 'P1 : le doublon est encore lu'; END IF;
  IF v_def NOT LIKE '%FROM public.clubs_football c%WHERE c.pays = v_pays AND c.ville = v_ville%' THEN
    RAISE EXCEPTION 'P2 : la resolution sur le miroir genere est absente'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='clubs_football'
                    AND column_name IN ('id','pays','ville')
                 GROUP BY table_name HAVING count(*) = 3) THEN
    RAISE EXCEPTION 'P3 : clubs_football ne resout plus (pays, ville) -> id'; END IF;
  IF EXISTS (SELECT 1 FROM (SELECT pays, ville FROM public.clubs_football
                             GROUP BY pays, ville HAVING count(*) > 1) z) THEN
    RAISE EXCEPTION 'P4 : une ville porte deux clubs, la resolution n''est plus univoque'; END IF;
  IF coalesce(array_to_string((SELECT proacl::text[] FROM pg_proc p JOIN pg_namespace n
       ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='cotisation_renouveler'),
       ' | '), '(defaut)') <> 'postgres=X/postgres | service_role=X/postgres' THEN
    RAISE EXCEPTION 'P5 : le patch a rouvert les droits'; END IF;
  RAISE NOTICE 'resolution du club sur le miroir genere : 5 preuves conformes.';
END $$;