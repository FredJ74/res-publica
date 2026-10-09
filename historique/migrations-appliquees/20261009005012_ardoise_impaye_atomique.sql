-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009005012 (UTC ; 02h50 a Paris), nom
-- `ardoise_impaye_atomique`. Le registre passe de 563 a 564 entrees.
--
-- LE CORPS CI-DESSOUS EST LE TEXTE EXACT ENREGISTRE : md5
-- b296aaeee10f170462f16866c7f5cd4d, 8 502 caracteres, 1 instruction au registre. Relu depuis
-- `supabase_migrations.schema_migrations` et son empreinte verifiee avant archivage.
--
-- ELLE VA PAR PAIRE AVEC UNE MODIFICATION DU DEPOT, et l'une sans l'autre serait inutile :
-- `api/cron-minuit.js`, fonction `preleverLoyersBaux`, cesse de calculer et de reecrire
-- l'ardoise. Les deux sont dans le meme commit.
--
-- -----------------------------------------------------------------------------
-- CE QU'ELLE FERME : UNE DETTE QUI DOUBLAIT A CHAQUE REJEU DU CRON
-- -----------------------------------------------------------------------------
-- `prelever_loyer_bail` a six sorties. Cinq posaient `jourPaiement`, le marqueur anti-rejeu du
-- bail. UNE ne le posait pas : celle du locataire DEJA AVERTI et toujours insolvable, qui rend
-- `expulsion_requise`.
--
-- Consequence : un second passage du cron la meme nuit -- retry apres timeout, double
-- declenchement, relance manuelle -- rendait de nouveau `expulsion_requise`, et l'appelant
-- rajoutait UN JOUR et UN LOYER a l'ardoise. La dette du locataire DOUBLAIT. Avec un loyer de
-- 400 FR, deux passes ecrivaient 800 FR dus et « 2 jours » d'impaye le premier soir.
--
-- POSER LE MARQUEUR N'AURAIT PAS SUFFI, et c'est le point interessant. L'appelant ecrivait
-- `{ ...data, impaye: majImpaye }` -- un blob reconstruit depuis une lecture faite AVANT
-- l'appel de la RPC. Il aurait donc efface, dans la foulee, le `jourPaiement` que la RPC venait
-- de poser. C'est le motif « relire puis reecrire » que ce projet connait bien : la correction
-- SQL seule aurait ete sincere et sans effet.
--
-- LA REVENDICATION ET L'EFFET DESCENDENT DONC ENSEMBLE DANS LA RPC. Une RPC est UNE SEULE
-- transaction, et `v_data` y est lu `FOR UPDATE` : le marqueur et l'ardoise sont ecrits par le
-- meme `UPDATE`, sur une ligne verrouillee. Il n'y a plus de fenetre, ni entre deux requetes
-- HTTP, ni entre deux lectures.
--
-- -----------------------------------------------------------------------------
-- LA REGLE DE JEU NE CHANGE PAS D'UN IOTA, ET C'ETAIT LA CONDITION
-- -----------------------------------------------------------------------------
-- Arbitrage du 8 septembre 2026, inchange : AUCUNE expulsion automatique. Un impaye est un
-- FAIT qu'on constate, qu'on chiffre et qu'on conserve ; il ouvre au bailleur la meme voie de
-- recuperation que n'importe quel autre motif, il ne la remplace pas. L'ardoise reste
-- `{ depuis, jours, montantDu, avisEnvoye }` sur le bail, et la date d'ouverture n'est jamais
-- reecrite. Un seul avis, a l'ouverture.
--
-- Seul le LIEU du calcul change. C'est une decision technique, pas de game design : le montant
-- ajoute est le meme (`v_prix`, le loyer du bail), l'increment est le meme (+1 jour), et le
-- courrier part dans les memes cas.
--
-- DEUX VERDICTS LA OU IL Y EN AVAIT UN. L'appelant n'a plus qu'une chose a faire -- poster
-- l'avis -- et elle depend de l'etat de l'ardoise, que lui seul ne peut plus calculer :
--   . `expulsion_requise`             : l'ardoise vient de s'ouvrir, l'avis part ;
--   . `expulsion_requise_deja_avise`  : elle courait deja, silence.
-- L'appelant comptait deja tout verdict inconnu en « ignore » : un deploiement du SQL avant le
-- JavaScript aurait donc sous-compte un impaye, jamais invente un mouvement d'argent.
--
-- -----------------------------------------------------------------------------
-- POURQUOI UNE REECRITURE PAR ANCRE
-- -----------------------------------------------------------------------------
-- La fonction fait 6 320 caracteres et porte quatre destinations de loyer, un verrou de
-- locataire et une derivation de destination attestee. La recopier pour y changer trois lignes
-- offrirait 6 300 occasions de l'alterer. Son corps est relu par `pg_get_functiondef`, modifie
-- par deux `replace()` sur des ancres exactes, et rejoue -- le procede des chantiers 4G et 6.
-- Chaque ancre introuvable LEVE. Et la migration est idempotente : si le second verdict existe
-- deja, elle ne fait rien et le dit.
--
-- -----------------------------------------------------------------------------
-- SES PREUVES SONT STRUCTURELLES. LA PREUVE 3 A REFUSE DEUX FOIS LA MIGRATION.
-- -----------------------------------------------------------------------------
-- Cinq preuves, qui lisent le catalogue : le second verdict et les deux variables existent (1),
-- l'ancienne sortie nue a disparu (1), marqueur et ardoise sont poses par la MEME ecriture (2),
-- il y a desormais SIX poses de `jourPaiement` la ou il y en avait cinq (3), l'autorite, le
-- `search_path` et les droits `postgres` + `service_role` sont intacts apres reecriture (4), et
-- le seul bail de la beta a l'empreinte qu'il avait avant (5).
--
-- DEUX REFUS AVANT L'APPLICATION, et ils valaient leur prix :
--   . la premiere version de la preuve 1 interdisait la sequence « RETURN ''expulsion_requise'';
--     END IF; » -- que le CODE NEUF contient aussi, a la fin de son nouveau bloc. Elle refusait
--     une migration correcte. Corrigee pour viser l'ANCIENNE sortie : le test d'avertissement
--     suivi IMMEDIATEMENT du RETURN, sans rien ecrire entre les deux ;
--   . la preuve 3 annoncait quatre poses de `jourPaiement` avant correctif. Il y en avait CINQ.
--     Elle a refuse la migration jusqu'a ce que le compte soit juste -- une assertion fausse est
--     une assertion qui marche.
-- Les deux refus n'ont rien laisse : registre inchange a 563, fonction inchangee, bail inchange.
--
-- L'EPREUVE COMPORTEMENTALE A EU LIEU AVANT, AU BANC, EN TRANSACTION ANNULEE, sur le bail reel
-- de la beta (loyer 400 FR, locataire mis a sec et deja averti pour la duree du banc) :
--   . premier passage : verdict `expulsion_requise`, ardoise 1 jour / 400 FR, avis marque
--     envoye, `depuis` au jour courant, `jourPaiement` pose ;
--   . DEUX rejeux le MEME jour : verdict `deja_preleve`, ardoise INCHANGEE a 1 jour / 400 FR ;
--   . le lendemain : verdict `expulsion_requise_deja_avise`, ardoise 2 jours / 800 FR, et la
--     date d'ouverture n'a pas bouge ;
--   . AUCUN ARGENT DEPLACE pendant les quatre appels ;
--   . la branche payante est intacte : locataire solvable, verdict `paye`, solde debite du loyer.
-- Verifie annule ensuite : la fonction n'avait pas change et le bail portait son empreinte
-- d'origine.
--
-- -----------------------------------------------------------------------------
-- CE QUE CE LOT NE TOUCHE PAS, ET QU'IL FAUT SAVOIR
-- -----------------------------------------------------------------------------
-- La fonction porte DEUX tests identiques et consecutifs de `v_dest IS NULL` (le second est
-- inatteignable). C'est du code mort, sans effet, laisse en place : le supprimer n'a rien a voir
-- avec l'idempotence et mettrait une seconde intention dans la meme migration.
-- =============================================================================

