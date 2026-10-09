-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261008235521 (horodatage UTC du registre ; 01h55 a Paris),
-- nom `idempotence_prets_helvetia`. Le registre passe de 561 a 562 entrees.
--
-- LE CORPS CI-DESSOUS EST LE TEXTE EXACT ENREGISTRE : md5
-- c36630f75ecacc2bb378613f20da48a1, 6 071 caracteres. Il a ete relu depuis
-- `supabase_migrations.schema_migrations` et son empreinte verifiee avant d'etre archive. Son
-- propre en-tete renvoie a `migrations/20261009015300_idempotence_prets_helvetia.sql` : ce
-- fichier de travail n'existe plus -- c'est le present fichier qui lui succede, et le
-- raisonnement qu'il portait est repris ci-dessous. Le texte applique differait de ce brouillon
-- par les seules lignes vides et par six declarations regroupees sur une ligne, pour tenir dans
-- la limite de taille du transport MCP.
--
-- -----------------------------------------------------------------------------
-- LIRE CECI D'ABORD : SES PREUVES ONT LAISSE UN ECART, ET J'AI DU LE RESTITUER
-- -----------------------------------------------------------------------------
-- La preuve 3 cree un pret temoin et appelle la RPC pour de vrai, quatre fois, afin de
-- demontrer qu'un seul prelevement a lieu par jour. Le pret et le compte temoins sont
-- supprimes a la fin. MAIS la RPC ne touche pas que ces deux lignes : a chaque prelevement
-- elle CREDITE la caisse `<pays>_banque-privee`. Deux prelevements ont donc depose 1 000 FR
-- dans `republic_banque-privee`, et la migration -- une fois COMMITEE -- les a laisses la.
--
-- Constate aussitot par l'empreinte md5 des caisses, qui ne correspondait plus a celle d'avant
-- l'application. Restitue dans la minute : `{"solde": 1000}` ramene a `{"solde": 0}`.
-- L'etat d'avant est etabli par trois faits concordants -- les trois autres empires portent
-- `{"solde": 0}`, le mecanisme Helvetia n'avait jamais tourne puisque la table `prets` etait
-- vide, et 1 000 est exactement le double de la mensualite temoin. Apres restitution, les
-- quatre banques privees sont a 0. Verifie aussi : AUCUNE fonction ne compare
-- `caisses_batiments.updated_at`, donc l'horodatage reste seul temoin de l'incident -- et c'est
-- preferable a une metadonnee falsifiee.
--
-- LA LECON, ET ELLE VAUT POUR TOUTE MIGRATION FUTURE. Un banc en transaction annulee peut
-- faire tourner la mecanique : tout est annule. Une MIGRATION, elle, COMMITE -- y compris les
-- effets de bord de ses propres preuves, sur des tables auxquelles on ne pensait pas. Dans une
-- migration, les preuves doivent donc etre STRUCTURELLES : lire le corps d'une fonction,
-- compter des droits, verifier une contrainte. L'epreuve COMPORTEMENTALE appartient au banc,
-- avant application, et a lui seul.
--
-- -----------------------------------------------------------------------------
-- CE QU'ELLE FERME
-- -----------------------------------------------------------------------------
-- `traiter_prets_helvetia_quotidien` n'avait AUCUN marqueur de journee. Son seul filtre etait
-- `WHERE type_banque = 'helvetia' AND statut IN ('en_cours','contentieux')` -- un statut qui ne
-- change pas quand la mensualite est payee. Un second appel le meme soir -- retry apres
-- timeout, double declenchement, relance manuelle -- prelevait une SECONDE MENSUALITE ENTIERE.
--
-- ET L'ESCALADE DU CONTENTIEUX AVANCAIT DE DEUX CRANS EN UNE NUIT. Pour un debiteur a sec :
-- premier passage `jours_impayes` 0 -> 1 et avertissement ; rejeu 1 -> 2, donc
-- `statut = 'contentieux'` et mise en demeure ; troisieme passage, la saisie financiere.
--
-- CE DEFAUT AVAIT DEJA ETE REPARE AILLEURS. Le chemin bancaire *legacy*
-- (`preleverPretsBancairesServeur`, api/cron-minuit.js) a recu son marqueur le 14 septembre
-- 2026, avec un commentaire qui decrit exactement le meme symptome. Le chemin Helvetia etant
-- une RPC SQL, il n'avait jamais recu le correctif. La colonne `prets.jour_dernier_prelevement`
-- existait deja, et les deux chemins ecrivent desormais la MEME colonne au MEME format --
-- verifie : `jourParisISO()` cote JS et `to_char(now() AT TIME ZONE 'Europe/Paris',
-- 'YYYY-MM-DD')` cote SQL rendent la meme chaine.
--
-- OU LA GARDE EST POSEE, ET POURQUOI PAS AILLEURS. Apres le bloc des accords de
-- reechelonnement, avant le prelevement. Les effets du bloc des accords sont IDEMPOTENTS
-- (`accord_actif = false`, `accord_avertissement_envoye = true` sont des affectations
-- absolues) et doivent continuer de tourner chaque nuit -- un accord doit pouvoir expirer.
-- Seul le prelevement, qui est un delta, demande la garde. On protege ce qui n'est pas
-- idempotent ; on laisse passer ce qui l'est. La preuve 2 verifie cet ordre.
--
-- LE MARQUEUR EST POSE AVANT TOUT MOUVEMENT, et c'est sans risque parce qu'une RPC est UNE
-- SEULE TRANSACTION : un echec plus loin l'annule avec le reste. C'est ce qui distingue ce
-- correctif des fenetres cote JavaScript, ou chaque appel HTTP est sa propre transaction.
--
-- POURQUOI UNE REECRITURE PAR ANCRE. La fonction fait 15 232 caracteres ; la recopier pour y
-- ajouter six lignes offrirait 15 000 occasions de l'alterer. Son corps est relu par
-- `pg_get_functiondef`, modifie par deux `replace()` sur des ancres exactes, et rejoue -- le
-- procede du chantier 4G. Chaque ancre introuvable LEVE. Et la migration est idempotente : si
-- la garde est deja la, elle ne fait rien et le dit.
--
-- -----------------------------------------------------------------------------
-- UN SECOND DEFAUT, DECOUVERT EN L'EPROUVANT, ET NON CORRIGE ICI
-- -----------------------------------------------------------------------------
-- La branche « debiteur a sec » de cette RPC **LEVE**, pour une cause etrangere a
-- l'idempotence : elle fait `INSERT INTO public.mails (...)` SANS fournir `id`, alors que
-- `mails.id` est `text NOT NULL` sans valeur par defaut. Constate au banc :
-- `23502 null value in column "id" of relation "mails"`. Comme une RPC est une transaction,
-- l'exception annule TOUT le traitement, pas seulement le mail.
--
-- CORRECTION DU 9 OCTOBRE 2026, 02h40. Cette ligne annoncait « DIX fonctions SQL partagent ce
-- defaut, dont la porte generique mail_systeme_envoyer ». C'ETAIT FAUX, et le compte a ete
-- refait fonction par fonction sur les 664 : elles sont DEUX --
-- `traiter_prets_helvetia_quotidien` (7 sites) et `finaliser_achat_bien_helvetia` (2 sites),
-- les deux du domaine `banque`, les deux Helvetia. `mail_systeme_envoyer` fait partie des HUIT
-- qui fournissent leur `id` correctement : elle a toujours eu raison. Le chiffre de dix
-- melangeait deux familles -- celles qui inserent sans id et celles qui touchent `mails` tout
-- court. La ligne fausse n'est pas effacee en silence : elle est corrigee, datee, et le lot
-- qui a ferme le defaut est l'archive `20261009003201_mails_portent_leur_identite.sql`.
--
-- Le defaut etait latent parce que `prets` est vide, mais il se declenchait au premier
-- emprunteur Helvetia insolvable. Il est FERME depuis le 9 octobre 2026 a 02h32, non pas en
-- reecrivant les neuf sites, mais en donnant a `mails.id` la valeur par defaut que la porte
-- generique fabriquait deja : un invariant de table appartient a la table.
--
-- -----------------------------------------------------------------------------
-- CE QUI A ETE PROUVE AVANT APPLICATION, en transaction annulee
-- -----------------------------------------------------------------------------
-- Pret temoin de 5 000 FR, mensualite 500, emprunteur solvable :
--   . premier passage : 5000 -> 4500 ;
--   . deuxieme passage le MEME jour : 4500 -> 4500 ;
--   . troisieme passage le MEME jour : 4500 -> 4500 ;
--   . le marqueur porte la date du jour en Europe/Paris ;
--   . le verdict rendu nomme la cause : `deja_traite_aujourdhui` ;
--   . le JOUR SUIVANT, le prelevement reprend : 4500 -> 4000.
-- Les deux dernieres epreuves sont celles qui comptent : une garde qui bloquerait aussi le
-- lendemain aurait arrete l'echeancier au lieu de le proteger.
-- =============================================================================

