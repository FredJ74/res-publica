-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009073456 (UTC ; 09h34 a Paris), nom
-- `restitution_arg_arnie_effet_de_bord_des_preuves`. Le registre passe de 564 a 565 entrees.
--
-- LE CORPS CI-DESSOUS EST LE TEXTE EXACT ENREGISTRE : md5
-- c4e8682ca1952b9017f9071253ccbef5, 5 652 caracteres, 1 instruction au registre. Relu depuis
-- `supabase_migrations.schema_migrations`, empreinte verifiee avant archivage.
--
-- PREMIERE MIGRATION DE CE PROJET QUI MODIFIE UNE DONNEE DE JOUEUR, et elle repare un ecart
-- que l'agent a cause. Elle est passee par le canal normal -- apply_migration -- precisement
-- pour que le registre en garde la trace : une correction de donnees hors registre serait
-- exactement le trou que le chantier de reproductibilite a reboucho.
--
-- ETAT CONSTATE APRES APPLICATION, RELU EN BASE :
--   Arnie      arg 8428 -> 9428, liquide 500 inchange, updated_at 2026-10-08 22:12:13.211
--              -> 2026-10-09 07:34:56.420332 ;
--   les sept autres personnages : identiques au caractere pres (empreinte comparee dans la
--              transaction, preuve 6) ;
--   somme des arg : 22 003 -> 23 003.
-- =============================================================================

-- RESTITUTION DE DONNEES -- 1 000 FR rendus au personnage « Arnie ».
--
-- POURQUOI CETTE MIGRATION EXISTE. La migration 20261008235521 (idempotence_prets_helvetia) a
-- prouve son effet en appelant `traiter_prets_helvetia_quotidien` POUR DE VRAI sur un pret
-- temoin, deux prelevements de 500 FR. Cette RPC ne touche pas que le pret : elle credite la
-- caisse de la banque privee ET DEBITE `arg` de l'emprunteur. Le temoin etait le premier
-- personnage par ordre alphabetique, « Arnie » -- un joueur reel. Les 1 000 FR deposes dans
-- `republic_banque-privee` avaient ete restitues dans la minute ; ce second effet de bord, lui,
-- n'a ete vu qu'ensuite, en relisant TOUTES les ecritures de la branche executee.
--
-- LE MONTANT N'EST PAS DEDUIT, IL EST MESURE. Rejeu du scenario exact en transaction annulee :
-- `arg` 8428 -> 7428 pour une caisse a +1 000. Le debit de `arg` et le credit de la caisse
-- viennent de la MEME variable (`v_a_prelever`) dans la MEME branche, executee le meme nombre
-- de fois : le +1 000 constate sur la caisse prouve le -1 000 sur `arg`.
--
-- SEUL `arg` EST RESTITUE. La branche executee (ligne 91 du corps de la RPC) ne touche que
-- `arg` : `liquide` n'a pas bouge et ne doit pas bouger. La preuve 4 le verifie.
--
-- `updated_at` EST RELEVE, ET CE N'EST PAS UNE COQUETTERIE. `sbVerifierEtSauvegarderPersonnage`
-- (supabase.js) compare l'`updated_at` serveur au dernier qu'elle a ecrit : si les deux sont
-- EGAUX, elle considere que personne n'a ecrit depuis et republie sa copie en memoire. Une
-- session qui tient encore Arnie a 8428 ecraserait donc cette restitution en silence. Son
-- commentaire nomme exactement ce cas : « une correction serveur directe a ecrit entretemps ».
-- Le fuseau suit la convention de la colonne (timestamp sans fuseau, en UTC, comme
-- `new Date().toISOString()` cote client) : `now() AT TIME ZONE 'UTC'`, explicite.
--
-- FAIL-CLOSED. Les preconditions sont verifiees AVANT l'ecriture et levent : un seul Arnie,
-- `arg` exactement a 8428, somme des `arg` a 22 003. Si l'une est fausse -- un joueur a joue,
-- un cron est passe -- RIEN n'est modifie et l'etat observe est dit dans le message.
DO $$
DECLARE
  v_n            integer;
  v_arg          numeric;
  v_liquide      numeric;
  v_maj_avant    timestamp;
  v_maj_apres    timestamp;
  v_somme_avant  numeric;
  v_somme_apres  numeric;
  v_autres_avant text;
  v_autres_apres text;
  v_touchees     integer;
