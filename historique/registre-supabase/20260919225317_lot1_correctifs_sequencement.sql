-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919225317
-- Nom original      : lot1_correctifs_sequencement
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 22:53:17 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5daedbb3de6742b2b7b8942525b5a154
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =====================================================================
-- LOT P0-A — DEUX CORRECTIFS, ASSUMES
-- =====================================================================

-- CORRECTIF 1 — SEQUENCEMENT. J'avais annonce que les migrations de FERMETURE
-- partiraient avec le push, pour ne pas casser le client deja deploye sur
-- Vercel. J'ai malgre tout revoque caisse_institution_mouvement : le bundle en
-- production appelle encore cette primitive, tout paiement institutionnel etait
-- donc casse depuis cette migration. Le droit est retabli ici ; la revocation
-- est consignee dans le rapport et sera rejouee AU MOMENT DU PUSH, quand le
-- client migre vers caisse_client_mouvement sera en ligne.
-- La nouvelle porte (caisse_client_mouvement) reste en place et operationnelle :
-- elle est additive, elle ne casse rien.
GRANT EXECUTE ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.caisse_institution_mouvement_plafonne(text, numeric) TO authenticated;

-- CORRECTIF 2 — EXPEDITEURS MANQUANTS. Ma premiere extraction lisait les
-- litteraux avec une expression qui coupait aux apostrophes echappees : trois
-- expediteurs reels avaient ete tronques ou perdus. Releve exact refait sur les
-- 82 appels a sbSendMail : 56 litteraux, 26 distincts, 26 appels a expediteur
-- variable (le nom du joueur lui-meme, ses replis, ou un nom d'organisation).
INSERT INTO public.mails_expediteurs_systeme (expediteur, note) VALUES
  ('Service de l''Immigration',  'naturalisation'),
  ('Bureau National de l''Emploi','emploi'),
  ('Anonyme',                    'repli quand le nom du joueur manque'),
  ('Un citoyen',                 'repli quand le nom du joueur manque'),
  ('Lieutenant',                 'repli militaire')
ON CONFLICT (expediteur) DO NOTHING;

-- Un mail envoye au nom d'une ORGANISATION porte le vrai auteur dans from_real.
-- La policy l'acceptait deja par ce biais ; on ajoute explicitement le cas ou
-- l'expediteur affiche est le nom d'une organisation existante, pour que ce
-- parcours reste ouvert le jour ou des organisations seront creees (la table en
-- compte zero aujourd'hui, ce chemin est donc actuellement inerte).
CREATE OR REPLACE FUNCTION public.mail_expediteur_organisation(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.organisations o
     WHERE coalesce(o.data::jsonb ->> 'nom', '') = p_nom
  );
$$;
REVOKE ALL ON FUNCTION public.mail_expediteur_organisation(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_organisation(text) TO authenticated, service_role;

DROP POLICY IF EXISTS mails_envoi ON public.mails;
CREATE POLICY mails_envoi ON public.mails
  FOR INSERT TO authenticated
  WITH CHECK (from_player = public.mon_personnage()
           OR from_real   = public.mon_personnage()
           OR public.mail_expediteur_systeme(from_player)
           OR public.mail_expediteur_organisation(from_player));