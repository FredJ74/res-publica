-- =====================================================================
-- MAILS SYSTEME ATTESTES — LOT DU 20 SEPTEMBRE 2026
-- =====================================================================
-- OBJET DU LOT. Le navigateur ne choisit plus l'identite institutionnelle sous
-- laquelle il ecrit : il demande un envoi, le serveur verifie l'autorite puis
-- ecrit lui-meme (mail_systeme_envoyer). Autour de cette porte, quatre passes
-- successives ont elargi la notion de « destinataire impose par la base » —
-- titulaire du poste, conjoint, destinataire d'une caisse de fret — afin que la
-- fermeture de la tolerance transitoire ne rende pas invisibles des demandes que
-- les joueurs deposent deja.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES (toutes du 20/09/2026) :
--   20260920091147  mails_rpc_systeme_et_transition
--   20260920102935  mails_accuse_vers_titulaire
--   20260920103021  mails_accuse_vers_conjoint
--   20260920103309  mails_accuse_vers_destinataire_fret
--
-- AVERTISSEMENT — ETAT FINAL, PAS HISTORIQUE. Ce fichier reproduit ce qui EST en
-- production au soir du 20/09/2026, pas la suite des gestes qui y ont mene. En
-- particulier, mail_expediteur_autorise_strict a ete redefinie QUATRE fois dans
-- la journee, chaque passe elargissant les destinataires autorises : seule la
-- DERNIERE definition figure ici. Rejouer ce fichier sur une base neuve donne le
-- meme etat que la production ; il ne rejoue pas les trois versions
-- intermediaires, qui n'ont plus d'existence.
--
-- DEPENDANCES. Aucun fichier *.sql du depot ne cree les objets prerequis : ils
-- viennent de migrations de production non encore exportees dans le depot. Doivent
-- etre en place AVANT ce fichier :
--   * table public.mails                      (socle historique)
--   * table public.mails_expediteurs_systeme et public.mails_envois_systeme
--       -> 20260919224828 mails_confidentialite_lot1,
--          puis 20260919225357 mails_expediteurs_prefixes (colonne est_prefixe),
--          puis 20260919232628 mails_expediteurs_autorite (postes, autorise_soi, libre)
--   * table public.personnages_donnees, public.mariages, public.caisses_fret
--   * fonctions public.mon_personnage(), public.est_appel_serveur(),
--     public.acteur_poste_courant()
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. LA TOLERANCE TRANSITOIRE, NOMMEE ET REVERSIBLE D'UNE LIGNE
-- ---------------------------------------------------------------------
-- Commentaire d'origine (20260920091147) :
--
-- LA FENETRE, CONSTATEE FACTUELLEMENT. Le bundle servi en production insere les
-- mails EN DIRECT (sbInsert('mails')). La policy posee au lot precedent exige un
-- poste pour 13 identites institutionnelles : les parcours correspondants du
-- client deploye echoueraient. C'est une vraie incompatibilite, et la laisser
-- ouverte en s'appuyant sur « aucun PJ n'a de poste aujourd'hui » n'est pas une
-- garantie.
--
-- DEUX PIECES, POSEES ENSEMBLE :
--
-- 1. LA PORTE DEFINITIVE — mail_systeme_envoyer(). Le navigateur ne choisit plus
--    son identite : il demande un envoi, le serveur verifie l'autorite puis
--    ecrit. C'est cette RPC que le client migre utilisera.
--
-- 2. UNE TOLERANCE TRANSITOIRE, NOMMEE, JOURNALISEE ET REVERSIBLE D'UNE LIGNE.
--    Tant qu'elle est active, un envoi direct sous une identite DECLAREE reste
--    accepte -- mais il est enregistre dans mails_envois_systeme avec son
--    veritable auteur. Ce n'est pas un fail-open generique : une identite
--    INVENTEE reste refusee, et une identite reservee a « soi » ne peut toujours
--    pas viser un tiers. Au push :
--        UPDATE public.rp_transitions SET actif = false
--         WHERE cle = 'mails_expediteurs_tolerance';
--    et le durcissement complet prend effet, sans migration ni redeploiement.

