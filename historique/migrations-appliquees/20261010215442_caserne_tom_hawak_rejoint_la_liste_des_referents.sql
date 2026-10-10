-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010215442 (UTC), nom `caserne_tom_hawak_rejoint_la_liste_des_referents`.
-- Le registre passe de 636 a 637 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 e58dcc3a0ae5dad8f6ccf499ca17bc1f, 2623 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE LIGNE, ET ELLE N'EST PAS DECORATIVE
--
-- `pnj_referents` est la LISTE FERMEE qui autorise la memoire pedagogique d'un referent :
-- `referent_pedagogie_noter` rend « referent: false » sans rien ecrire pour un identifiant qui
-- n'y figure pas. Sans cette ligne, le Commandant Tom Hawak aurait eu une personnalite, un
-- corpus et une voix -- et AUCUN SOUVENIR : il aurait tout reexplique depuis le debut a chaque
-- visite, la ou les dix-huit autres referents enchainent. Ils sont dix-neuf.
--
-- PREUVE : outils/bancs/banc-referent-commandant.js, 20 epreuves sous JavaScriptCore.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LE COMMANDANT TOM HAWAK REJOINT LA LISTE FERMEE DES REFERENTS (10 octobre 2026)
-- =================================================================================================
-- POURQUOI CETTE LIGNE EST NECESSAIRE, ET PAS DECORATIVE. `pnj_referents` existe pour une seule
-- raison, ecrite dans son propre commentaire : empecher qu'un client fasse naitre cent quatre-vingts
-- lignes de memoire en demandant gentiment. `referent_pedagogie_noter` interroge cette liste et
-- rend `referent: false` sans rien ecrire quand l'identifiant n'y figure pas.
--
-- Sans cette ligne, le Commandant Tom Hawak aurait une personnalite, un corpus et une voix -- mais
-- AUCUNE MEMOIRE PEDAGOGIQUE : il reprendrait l'explication au debut a chaque visite, la ou les
-- dix-huit autres referents se souviennent de ce qu'ils ont deja expose. La difference serait
-- invisible dans le code et parfaitement visible pour le joueur.
--
-- `domaine` n'est PAS le domaine envoye au modele : c'est un libelle de lecture. La personnalite et
-- le corpus vivent dans api/_pnj-referents.js et api/_pnj-profils.js, source unique.
--
-- AUCUNE LIGNE DE SUJET CONNU n'est posee, et c'est voulu : seule Gretta Delieu en a: ses huit
-- sujets servent une pedagogie par etapes qui lui est propre. Les dix-huit autres referents, dont
-- Martial Bouterin, n'en ont aucun -- leur memoire compte les consultations, pas les chapitres.
-- =================================================================================================

INSERT INTO public.pnj_referents (referent_id, domaine, pays)
VALUES ('commandant_tom_hawak', 'militaire — commandement, compagnies, grades et caisse', 'republic')
ON CONFLICT (referent_id) DO UPDATE
   SET domaine = EXCLUDED.domaine, pays = EXCLUDED.pays;

-- PREUVES STRUCTURELLES
DO $$
DECLARE v_n integer;
BEGIN
  SELECT count(*) INTO v_n FROM public.pnj_referents
   WHERE referent_id = 'commandant_tom_hawak' AND pays = 'republic';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 : le referent n est pas inscrit'; END IF;

  -- P2 : il est le DIX-NEUVIEME, et aucun autre n a bouge.
  SELECT count(*) INTO v_n FROM public.pnj_referents;
  IF v_n <> 19 THEN RAISE EXCEPTION 'P2 : % referents au lieu de 19', v_n; END IF;

  -- P3 : « general_faure » n a jamais ete un referent et ne le devient pas.
  SELECT count(*) INTO v_n FROM public.pnj_referents WHERE referent_id LIKE '%faure%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3 : un referent Faure existe'; END IF;

  RAISE NOTICE 'Tom Hawak est le 19e referent.';
END $$;
