-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009003201 (UTC ; 02h32 a Paris), nom
-- `mails_portent_leur_identite`. Le registre passe de 562 a 563 entrees.
--
-- LE CORPS CI-DESSOUS EST LE TEXTE EXACT ENREGISTRE : md5
-- 5dcde25b511e3ded71da4cc74c24b48e, 4 175 caracteres, 1 instruction au registre. Il a ete
-- relu depuis `supabase_migrations.schema_migrations` et son empreinte verifiee avant d'etre
-- archive. Le fichier de travail s'appelait
-- `migrations/20261009023500_mails_portent_leur_identite.sql` ; son raisonnement est repris
-- ci-dessous, et le texte applique n'en differe que par les commentaires, raccourcis pour la
-- taille du transport MCP.
--
-- ETAT APRES APPLICATION, RELU DANS LA BASE :
--   . `mails.id` porte le defaut
--     `(('mail-' || ((EXTRACT(epoch FROM clock_timestamp()) * 1000))::bigint) || '-')
--      || substr(md5(random()::text), 1, 6)` ;
--   . `id` est toujours `NOT NULL` et la cle primaire est toujours `PRIMARY KEY (id)` ;
--   . AUCUNE DONNEE TOUCHEE, et c'est prouve par empreinte avant/apres : mails 28 lignes
--     3d1b87e4..., personnages_donnees 8 lignes 3bc9771a..., caisses_batiments 150 lignes
--     f72fd8bb..., comptes_bancaires 18 lignes 0fe6e3ab... -- les quatre identiques au releve
--     pris juste avant l'application.
--
-- -----------------------------------------------------------------------------
-- CE QU'ELLE FERME
-- -----------------------------------------------------------------------------
-- `public.mails.id` est `text NOT NULL`, cle primaire, et n'avait AUCUNE valeur par defaut.
-- Neuf sites d'ecriture, dans deux fonctions SQL, inserent sans le fournir : la ligne leve
-- `23502 null value in column "id" of relation "mails"`. Et comme une RPC est UNE SEULE
-- transaction, l'exception annule TOUT le traitement, pas seulement le mail.
--
-- CE QUE CELA COUTAIT REELLEMENT. Dans `traiter_prets_helvetia_quotidien`, la branche
-- « debiteur a sec » poste un avertissement : elle levait, donc aucun impaye n'etait jamais
-- comptabilise, aucune mise en demeure envoyee, aucune saisie declenchee -- et la passe
-- nocturne des prets Helvetia mourait entiere au premier emprunteur insolvable. Le defaut
-- etait latent uniquement parce que la table `prets` est vide aujourd'hui.
--
-- -----------------------------------------------------------------------------
-- LE PERIMETRE EXACT, MESURE SUR LES 664 FONCTIONS ET NON SUPPOSE
-- -----------------------------------------------------------------------------
-- DEUX fonctions inserent dans `mails` sans nommer `id`, pour NEUF sites :
--   . traiter_prets_helvetia_quotidien  -- 7 sites (avertissement, mise en demeure, saisie,
--     proposition de bien, refus, absorption de perte, cloture) ;
--   . finaliser_achat_bien_helvetia      -- 2 sites.
-- Les deux appartiennent au domaine `banque`, et les deux sont Helvetia : c'est l'oubli d'un
-- seul auteur dans un seul coin, pas une pratique du projet.
--
-- HUIT autres fonctions fournissent `id` correctement, dont la porte generique
-- `mail_systeme_envoyer`.
--
-- UNE PRECISION QUI CORRIGE UN RELEVE ANTERIEUR, ET IL FAUT LA LIRE. L'en-tete de la
-- migration 20261008235521 annonce « DIX fonctions SQL partagent ce defaut, dont la porte
-- generique mail_systeme_envoyer ». C'EST FAUX. Le compte a ete refait sur les 664 fonctions,
-- une par une : elles sont DEUX, et `mail_systeme_envoyer` fait partie de celles qui ont
-- toujours eu raison. Le chiffre de dix melangeait les deux familles -- celles qui inserent
-- sans id et celles qui touchent `mails` tout court.
--
-- -----------------------------------------------------------------------------
-- POURQUOI LA TABLE, ET PAS LES NEUF SITES
-- -----------------------------------------------------------------------------
-- « Un mail a une identite » est un invariant de la TABLE. Le confier a onze sites
-- d'ecriture, c'est onze occasions de l'oublier -- et neuf l'ont deja fait. Un DEFAULT le
-- garantit la ou il vit, une seule fois, y compris pour le site qui sera ecrit demain.
--
-- AUCUNE CONVENTION N'EST INVENTEE. L'expression est, au caractere pres, celle que
-- `mail_systeme_envoyer` produit depuis toujours. La preuve 2 compare les deux textes et LEVE
-- s'ils divergent : si la porte generique change de format un jour, cette migration le
-- signalera au lieu de laisser deux formats coexister sans que personne ne l'ait decide.
--
-- `clock_timestamp()` et non `now()` : `now()` est figee pour toute la transaction, donc sept
-- mails ecrits dans la meme passe nocturne obtiendraient le meme horodatage et ne
-- dependraient plus que des six caracteres aleatoires pour ne pas collisionner.
--
-- CE QUE CE DEFAUT NE FAIT PAS. Il n'ecrase aucun `id` fourni -- tous les chemins JavaScript
-- continuent de poser le leur, et le banc l'a verifie. Il ne relache ni le `NOT NULL` ni la
-- cle primaire, que la preuve 3 recontrole. Et il ne touche AUCUNE ligne : les 28 mails
-- existants gardent leur identifiant, quel que soit son format -- la base en porte plusieurs,
-- dont certains ne commencent meme pas par « mail- », et les renommer casserait des liens
-- deja envoyes.
--
-- -----------------------------------------------------------------------------
-- CE QUI RESTE A FAIRE APRES, ET QUI N'EST PAS ICI
-- -----------------------------------------------------------------------------
-- Les neuf sites devraient a terme passer par `mail_systeme_envoyer` plutot que d'ecrire la
-- table en direct -- c'est la suppression de duplication, priorite 3. Elle n'est pas faite ici
-- parce qu'elle pose une vraie question : la porte rend un verdict jsonb
-- (`parametres_invalides`, `expediteur_non_autorise`) et decider si un verdict negatif doit
-- faire echouer la passe nocturne ou etre avale releve du CHANTIER 5, pas de celui-ci. Le
-- present lot ferme la robustesse (priorite 4) sans prejuger de cet arbitrage.
--
-- -----------------------------------------------------------------------------
-- SES PREUVES SONT STRUCTURELLES, ET C'EST LA PREMIERE MIGRATION ECRITE SOUS LA REGLE
-- -----------------------------------------------------------------------------
-- Elles lisent le catalogue : le defaut existe (1), il est identique a celui de la porte
-- generique (2), la cle primaire et le NOT NULL tiennent (3), les 28 mails sont intacts et
-- aucun n'a perdu son identifiant (4), et le perimetre est bien de DEUX fonctions (5).
--
-- L'EPREUVE COMPORTEMENTALE A EU LIEU AVANT, AU BANC, EN TRANSACTION ANNULEE :
--   . une insertion sans id aboutit et rend `mail-1791505677843-c060c2` ;
--   . trois insertions d'affilee ne collisionnent pas sur la cle primaire ;
--   . un id fourni explicitement est respecte ;
--   . et surtout la branche « debiteur a sec » de la RPC Helvetia TRAVERSE enfin --
--     `jours_impayes` passe a 1 et l'avertissement est poste, la ou elle levait 23502.
-- Le banc a ete verifie annule : ni mail, ni pret, ni compte temoin ne subsistent, et le
-- defaut n'etait pas en base avant l'application.
--
-- La raison de cette separation est ecrite dans WORKFLOW-SUPABASE.md temps 3, et elle a ete
-- payee comptant : la migration 20261008235521 a prouve son effet en faisant tourner la
-- mecanique, et a commite les effets de bord de ses propres preuves sur DEUX tables
-- auxquelles personne ne pensait.
-- =============================================================================