-- Chantier 6 -- l'ardoise d'un loyer impaye cesse de doubler a chaque rejeu du cron.
-- La branche « expulsion_requise » de prelever_loyer_bail etait LA SEULE sortie a effet a ne
-- pas poser `jourPaiement` : un second passage la meme nuit rendait de nouveau ce verdict, et
-- l'appelant (preleverLoyersBaux, api/cron-minuit.js) rajoutait un jour et un loyer a la dette.
-- Poser le marqueur ne suffisait pas : l'appelant reecrivait le blob entier depuis une lecture
-- ANTERIEURE a la RPC, donc il effacait le marqueur dans la foulee. Le calcul de l'ardoise
-- descend donc DANS la RPC, ou revendication et effet deviennent atomiques -- une RPC est une
-- seule transaction et v_data est lu FOR UPDATE. La regle ne change pas (arbitrage du
-- 8 septembre 2026) : aucune expulsion automatique, un impaye est un fait qu'on chiffre, un
-- seul avis a l'ouverture. Deux verdicts distincts disent desormais a l'appelant s'il doit
-- poster cet avis. Reecriture PAR ANCRE : la fonction fait 6 320 caracteres, et chaque ancre
-- introuvable LEVE. PREUVES STRUCTURELLES ICI ; l'epreuve comportementale a eu lieu au banc,
-- en transaction annulee (cinq preuves vertes : ardoise a 1 jour malgre deux rejeux, 2 jours le
-- lendemain sans second avis, aucun argent deplace, branche payante intacte).
DO $$
DECLARE
  v_src  text;
  v_neuf text;
  k_decl constant text := '  v_rec         jsonb;' || E'\n' || 'BEGIN';
  k_exp  constant text :=
    '    IF COALESCE((v_data ->> ''avertissement'')::boolean, false) THEN' || E'\n' ||
    '      RETURN ''expulsion_requise'';' || E'\n' ||
    '    END IF;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_src
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'prelever_loyer_bail';
  IF v_src IS NULL THEN
    RAISE EXCEPTION 'prelever_loyer_bail est absente : rien a proteger';
  END IF;
  IF v_src ~ 'expulsion_requise_deja_avise' THEN
    RAISE NOTICE 'l''ardoise est deja atomique : rien a faire';
    RETURN;
  END IF;
  IF position(k_decl in v_src) = 0 THEN
    RAISE EXCEPTION 'ARRET : l''ancre de declaration a change. L''ardoise ne doit pas etre posee a l''aveugle.';
  END IF;
  v_neuf := replace(v_src, k_decl,
    '  v_rec         jsonb;' || E'\n' ||
    '  -- L''ardoise de l''impaye, desormais calculee ET posee ici : voir le bloc de la' || E'\n' ||
    '  -- branche « expulsion_requise ».' || E'\n' ||
    '  v_imp         jsonb;' || E'\n' ||
    '  v_avise       boolean;' || E'\n' ||
    'BEGIN');
  IF position(k_exp in v_neuf) = 0 THEN
    RAISE EXCEPTION 'ARRET : l''ancre de la branche expulsion_requise a change. L''ardoise ne doit pas etre posee a l''aveugle.';
  END IF;
  v_neuf := replace(v_neuf, k_exp,
    '    IF COALESCE((v_data ->> ''avertissement'')::boolean, false) THEN' || E'\n' ||
    '      -- ARDOISE ATOMIQUE (chantier 6, 9 octobre 2026). Cette branche etait LA SEULE sortie' || E'\n' ||
    '      -- a effet a ne pas poser jourPaiement : un rejeu du cron la meme nuit rendait de' || E'\n' ||
    '      -- nouveau « expulsion_requise », et l''appelant rajoutait un jour et un loyer a' || E'\n' ||
    '      -- l''ardoise. La dette DOUBLAIT a chaque passe.' || E'\n' ||
    '      --' || E'\n' ||
    '      -- Poser le marqueur ne suffisait pas : l''appelant reecrivait le blob entier depuis' || E'\n' ||
    '      -- une lecture ANTERIEURE a cet appel, et effacait donc le marqueur dans la foulee.' || E'\n' ||
    '      -- Le calcul de l''ardoise descend ici, ou il devient atomique avec sa revendication :' || E'\n' ||
    '      -- une RPC est une seule transaction, et v_data a ete lu FOR UPDATE.' || E'\n' ||
    '      --' || E'\n' ||
    '      -- La regle, elle, ne change pas (arbitrage du 8 septembre 2026) : aucune expulsion' || E'\n' ||
    '      -- automatique, un impaye est un FAIT qu''on chiffre et qu''on conserve, et un seul' || E'\n' ||
    '      -- avis a l''ouverture de l''ardoise. Aucun argent ne bouge : le loyer reste du.' || E'\n' ||
    '      v_imp := CASE WHEN jsonb_typeof(v_data -> ''impaye'') = ''object''' || E'\n' ||
    '                    THEN v_data -> ''impaye'' ELSE ''{}''::jsonb END;' || E'\n' ||
    '      v_avise := COALESCE((v_imp ->> ''avisEnvoye'')::boolean, false);' || E'\n' ||
    '      UPDATE locations_actives' || E'\n' ||
    '         SET data = v_data || jsonb_build_object(' || E'\n' ||
    '               ''jourPaiement'', v_jour,' || E'\n' ||
    '               ''impaye'', jsonb_build_object(' || E'\n' ||
    '                  ''depuis'',     COALESCE(v_imp ->> ''depuis'', v_jour),' || E'\n' ||
    '                  ''jours'',      COALESCE((v_imp ->> ''jours'')::numeric, 0) + 1,' || E'\n' ||
    '                  ''montantDu'',  COALESCE((v_imp ->> ''montantDu'')::numeric, 0) + v_prix,' || E'\n' ||
    '                  ''avisEnvoye'', true))' || E'\n' ||
    '       WHERE id = p_bail_id;' || E'\n' ||
    '      -- Deux verdicts distincts, parce que l''appelant n''a plus qu''une chose a faire et' || E'\n' ||
    '      -- qu''elle depend de celui-ci : poster l''avis UNE fois, a l''ouverture.' || E'\n' ||
    '      IF v_avise THEN' || E'\n' ||
    '        RETURN ''expulsion_requise_deja_avise'';' || E'\n' ||
    '      END IF;' || E'\n' ||
    '      RETURN ''expulsion_requise'';' || E'\n' ||
    '    END IF;');
  EXECUTE v_neuf;
  RAISE NOTICE 'ardoise de l''impaye rendue atomique dans prelever_loyer_bail';