-- Chantier 6 -- un echeancier ne s'execute qu'une fois par jour : le chemin Helvetia.
-- Le raisonnement complet, le defaut mesure et les cinq preuves sont dans
-- migrations/20261009015300_idempotence_prets_helvetia.sql, dont ce texte est le code
-- executable (meme arbre syntaxique, 2 instructions, commentaires retires pour la taille du
-- transport). Banc en transaction annulee : 5 preuves vertes avant application.

DO $$
DECLARE
  v_src text;
  v_neuf text;
  k_decl  constant text := '  v_bien record;' || E'\n' || 'BEGIN';
  k_garde constant text := '    SELECT * INTO v_perso FROM public.personnages WHERE name = v_pret.emprunteur FOR UPDATE;';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_src
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'traiter_prets_helvetia_quotidien';
  IF v_src IS NULL THEN
    RAISE EXCEPTION 'traiter_prets_helvetia_quotidien est absente : rien a proteger';
  END IF;
  IF v_src ~ 'jour_dernier_prelevement = v_jour' THEN
    RAISE NOTICE 'la garde est deja posee : rien a faire';
    RETURN;
  END IF;
  IF position(k_decl in v_src) = 0 THEN
    RAISE EXCEPTION 'ARRET : l''ancre de declaration a change. La garde ne doit pas etre posee a l''aveugle.';
  END IF;
  v_neuf := replace(v_src, k_decl,
    '  v_bien record;' || E'\n' ||
    '  -- Le jour de reference, en Europe/Paris : meme format que jourParisISO() cote JS, qui' || E'\n' ||
    '  -- ecrit la MEME colonne pour les prets non-Helvetia.' || E'\n' ||
    '  v_jour text := to_char(now() AT TIME ZONE ''Europe/Paris'', ''YYYY-MM-DD'');' || E'\n' ||
    'BEGIN');
  IF position(k_garde in v_neuf) = 0 THEN
    RAISE EXCEPTION 'ARRET : l''ancre du prelevement a change. La garde ne doit pas etre posee a l''aveugle.';
  END IF;
  v_neuf := replace(v_neuf, k_garde,
    '    -- MARQUEUR ANTI-REJEU (chantier 6, 9 octobre 2026). Pose APRES le bloc des accords,' || E'\n' ||
    '    -- dont les effets sont idempotents et doivent tourner chaque nuit, et AVANT le' || E'\n' ||
    '    -- prelevement, qui est un delta. Une RPC etant une seule transaction, poser le' || E'\n' ||
    '    -- marqueur en premier est sans risque : un echec plus loin l''annule avec le reste.' || E'\n' ||
    '    IF v_pret.jour_dernier_prelevement = v_jour THEN' || E'\n' ||
    '      pret_id := v_pret.id; action := ''deja_traite_aujourdhui''; RETURN NEXT;' || E'\n' ||
    '      CONTINUE;' || E'\n' ||
    '    END IF;' || E'\n' ||
    '    UPDATE public.prets SET jour_dernier_prelevement = v_jour WHERE id = v_pret.id;' || E'\n' ||
    k_garde);
  EXECUTE v_neuf;
  RAISE NOTICE 'garde anti-rejeu posee sur traiter_prets_helvetia_quotidien';
