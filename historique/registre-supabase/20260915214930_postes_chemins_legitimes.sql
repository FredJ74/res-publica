-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915214930
-- Nom original      : postes_chemins_legitimes
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-15 21:49:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c65617b6b90b56dfabb852f6695ec13f
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
-- AUTORITE DES POSTES — LES CHEMINS LEGITIMES, RACCORDES AU SERVEUR.
--
-- Le verrou pose au lot precedent rend inoperante la seule voie par laquelle un PJ obtenait
-- jusqu'ici un poste NOMME : accepterNominationPosteNomme ecrivait state.poste sur sa propre
-- fiche. Il faut donc rendre cette voie au serveur, sinon les postes nommes deviendraient
-- inaccessibles. Les postes ELUS, eux, n'ont besoin de rien : le depouillement est deja ecrit par
-- le cron dans cycles_electoraux, et le pont client reconcilierPosteElu continue de fonctionner
-- puisque le trigger atteste sa valeur.
--
-- LE GAME DESIGN N'EST PAS TOUCHE. On reprend exactement les regles deja ecrites dans le jeu :
-- qui nomme quoi (POSTES_NOMMES_EXCLUSIFS, miroir postes_nommes_regles), la competence de ville
-- pour les postes de scope 'ville', la protection de 3 jours du titulaire fraichement nomme
-- (DUREE_PROTECTION_POSTE_NOMME_MS), et la priorite d'un PJ candidat lorsque l'autorite est
-- tenue par un PNJ. Rien n'est invente ici.

-- Nominations en attente d'acceptation. La table n'existait pas : le jeu convoyait la nomination
-- par un simple bouton dans un mail, ce qu'aucun serveur ne peut verifier. Le mail reste la
-- notification ; cette ligne en est desormais la preuve.
CREATE TABLE IF NOT EXISTS public.nominations_en_attente (
  id            text PRIMARY KEY,
  country       text NOT NULL,
  poste_id      text NOT NULL,
  city          text,
  destinataire  text NOT NULL,
  par           text NOT NULL,
  cree_le       timestamptz NOT NULL DEFAULT now(),
  traitee       boolean NOT NULL DEFAULT false
);
ALTER TABLE public.nominations_en_attente ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS nominations_attente_lecture ON public.nominations_en_attente;
CREATE POLICY nominations_attente_lecture ON public.nominations_en_attente
  FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.nominations_en_attente FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- Attribution effective. Interne : aucune regle d'autorisation ici, chaque RPC pose les siennes.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.poste_attribuer_interne(
  p_pays text, p_poste text, p_city text, p_titulaire text, p_source text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_id text := p_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  v_label text; v_ancien text;
BEGIN
  SELECT r.label INTO v_label FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF v_label IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;

  SELECT a.titulaire INTO v_ancien FROM public.postes_attribues a WHERE a.id = v_id;

  -- Le predecesseur perd la fonction : registre d'abord, miroir de fiche ensuite.
  IF v_ancien IS NOT NULL AND v_ancien IS DISTINCT FROM p_titulaire THEN
    UPDATE public.personnages_donnees SET poste = NULL
     WHERE name = v_ancien AND poste ->> 'id' = p_poste;
  END IF;

  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, depuis, source, updated_at)
  VALUES (v_id, p_pays, p_poste, p_city, p_titulaire, now(), p_source, now())
  ON CONFLICT (id) DO UPDATE
    SET titulaire = EXCLUDED.titulaire, depuis = now(),
        source = EXCLUDED.source, updated_at = now();

  -- Le PNJ qui tenait la fonction s'efface.
  DELETE FROM public.titulaires_pnj
   WHERE country = p_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city;

  -- Miroir d'affichage sur la fiche : atteste, donc accepte par le trigger.
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', p_poste, 'name', v_label, 'city', p_city,
                                    'nommeLe', (extract(epoch from now())*1000)::bigint)
   WHERE name = p_titulaire;

  RETURN jsonb_build_object('ok', true, 'poste', p_poste, 'city', p_city,
                            'titulaire', p_titulaire, 'predecesseur', v_ancien);