END $$;

DO $$
DECLARE v_def text; v_droits text; v_md5 text; v_n int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'prelever_loyer_bail';

  -- PREUVE 1 : l'ardoise est dans la fonction, et l'ANCIENNE SORTIE NUE a disparu -- c'est-a-dire
  -- le test d'avertissement suivi IMMEDIATEMENT du RETURN, sans rien ecrire entre les deux.
  IF v_def !~ 'expulsion_requise_deja_avise' THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- le second verdict est absent';
  END IF;
  IF v_def !~ 'v_imp         jsonb;' OR v_def !~ 'v_avise       boolean;' THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- les variables de l''ardoise ne sont pas declarees';
  END IF;
  IF position('    IF COALESCE((v_data ->> ''avertissement'')::boolean, false) THEN' || E'\n' ||
              '      RETURN ''expulsion_requise'';' in v_def) > 0 THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- la sortie nue sans marqueur subsiste';
  END IF;

  -- PREUVE 2 : la branche pose le marqueur du jour ET l'ardoise, dans la meme ecriture.
  IF position('''jourPaiement'', v_jour,' || E'\n' || '               ''impaye''' in v_def) = 0 THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- marqueur et ardoise ne sont pas poses ensemble';
  END IF;

  -- PREUVE 3 : SIX poses de jourPaiement, la ou il y en avait CINQ. Le compte exact importe :
  -- il interdit aussi bien l'oubli que le doublon. La premiere version de cette preuve en
  -- annoncait quatre, et c'est elle qui a refuse la migration jusqu'a ce que le compte soit juste.
  SELECT count(*) INTO v_n FROM regexp_matches(v_def, '''jourPaiement'', v_jour', 'g');
  IF v_n <> 6 THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- % poses de jourPaiement au lieu de 6', v_n;
  END IF;

  -- PREUVE 4 : une reecriture ne doit rien perdre. Autorite, search_path et droits identiques.
  IF v_def !~ 'SECURITY DEFINER' OR v_def !~ 'search_path TO ''public'', ''pg_temp''' THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- l''autorite ou le search_path a change';
  END IF;
  SELECT string_agg(coalesce(r.rolname,'PUBLIC') || ':' || ae.privilege_type, ', '
                    ORDER BY coalesce(r.rolname,'PUBLIC'))
    INTO v_droits
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
    CROSS JOIN LATERAL aclexplode(p.proacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE p.proname = 'prelever_loyer_bail';
  IF v_droits IS DISTINCT FROM 'postgres:EXECUTE, service_role:EXECUTE' THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- les droits sont « % » au lieu de postgres+service_role', v_droits;
  END IF;

  -- PREUVE 5 : aucune donnee touchee. Le seul bail de la beta est intact.
  SELECT md5(data::text) INTO v_md5 FROM public.locations_actives ORDER BY id LIMIT 1;
  IF v_md5 IS DISTINCT FROM '0d1c3936f4dbc739e9fd517b1f957abb' THEN
    RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- le bail a change : % au lieu de 0d1c3936...', v_md5;
  END IF;

  RAISE NOTICE 'CINQ PREUVES STRUCTURELLES VERTES.';
END $$;