END $$;

DO $$
DECLARE
  v_def text; v_emp text; v_r0 numeric; v_r1 numeric; v_r2 numeric; v_action text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'traiter_prets_helvetia_quotidien';
  IF v_def !~ 'jour_dernier_prelevement = v_jour' THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- la garde est absente du corps';
  END IF;
  IF v_def !~ 'v_jour text :=' THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- le jour de reference n''est pas declare';
  END IF;
  IF position('accord_actif' in v_def) > position('jour_dernier_prelevement = v_jour' in v_def) THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- la garde precede le bloc des accords, qui ne tournerait plus';
  END IF;

  SELECT name INTO v_emp FROM public.personnages_donnees ORDER BY name LIMIT 1;
  IF v_emp IS NULL THEN
    RAISE EXCEPTION 'PREUVE 3 IMPOSSIBLE -- aucun personnage pour porter le pret temoin';
  END IF;

  INSERT INTO public.comptes_bancaires (id, personnage, pays, banque, solde)
  VALUES ('zz-migr-cpt', v_emp, 'republic', 'helvetia', 100000);
  INSERT INTO public.prets (id, emprunteur, country, type_banque, statut, montant_initial,
                            montant_restant, duree_jours, mensualite, jours_impayes)
  VALUES ('zz-migr-pret', v_emp, 'republic', 'helvetia', 'en_cours', 5000, 5000, 10, 500, 0);

  SELECT montant_restant INTO v_r0 FROM public.prets WHERE id = 'zz-migr-pret';
  PERFORM public.traiter_prets_helvetia_quotidien();
  SELECT montant_restant INTO v_r1 FROM public.prets WHERE id = 'zz-migr-pret';
  PERFORM public.traiter_prets_helvetia_quotidien();
  PERFORM public.traiter_prets_helvetia_quotidien();
  SELECT montant_restant INTO v_r2 FROM public.prets WHERE id = 'zz-migr-pret';

  IF v_r1 <> v_r0 - 500 THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- le premier passage n''a pas preleve la mensualite (% -> %)', v_r0, v_r1;
  END IF;
  IF v_r2 <> v_r1 THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- deux passages de plus ont encore preleve (% -> %)', v_r1, v_r2;
  END IF;

  IF (SELECT jour_dernier_prelevement FROM public.prets WHERE id = 'zz-migr-pret')
     <> to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD') THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- le marqueur ne porte pas le jour courant';
  END IF;
  SELECT action INTO v_action FROM public.traiter_prets_helvetia_quotidien() LIMIT 1;
  IF v_action <> 'deja_traite_aujourdhui' THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- le verdict rendu est « % »', v_action;
  END IF;

  UPDATE public.prets SET jour_dernier_prelevement = '2000-01-01' WHERE id = 'zz-migr-pret';
  PERFORM public.traiter_prets_helvetia_quotidien();
  IF (SELECT montant_restant FROM public.prets WHERE id = 'zz-migr-pret') <> v_r2 - 500 THEN
    RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- le prelevement ne reprend pas le jour suivant';
  END IF;

  DELETE FROM public.prets WHERE id = 'zz-migr-pret';
  DELETE FROM public.comptes_bancaires WHERE id = 'zz-migr-cpt';
  IF EXISTS (SELECT 1 FROM public.prets WHERE id = 'zz-migr-pret')
     OR EXISTS (SELECT 1 FROM public.comptes_bancaires WHERE id = 'zz-migr-cpt') THEN
    RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- le temoin n''a pas ete retire';
  END IF;

  RAISE NOTICE 'CINQ PREUVES VERTES. Trois passages, une seule mensualite ; le lendemain reprend.';
END $$;