END;
$$;
REVOKE ALL ON FUNCTION public.poste_attribuer_interne(text,text,text,text,text)
  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- L'appelant detient-il l'autorite de nomination sur ce poste ? Renvoie son nom, ou NULL.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.poste_autorite_de(p_poste text, p_city text)
RETURNS TABLE (nom text, pays text, autorite text, scope text)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_pays text; v_poste jsonb; v_regle record;
BEGIN
  SELECT d.name, d.country, d.poste INTO v_nom, v_pays, v_poste
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN RETURN; END IF;

  SELECT * INTO v_regle FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF NOT FOUND OR v_regle.nomme_par IS NULL THEN RETURN; END IF;

  -- Le poste porte par la fiche est deja atteste (trigger) : on peut s'y fier.
  IF (v_poste ->> 'id') IS DISTINCT FROM v_regle.nomme_par THEN RETURN; END IF;
  -- Autorite de scope 'ville' : elle ne nomme que dans SA ville.
  IF v_regle.scope = 'ville' AND (v_poste ->> 'city') IS DISTINCT FROM p_city THEN RETURN; END IF;

  RETURN QUERY SELECT v_nom, v_pays, v_regle.nomme_par, v_regle.scope;
END;
$$;
REVOKE ALL ON FUNCTION public.poste_autorite_de(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_autorite_de(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- NOMINATION par l'autorite competente. Un PJ recoit une proposition a accepter ; un PNJ prend
-- la fonction immediatement, comme aujourd'hui.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.poste_nommer(p_poste text, p_city text, p_destinataire text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_pays text; v_scope text;
  v_est_pj boolean; v_id text; v_depuis timestamptz;
BEGIN
  SELECT a.nom, a.pays, a.scope INTO v_nom, v_pays, v_scope
    FROM public.poste_autorite_de(p_poste, p_city) a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_destinataire IS NULL OR btrim(p_destinataire) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_absent');
  END IF;

  -- Protection de 3 jours du titulaire fraichement nomme (regle de jeu existante).
  SELECT depuis INTO v_depuis FROM public.postes_attribues
   WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  IF v_depuis IS NOT NULL AND v_depuis > now() - interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_protege');
  END IF;

  v_est_pj := EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = p_destinataire);

  IF NOT v_est_pj THEN
    -- Destinataire PNJ : prise de fonction immediate, comme le fait le jeu aujourd'hui.
    UPDATE public.personnages_donnees SET poste = NULL
     WHERE name = (SELECT titulaire FROM public.postes_attribues
                    WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national'));
    DELETE FROM public.postes_attribues
     WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
    INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj, updated_at)
    VALUES (v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national'),
            v_pays, p_poste, p_city, p_destinataire, now())
    ON CONFLICT (id) DO UPDATE SET nom_pnj = EXCLUDED.nom_pnj, updated_at = now();
    RETURN jsonb_build_object('ok', true, 'decision', 'pnj_en_fonction', 'titulaire', p_destinataire);
  END IF;

  v_id := 'nom-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6);
  DELETE FROM public.nominations_en_attente
   WHERE country = v_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city
     AND traitee IS FALSE;
  INSERT INTO public.nominations_en_attente (id, country, poste_id, city, destinataire, par)
  VALUES (v_id, v_pays, p_poste, p_city, p_destinataire, v_nom);

  RETURN jsonb_build_object('ok', true, 'decision', 'proposition_envoyee',
                            'id', v_id, 'destinataire', p_destinataire);
END;
$$;
REVOKE ALL ON FUNCTION public.poste_nommer(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_nommer(text, text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- ACCEPTATION par le destinataire. C'est la ligne serveur qui fait foi, plus le bouton du mail.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.poste_accepter_nomination(p_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_nom text; v_pays text; v_n record;
BEGIN
  SELECT d.name, d.country INTO v_nom, v_pays
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO v_n FROM public.nominations_en_attente WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR v_n.traitee THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable');
  END IF;
  IF v_n.destinataire IS DISTINCT FROM v_nom OR v_n.country IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nomination_pas_pour_vous');
  END IF;

  UPDATE public.nominations_en_attente SET traitee = true WHERE id = p_id;
  RETURN public.poste_attribuer_interne(v_pays, v_n.poste_id, v_n.city, v_nom, 'nomination');
END;
$$;
REVOKE ALL ON FUNCTION public.poste_accepter_nomination(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_accepter_nomination(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- CANDIDATURE SPONTANEE quand l'autorite est tenue par un PNJ : priorite du PJ sur le vide,
-- regle de jeu existante (demanderNominationPoste). Si l'autorite est tenue par un PJ, on ne
-- decide rien a sa place : la candidature reste de son ressort.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.poste_postuler(p_poste text, p_city text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_nom text; v_pays text; v_regle record; v_depuis timestamptz; v_autorite_pj boolean;
BEGIN
  SELECT d.name, d.country INTO v_nom, v_pays
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO v_regle FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu'); END IF;

  SELECT depuis INTO v_depuis FROM public.postes_attribues
   WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  IF v_depuis IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_deja_occupe_par_un_joueur');
  END IF;

  -- L'autorite de nomination est-elle tenue par un joueur ?
  v_autorite_pj := EXISTS (
    SELECT 1 FROM public.postes_attribues a
     WHERE a.country = v_pays AND a.poste_id = v_regle.nomme_par
       AND (v_regle.scope = 'pays' OR a.city IS NOT DISTINCT FROM p_city))
   OR EXISTS (
    SELECT 1 FROM public.cycles_electoraux c
     WHERE c.country = v_pays AND c.poste_id = v_regle.nomme_par
       AND left(btrim(c.data), 1) = '{' AND (c.data::jsonb ->> 'eluId') IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.personnages_donnees d
                    WHERE d.name = c.data::jsonb ->> 'eluId'));
  IF v_autorite_pj THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_joueur_doit_decider');
  END IF;

  RETURN public.poste_attribuer_interne(v_pays, p_poste, p_city, v_nom, 'candidature_autorite_pnj');
END;
$$;
REVOKE ALL ON FUNCTION public.poste_postuler(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_postuler(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- REVOCATION par l'autorite competente, et DEMISSION du titulaire.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.poste_revoquer(p_poste text, p_city text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_nom text; v_pays text; v_id text; v_titulaire text; v_depuis timestamptz;
BEGIN
  SELECT a.nom, a.pays INTO v_nom, v_pays FROM public.poste_autorite_de(p_poste, p_city) a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  v_id := v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  SELECT titulaire, depuis INTO v_titulaire, v_depuis FROM public.postes_attribues WHERE id = v_id;
  IF v_titulaire IS NULL THEN
    DELETE FROM public.titulaires_pnj
     WHERE country = v_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city;
    RETURN jsonb_build_object('ok', true, 'decision', 'pnj_revoque');
  END IF;
  IF v_depuis > now() - interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_protege');
  END IF;

  DELETE FROM public.postes_attribues WHERE id = v_id;
  UPDATE public.personnages_donnees SET poste = NULL
   WHERE name = v_titulaire AND poste ->> 'id' = p_poste;
  RETURN jsonb_build_object('ok', true, 'decision', 'revoque', 'ancien_titulaire', v_titulaire);
END;
$$;
REVOKE ALL ON FUNCTION public.poste_revoquer(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_revoquer(text, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.poste_quitter()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_nom text;
BEGIN
  SELECT d.name INTO v_nom FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  DELETE FROM public.postes_attribues WHERE titulaire = v_nom;
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = v_nom;
  RETURN jsonb_build_object('ok', true, 'decision', 'demission');
END;
$$;
REVOKE ALL ON FUNCTION public.poste_quitter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_quitter() TO authenticated, service_role;