CREATE TABLE IF NOT EXISTS public.rp_transitions (
  cle        text PRIMARY KEY,
  actif      boolean NOT NULL DEFAULT true,
  note       text,
  pose_le    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.rp_transitions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rp_transitions FROM PUBLIC, anon, authenticated;
-- Aucune policy : RLS active sans policy = table fermee a anon/authenticated.
-- Seuls postgres et service_role y accedent (ACL constatee en production).

-- ETAT FINAL DE LA LIGNE, pas son etat a la pose. La migration d'origine posait
-- actif = true avec la note « A DESACTIVER AU PUSH » ; la tolerance a ete FERMEE
-- le 20/09/2026 par l'UPDATE annonce ci-dessus, execute hors migration. C'est cet
-- etat ferme, et sa note reecrite, qui sont en base aujourd'hui.
INSERT INTO public.rp_transitions (cle, actif, note) VALUES ('mails_expediteurs_tolerance', 'f', 'FERMEE le 20/09/2026 (§5). Le controle strict fait foi : identite libre, ou titulaire du poste, ou saisine a destinataire impose par la base (titulaire / conjoint / destinataire de fret). Tout refus est desormais journalise dans mails_envois_systeme via mail_systeme_envoyer (voir sbSendMail).') ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.rp_transition_active(p_cle text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT t.actif FROM public.rp_transitions t WHERE t.cle = p_cle), false);
$function$;
REVOKE ALL ON FUNCTION public.rp_transition_active(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rp_transition_active(text) TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- 2. LES TROIS DRAPEAUX DE SAISINE SUR LE MIROIR DES EXPEDITEURS
-- ---------------------------------------------------------------------
-- Commentaires d'origine (20260920102935 / 103021 / 103309), resumes :
--
-- §5 : FERMER LA TOLERANCE SANS CASSER L'ACCUSE DE RECEPTION.
-- CE QUE LA MESURE A MONTRE. 34 envois clients utilisent une identite
-- institutionnelle DECLAREE mais non libre. La majorite est emise par le
-- titulaire lui-meme (un ministre qui repond sous l'en-tete de son ministere) et
-- passe deja le controle strict. Mais un groupe entier ne passe pas, et il a
-- toujours la meme forme :
--
--   un CITOYEN depose une demande, et l'institution en avise SON TITULAIRE.
--     - permis de construire      -> « Services municipaux » au Maire
--     - logement social Montrouge -> « Services municipaux » au Maire Adjoint
--     - naturalisation            -> « Service de l'Immigration » au Min. Interieur
--
-- LA REGLE AJOUTEE est le pendant exact d'autorise_soi : autorise_soi dit « vous
-- ne pouvez ecrire sous cette identite qu'a VOUS-MEME » ; autorise_vers_titulaire
-- dit « ... qu'au TITULAIRE ACTUEL de cette institution ».
--
-- L'officialisation d'un mariage envoie au conjoint un avis sous l'en-tete
-- « Mairie ». L'emetteur est un citoyen ordinaire, mais l'union LAISSE UNE TRACE
-- (table mariages), donc le lien est verifiable cote serveur.
--
-- expedierCaisseFret() avise le DESTINATAIRE d'une caisse sous l'en-tete
-- « Administration Portuaire ». Le lien est inscrit en base avant l'envoi : la
-- ligne caisses_fret porte le leader (l'expediteur) et le destinataire. On exclut
-- volontairement les caisses deja arrivees : l'avis accompagne une expedition en
-- cours, il ne doit pas rester un droit d'ecriture permanent.

ALTER TABLE public.mails_expediteurs_systeme
  ADD COLUMN IF NOT EXISTS autorise_vers_titulaire boolean NOT NULL DEFAULT false;

ALTER TABLE public.mails_expediteurs_systeme
  ADD COLUMN IF NOT EXISTS autorise_vers_conjoint boolean NOT NULL DEFAULT false;

ALTER TABLE public.mails_expediteurs_systeme
  ADD COLUMN IF NOT EXISTS autorise_vers_destinataire_fret boolean NOT NULL DEFAULT false;


-- ---------------------------------------------------------------------
-- 3. LES TROIS VERIFICATEURS DE LIEN
-- ---------------------------------------------------------------------

-- Titulaire courant d'un poste : un PJ dont la fiche porte ce poste. La fiche est
-- deja attestee par trg_personnages_attester_poste, donc « poste » n'est plus
-- auto-declare depuis le chantier des postes.
CREATE OR REPLACE FUNCTION public.mail_destinataire_est_titulaire(p_destinataire text, p_postes text[])
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.name = p_destinataire
       AND d.poste ->> 'id' = ANY (p_postes)
  );
$function$;
REVOKE ALL ON FUNCTION public.mail_destinataire_est_titulaire(text, text[]) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_titulaire(text, text[]) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.mail_destinataire_est_conjoint(p_moi text, p_destinataire text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.mariages m
     WHERE coalesce(m.statut, 'actif') <> 'dissous'
       AND m.dissous_at IS NULL
       AND ((m.conjoint1 = p_moi AND m.conjoint2 = p_destinataire)
         OR (m.conjoint2 = p_moi AND m.conjoint1 = p_destinataire))
  );
$function$;
REVOKE ALL ON FUNCTION public.mail_destinataire_est_conjoint(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_conjoint(text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.mail_destinataire_est_fret(p_moi text, p_destinataire text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.caisses_fret f
     WHERE f.leader = p_moi
       AND f.destinataire = p_destinataire
       AND f.date_arrivee_reelle IS NULL
  );
$function$;
REVOKE ALL ON FUNCTION public.mail_destinataire_est_fret(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_fret(text, text) TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- 4. LE VERDICT STRICT — DEFINITION FINALE, LA SEULE EN PRODUCTION
-- ---------------------------------------------------------------------
-- Redefinie quatre fois le 20/09 (091147, 102935, 103021, 103309). Seule cette
-- quatrieme et derniere version existe en base ; les trois precedentes ne sont
-- pas reproduites ici.
CREATE OR REPLACE FUNCTION public.mail_expediteur_autorise_strict(p_nom text, p_destinataire text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_moi text;
BEGIN
  SELECT * INTO r FROM public.mails_expediteurs_systeme m
   WHERE (NOT m.est_prefixe AND m.expediteur = p_nom)
      OR (m.est_prefixe AND p_nom LIKE m.expediteur || '%')
   ORDER BY m.est_prefixe LIMIT 1;
  IF NOT FOUND THEN RETURN false; END IF;     -- identite inventee : jamais
  IF r.libre THEN RETURN true; END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;

  -- 1. A moi-meme.
  IF r.autorise_soi AND p_destinataire = v_moi THEN RETURN true; END IF;

  -- 2. Je detiens le poste : l'identite est la mienne, sans restriction.
  IF array_length(r.postes, 1) IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                  WHERE a.poste_id = ANY (r.postes)) THEN
    RETURN true;
  END IF;

  -- 3..5. SAISINE : le destinataire est impose par un lien verifiable en base.
  --       Dans les trois cas, l'identite institutionnelle ne permet JAMAIS
  --       d'atteindre un tiers librement choisi.
  IF r.autorise_vers_titulaire
     AND array_length(r.postes, 1) IS NOT NULL
     AND public.mail_destinataire_est_titulaire(p_destinataire, r.postes) THEN
    RETURN true;
  END IF;

  IF r.autorise_vers_conjoint
     AND public.mail_destinataire_est_conjoint(v_moi, p_destinataire) THEN
    RETURN true;
  END IF;

  IF r.autorise_vers_destinataire_fret
     AND public.mail_destinataire_est_fret(v_moi, p_destinataire) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$function$;
REVOKE ALL ON FUNCTION public.mail_expediteur_autorise_strict(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise_strict(text, text) TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- 5. LE VERDICT UTILISE PAR LA POLICY : strict + tolerance transitoire
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mail_expediteur_autorise(p_nom text, p_destinataire text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record;
BEGIN
  IF public.mail_expediteur_autorise_strict(p_nom, p_destinataire) THEN RETURN true; END IF;

  IF public.rp_transition_active('mails_expediteurs_tolerance') THEN
    SELECT * INTO r FROM public.mails_expediteurs_systeme m
     WHERE (NOT m.est_prefixe AND m.expediteur = p_nom)
        OR (m.est_prefixe AND p_nom LIKE m.expediteur || '%')
     ORDER BY m.est_prefixe LIMIT 1;
    -- Une identite DECLAREE reste acceptee le temps de la transition.
    -- Une identite inventee, jamais.
    IF FOUND THEN RETURN true; END IF;
  END IF;

  RETURN false;
END;
$function$;
-- Droits constates en production (poses par 20260919232628, conserves par le
-- CREATE OR REPLACE ; repetes ici pour qu'un rejeu a neuf aboutisse au meme etat).
REVOKE ALL ON FUNCTION public.mail_expediteur_autorise(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise(text, text) TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- 6. LA PORTE DEFINITIVE : le navigateur demande, le serveur decide et ecrit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mail_systeme_envoyer(p_expediteur text, p_destinataire text, p_sujet text, p_corps text, p_heure text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(p_expediteur),'') = '' OR coalesce(btrim(p_destinataire),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF NOT public.est_appel_serveur()
     AND NOT public.mail_expediteur_autorise_strict(p_expediteur, p_destinataire) THEN
    INSERT INTO public.mails_envois_systeme (auteur_reel, expediteur, destinataire, sujet)
    VALUES (v_moi, p_expediteur, p_destinataire, left(coalesce(p_sujet,''),200));
    RETURN jsonb_build_object('ok', false, 'raison', 'expediteur_non_autorise');
  END IF;

  v_id := 'mail-' || (extract(epoch from clock_timestamp())*1000)::bigint
                  || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
  VALUES (v_id, p_expediteur, p_destinataire, p_sujet, p_corps,
          coalesce(p_heure, to_char(now() AT TIME ZONE 'Europe/Paris', 'HH24') || 'h'), false);
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.mail_systeme_envoyer(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mail_systeme_envoyer(text, text, text, text, text) TO authenticated, service_role;


-- =====================================================================
-- REPARATION PONCTUELLE DES DONNEES DU 20 SEPTEMBRE
-- =====================================================================
-- Ces UPDATE portent sur des lignes METIER deja presentes (le miroir des
-- expediteurs systeme vient de 20260919224828 et 20260919232628). Ils ne sont pas
-- derivables du schema : recopies verbatim depuis les migrations d'origine.

-- 20260920102935
UPDATE public.mails_expediteurs_systeme
   SET autorise_vers_titulaire = true
 WHERE expediteur IN ('Services municipaux', 'Service de l''Immigration');

-- 20260920103021
UPDATE public.mails_expediteurs_systeme
   SET autorise_vers_conjoint = true
 WHERE expediteur = 'Mairie';

-- 20260920103309
UPDATE public.mails_expediteurs_systeme
   SET autorise_vers_destinataire_fret = true
 WHERE expediteur = 'Administration Portuaire';

-- CONSTATE EN PRODUCTION, POSE HORS MIGRATION. « Prefecture » porte elle aussi
-- autorise_vers_titulaire = true en base au 20/09/2026, alors qu'aucune des
-- quatre migrations absorbees ne la nomme. La ligne est reproduite ici pour que
-- le rejeu aboutisse a l'etat reel, et signalee comme telle plutot que fondue
-- dans l'UPDATE d'origine.
UPDATE public.mails_expediteurs_systeme
   SET autorise_vers_titulaire = true
 WHERE expediteur = 'Préfecture';

-- Etat final attendu du miroir apres ce fichier (verifie le 20/09/2026) :
--   Administration Portuaire   fret
--   Mairie                     conjoint
--   Préfecture                 titulaire (+ autorise_soi)
--   Service de l'Immigration   titulaire (+ autorise_soi)
--   Services municipaux        titulaire