BEGIN
  -- ---------------------------------------------------------------- preconditions
  SELECT count(*) INTO v_n FROM public.personnages_donnees WHERE name = 'Arnie';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'ARRET : % ligne(s) nommee(s) Arnie au lieu d''une seule. Rien n''est modifie.', v_n;
  END IF;

  SELECT arg, liquide, updated_at INTO v_arg, v_liquide, v_maj_avant
    FROM public.personnages_donnees WHERE name = 'Arnie';
  IF v_arg IS DISTINCT FROM 8428 THEN
    RAISE EXCEPTION 'ARRET : arg vaut % et non 8428 -- l''etat a bouge depuis la mesure. Rien n''est modifie, l''ecart reste a rejuger.', v_arg;
  END IF;

  SELECT sum(arg) INTO v_somme_avant FROM public.personnages_donnees;
  IF v_somme_avant IS DISTINCT FROM 22003 THEN
    RAISE EXCEPTION 'ARRET : la somme des arg vaut % et non 22003 -- un autre solde a bouge. Rien n''est modifie.', v_somme_avant;
  END IF;

  -- Empreinte des SEPT AUTRES personnages, pour prouver qu'aucun d'eux n'est touche.
  SELECT md5(string_agg(name || ':' || coalesce(arg::text,'~') || ':' || coalesce(liquide::text,'~'),
                        '|' ORDER BY name COLLATE "C"))
    INTO v_autres_avant
    FROM public.personnages_donnees WHERE name <> 'Arnie';

  -- ---------------------------------------------------------------- restitution
  UPDATE public.personnages_donnees
     SET arg = 9428,
         updated_at = (now() AT TIME ZONE 'UTC')
   WHERE name = 'Arnie' AND arg = 8428;
  GET DIAGNOSTICS v_touchees = ROW_COUNT;

  -- ---------------------------------------------------------------- preuves
  IF v_touchees <> 1 THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- % ligne(s) touchee(s) au lieu d''une', v_touchees;
  END IF;

  SELECT arg, liquide, updated_at INTO v_arg, v_liquide, v_maj_apres
    FROM public.personnages_donnees WHERE name = 'Arnie';
  IF v_arg IS DISTINCT FROM 9428 THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- arg vaut % au lieu de 9428', v_arg;
  END IF;

  IF v_liquide IS DISTINCT FROM 500 THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- liquide vaut % au lieu de 500 : la restitution ne doit toucher que arg', v_liquide;
  END IF;

  IF v_maj_apres IS NULL OR v_maj_apres <= v_maj_avant THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- updated_at n''a pas ete releve (% -> %) : une session vivante ecraserait la restitution', v_maj_avant, v_maj_apres;
  END IF;

  SELECT sum(arg) INTO v_somme_apres FROM public.personnages_donnees;
  IF v_somme_apres IS DISTINCT FROM 23003 THEN
    RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- la somme des arg vaut % au lieu de 23003', v_somme_apres;
  END IF;

  SELECT md5(string_agg(name || ':' || coalesce(arg::text,'~') || ':' || coalesce(liquide::text,'~'),
                        '|' ORDER BY name COLLATE "C"))
    INTO v_autres_apres
    FROM public.personnages_donnees WHERE name <> 'Arnie';
  IF v_autres_apres IS DISTINCT FROM v_autres_avant THEN
    RAISE EXCEPTION 'PREUVE 6 ECHOUEE -- un autre personnage a change (% -> %)', v_autres_avant, v_autres_apres;
  END IF;

  RAISE NOTICE 'SIX PREUVES VERTES. Arnie : arg 8428 -> 9428, liquide 500 inchange, updated_at % -> %, somme 22003 -> 23003, sept autres personnages intacts.',
               v_maj_avant, v_maj_apres;
END $$;