-- Chantier 6 -- un mail porte son identite, et ce n'est plus a ses neuf appelants de s'en
-- souvenir. `public.mails.id` est text NOT NULL, cle primaire, SANS defaut : neuf sites dans
-- DEUX fonctions (traiter_prets_helvetia_quotidien, 7 sites ; finaliser_achat_bien_helvetia,
-- 2 sites) inserent sans le fournir et levent 23502 -- ce qui, une RPC etant une seule
-- transaction, annule TOUTE la passe nocturne des prets au premier debiteur insolvable.
-- L'expression du defaut est, au caractere pres, celle que la porte generique
-- mail_systeme_envoyer produit depuis toujours : aucune convention n'est inventee, et la
-- preuve 2 leve si les deux divergent. Le raisonnement complet est dans
-- historique/migrations-appliquees/, dont ce texte est le code executable.
-- LES PREUVES SONT STRUCTURELLES, ET C'EST VOULU : l'epreuve comportementale a eu lieu au
-- banc, en transaction annulee (branche « debiteur a sec » qui traverse enfin, jours_impayes
-- a 1, avertissement poste), parce qu'une migration COMMITE les effets de bord de ses preuves.
DO $$
DECLARE v_defaut text;
BEGIN
  SELECT pg_get_expr(ad.adbin, ad.adrelid) INTO v_defaut
    FROM pg_attrdef ad JOIN pg_attribute a ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
   WHERE ad.adrelid = 'public.mails'::regclass AND a.attname = 'id';
  IF v_defaut IS NOT NULL THEN
    RAISE NOTICE 'mails.id porte deja un defaut : rien a faire';
    RETURN;
  END IF;
  ALTER TABLE public.mails
    ALTER COLUMN id SET DEFAULT ('mail-' || (extract(epoch from clock_timestamp())*1000)::bigint
                                         || '-' || substr(md5(random()::text), 1, 6));
  RAISE NOTICE 'mails.id porte desormais son identite par defaut';
END $$;

DO $$
DECLARE v_defaut text; v_porte text; v_n int; v_sans int;
BEGIN
  SELECT pg_get_expr(ad.adbin, ad.adrelid) INTO v_defaut
    FROM pg_attrdef ad JOIN pg_attribute a ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
   WHERE ad.adrelid = 'public.mails'::regclass AND a.attname = 'id';
  IF v_defaut IS NULL THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- mails.id n''a toujours aucun defaut';
  END IF;
  IF v_defaut !~ 'clock_timestamp' OR v_defaut !~ 'md5' OR v_defaut !~ 'mail-' THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- le defaut pose n''est pas celui attendu : %', v_defaut;
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_porte
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'mail_systeme_envoyer';
  IF v_porte IS NULL THEN
    RAISE EXCEPTION 'PREUVE 2 IMPOSSIBLE -- mail_systeme_envoyer est absente';
  END IF;
  IF position('''mail-'' || (extract(epoch from clock_timestamp())*1000)::bigint' in v_porte) = 0 THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- mail_systeme_envoyer ne fabrique plus l''id de cette facon : le defaut pose doit etre realigne, pas laisse divergent';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_attribute
                  WHERE attrelid = 'public.mails'::regclass AND attname = 'id' AND attnotnull) THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- mails.id a perdu son NOT NULL';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.mails'::regclass AND contype = 'p'
                    AND pg_get_constraintdef(oid) = 'PRIMARY KEY (id)') THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- la cle primaire de mails n''est plus PRIMARY KEY (id)';
  END IF;

  SELECT count(*) INTO v_n FROM public.mails;
  IF v_n <> 28 THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- % mails au lieu des 28 releves a l''inspection', v_n;
  END IF;
  IF EXISTS (SELECT 1 FROM public.mails WHERE id IS NULL OR btrim(id) = '') THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- un mail existant a perdu son identifiant';
  END IF;

  SELECT count(*) INTO v_sans
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE pg_get_functiondef(p.oid) ~ 'INSERT INTO public\.mails\s*\(\s*to_player';
  IF v_sans <> 2 THEN
    RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- % fonctions inserent sans nommer id, l''en-tete en annonce 2', v_sans;
  END IF;

  RAISE NOTICE 'CINQ PREUVES STRUCTURELLES VERTES.';
END $$;