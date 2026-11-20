-- Carrières « Enfant / Adolescent » et « Sans expérience professionnelle » ; personnages MINEURS (décisions de Fred du
-- 20/11/2026). GAME-DESIGN-CREATION-PERSONNAGES.md.
--  • personnages_donnees.est_mineur : posé à la création (carrière 'minor'), PERMANENT : ni le joueur ni une fonction
--    serveur ne peut le changer ; la carrière d'un mineur est figée, et personne ne devient mineur après coup.
--  • Aucune autre carrière pour un mineur : ni seconde carrière, ni cursus universitaire (donc ni stage).
--  • Contrôle commun mineur_refus_interne(acteur, cibles, motif) : NULL si permis, sinon un refus NEUTRE
--    ('action_non_disponible'), le même que le mineur soit l'acteur ou la cible. Branché sur : escorts (agence, standard
--    des résidences et cliniques, accompagnatrice sociale, intimité, débauchage), rencontre piège (kompromat intime),
--    alcool (bar, buvette, tournées, dîners, service d'étage, mini-bar, trinquer, achats en commerce, consommation),
--    drogue (dealers, GHB du marché noir, consommation).
--  • pnj_contexte_public signale mineur:true au dialogue des PNJ (aucune séduction, ni alcool ni drogue proposés).
--  • Signalement de messages (courrier, forum, conversations) : message_signaler ; file MJ admin_signalements_lire,
--    les signalements impliquant un mineur (auteur ou destinataire) en tête, marqués « mineur ».
-- Idempotente (raccords marqués mineurs_v1).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- 1. La marque permanente
ALTER TABLE public.personnages_donnees ADD COLUMN IF NOT EXISTS est_mineur boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.personnages_mineur_verrou_trg()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.est_mineur := coalesce(NEW.career, '') = 'minor';
    RETURN NEW;
  END IF;
  NEW.est_mineur := OLD.est_mineur;                      -- permanent, dans les deux sens
  IF OLD.est_mineur THEN NEW.career := OLD.career;       -- un mineur garde sa carrière unique
  ELSIF coalesce(NEW.career, '') = 'minor' AND coalesce(OLD.career, '') <> 'minor' THEN NEW.career := OLD.career;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS personnages_mineur_verrou ON public.personnages_donnees;
CREATE TRIGGER personnages_mineur_verrou BEFORE INSERT OR UPDATE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_mineur_verrou_trg();

CREATE OR REPLACE FUNCTION public.personnage_est_mineur(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT d.est_mineur FROM public.personnages_donnees d WHERE d.name = p_nom), false);
$$;

-- 2. Le contrôle commun. Neutre : le refus ne dit pas qui est mineur.
CREATE OR REPLACE FUNCTION public.mineur_refus_interne(p_acteur text, p_cibles text[] DEFAULT NULL, p_motif text DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN public.personnage_est_mineur(p_acteur)
                OR EXISTS (SELECT 1 FROM unnest(coalesce(p_cibles, '{}'::text[])) c WHERE public.personnage_est_mineur(c))
    THEN jsonb_build_object('ok', false, 'raison', 'action_non_disponible', 'motif', p_motif,
                            'message', 'Cette action n''est pas disponible.')
  END;
$$;
REVOKE ALL ON FUNCTION public.mineur_refus_interne(text, text[], text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.personnage_est_mineur(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.personnages_mineur_verrou_trg() FROM PUBLIC, anon, authenticated;

-- 3. Aucune autre carrière pour un mineur
CREATE OR REPLACE FUNCTION public.mineur_sans_autre_carriere_trg()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF public.personnage_est_mineur(NEW.personnage) THEN
    RAISE EXCEPTION 'personnage_mineur_carriere_unique' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.mineur_sans_autre_carriere_trg() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS mineur_sans_autre_carriere ON public.carrieres_acquises;
CREATE TRIGGER mineur_sans_autre_carriere BEFORE INSERT OR UPDATE ON public.carrieres_acquises
  FOR EACH ROW EXECUTE FUNCTION public.mineur_sans_autre_carriere_trg();
DROP TRIGGER IF EXISTS mineur_sans_autre_carriere ON public.universite_inscriptions;
CREATE TRIGGER mineur_sans_autre_carriere BEFORE INSERT ON public.universite_inscriptions
  FOR EACH ROW EXECUTE FUNCTION public.mineur_sans_autre_carriere_trg();

SELECT pg_temp.rp_raccorder('public.universite_inscrire(text,text)'::regprocedure,
  $a$  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.personnage_est_mineur(v_moi) THEN /* mineurs_v1 */
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_mineur_carriere_unique'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.mes_carrieres()'::regprocedure,
  $a$NOT EXISTS (SELECT 1 FROM public.carrieres_acquises a WHERE a.personnage = v_moi),$a$,
  $b$NOT EXISTS (SELECT 1 FROM public.carrieres_acquises a WHERE a.personnage = v_moi)
        AND NOT public.personnage_est_mineur(v_moi) /* mineurs_v1 */,
    'mineur', public.personnage_est_mineur(v_moi),$b$, 'mineurs_v1');

-- 4. Escorts et rencontre piège
SELECT pg_temp.rp_raccorder('public.escort_recruter(text)'::regprocedure,
  $a$    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.mineur_refus_interne(v_moi, NULL, 'escort') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(v_moi, NULL, 'escort'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.escort_sociale_choisir(text)'::regprocedure,
  $a$    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.mineur_refus_interne(v_moi, NULL, 'escort') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(v_moi, NULL, 'escort'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder(f::regprocedure,
  $a$  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.mineur_refus_interne(moi, NULL, 'escort') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(moi, NULL, 'escort'); END IF;$b$, 'mineurs_v1')
  FROM unnest(ARRAY['public.escort_standard_devis(text)', 'public.escort_standard_valider(uuid,integer,integer)',
                    'public.escort_intimite(uuid,text,integer)']) f;
SELECT pg_temp.rp_raccorder('public.pnj_debaucher(text,text,text,integer,integer)'::regprocedure,
  $a$  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_job = 'escort' AND public.mineur_refus_interne(v_moi, NULL, 'escort') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(v_moi, NULL, 'escort'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.pnj_employe_debaucher(text,text,text)'::regprocedure,
  $a$  v_moi := public.mon_personnage();$a$,
  $b$  v_moi := public.mon_personnage();
  IF p_job = 'escort' AND public.mineur_refus_interne(v_moi, NULL, 'escort') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(v_moi, NULL, 'escort'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.escort_piege_tenter(uuid,text,integer,integer)'::regprocedure,
  $a$  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.mineur_refus_interne(a.name, ARRAY[p_cible], 'kompromat_intime') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(a.name, ARRAY[p_cible], 'kompromat_intime'); END IF;$b$, 'mineurs_v1');

-- 5. Drogue
SELECT pg_temp.rp_raccorder('public.dealer_acheter(uuid,text)'::regprocedure,
  $a$  IF auth.uid() IS NULL OR acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;$a$,
  $b$  IF auth.uid() IS NULL OR acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF public.mineur_refus_interne(acteur, NULL, 'drogue') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(acteur, NULL, 'drogue'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.objet_acheter(text,text,integer,integer)'::regprocedure,
  $a$  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_ordre = 'acheter_ghb' AND public.mineur_refus_interne(v_moi, NULL, 'drogue') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(v_moi, NULL, 'drogue'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$ v_boisson:=CASE WHEN v_aliment THEN NULL ELSE public.boisson_objet_interne(v_item) END; -- maladies_boissons_gate$a$,
  $b$ v_boisson:=CASE WHEN v_aliment THEN NULL ELSE public.boisson_objet_interne(v_item) END; -- maladies_boissons_gate
 IF (v_boisson = 'alcoolisee' OR coalesce(v_item->>'type','') = 'drogue') /* mineurs_v1 */
    AND public.mineur_refus_interne(p_acteur, NULL, 'consommation') IS NOT NULL THEN
   RETURN public.mineur_refus_interne(p_acteur, NULL, 'consommation'); END IF;$b$, 'mineurs_v1');

-- 6. Alcool
SELECT pg_temp.rp_raccorder('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure,
  $a$ IF v_ref IS NULL OR coalesce(v_ref->>'recette_id','')='' THEN RETURN jsonb_build_object('ok',false,'raison','recette_absente'); END IF;$a$,
  $b$ IF v_ref IS NULL OR coalesce(v_ref->>'recette_id','')='' THEN RETURN jsonb_build_object('ok',false,'raison','recette_absente'); END IF;
 IF public.boisson_alcoolisee_interne(v_ref->>'recette_id') AND public.mineur_refus_interne(p_acheteur, NULL, 'alcool') IS NOT NULL THEN /* mineurs_v1 */
   RETURN public.mineur_refus_interne(p_acheteur, NULL, 'alcool'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.acheter_produit_commerce_interne(text,text,text,text,integer)'::regprocedure,
  $a$  IF COALESCE(v_ref->>'recette_id','') <> '' THEN$a$,
  $b$  IF public.boisson_alcoolisee_interne(v_ref->>'recette_id') AND public.mineur_refus_interne(p_acheteur, NULL, 'alcool') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(p_acheteur, NULL, 'alcool'); END IF;
  IF COALESCE(v_ref->>'recette_id','') <> '' THEN$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure,
  $a$  CASE p_ordre
  WHEN 'commanditer_sondage' THEN$a$,
  $b$  IF p_ordre = 'consommer_buvette' AND public.mineur_refus_interne(a.name, NULL, 'alcool') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(a.name, NULL, 'alcool'); END IF;
  CASE p_ordre
  WHEN 'commanditer_sondage' THEN$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.tournee_creer(text,text,text,text[])'::regprocedure,
  $a$ IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;$a$,
  $b$ IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF public.boisson_alcoolisee_interne(p_recette) AND public.mineur_refus_interne(v_moi, p_invites, 'alcool') IS NOT NULL THEN /* mineurs_v1 */
  RETURN public.mineur_refus_interne(v_moi, p_invites, 'alcool'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.tournee_repondre(bigint,boolean)'::regprocedure,
  $a$ IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;$a$,
  $b$ IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_accepte AND public.boisson_alcoolisee_interne((SELECT t2.recette_id FROM public.tournees t2 JOIN public.invitations_diner i2 ON i2.tournee_id = t2.id WHERE i2.id = p_invitation))
    AND public.mineur_refus_interne(v_moi, NULL, 'alcool') IS NOT NULL THEN /* mineurs_v1 */
  RETURN public.mineur_refus_interne(v_moi, NULL, 'alcool'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.restaurant_diner_servir(bigint)'::regprocedure,
  $a$ IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;$a$,
  $b$ IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;
 IF public.mineur_refus_interne(moi, ARRAY(SELECT x.invite FROM public.invitations_diner x WHERE x.id = p_invitation AND NOT coalesce(x.invite_pnj, false)), 'alcool') IS NOT NULL THEN /* mineurs_v1 */
  RETURN public.mineur_refus_interne(moi, ARRAY(SELECT x.invite FROM public.invitations_diner x WHERE x.id = p_invitation AND NOT coalesce(x.invite_pnj, false)), 'alcool'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.diner_commerce_servir_interne(text,bigint)'::regprocedure,
  $a$ cfg:=public.diner_commerce_lieu_interne(i.country,i.city,i.building_id,i.room_id);$a$,
  $b$ cfg:=public.diner_commerce_lieu_interne(i.country,i.city,i.building_id,i.room_id);
 IF public.boisson_alcoolisee_interne(cfg->>'boisson') /* mineurs_v1 */
    AND public.mineur_refus_interne(moi, CASE WHEN coalesce(i.invite_pnj, false) THEN NULL ELSE ARRAY[i.invite] END, 'alcool') IS NOT NULL THEN
  RETURN public.mineur_refus_interne(moi, CASE WHEN coalesce(i.invite_pnj, false) THEN NULL ELSE ARRAY[i.invite] END, 'alcool'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.service_etage_commander(uuid,text)'::regprocedure,
  $a$  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.boisson_alcoolisee_interne(p_produit) AND public.mineur_refus_interne(moi, NULL, 'alcool') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(moi, NULL, 'alcool'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.residence_acte(uuid,text,text)'::regprocedure,
  $a$  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_action IN ('minibar_prendre', 'minibar_remplir') AND public.mineur_refus_interne(a, NULL, 'alcool') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(a, NULL, 'alcool'); END IF;$b$, 'mineurs_v1');
SELECT pg_temp.rp_raccorder('public.sovarka_maison_agir(text,text)'::regprocedure,
  $a$  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;$a$,
  $b$  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_action = 'trinquer' AND public.mineur_refus_interne(a, NULL, 'alcool') IS NOT NULL THEN /* mineurs_v1 */
    RETURN public.mineur_refus_interne(a, NULL, 'alcool'); END IF;$b$, 'mineurs_v1');

-- 7. Dialogue des PNJ : le fait « mineur » est transmis (arbitrage de Fred du 20/11/2026)
SELECT pg_temp.rp_raccorder('public.pnj_contexte_public()'::regprocedure,
  $a$  RETURN jsonb_build_object('ok', true, 'nom', v_moi, 'fonctions', v_fonctions, 'genre', v_genre);$a$,
  $b$  RETURN jsonb_build_object('ok', true, 'nom', v_moi, 'fonctions', v_fonctions, 'genre', v_genre)
    || CASE WHEN public.personnage_est_mineur(v_moi) THEN jsonb_build_object('mineur', true) ELSE '{}'::jsonb END; /* mineurs_v1 */$b$,
  'mineurs_v1');

-- 8. Signalement des messages
CREATE TABLE IF NOT EXISTS public.signalements_messages (
  id bigserial PRIMARY KEY,
  source text NOT NULL CHECK (source IN ('courrier', 'forum', 'conversation')),
  message_id text NOT NULL,
  signale_par text NOT NULL,
  motif text NOT NULL CHECK (length(motif) BETWEEN 1 AND 500),
  auteur text,
  destinataires text[] NOT NULL DEFAULT '{}',
  mineur boolean NOT NULL DEFAULT false,
  extrait text,
  statut text NOT NULL DEFAULT 'ouvert' CHECK (statut IN ('ouvert', 'traite', 'rejete')),
  cree_le timestamptz NOT NULL DEFAULT now(),
  traite_le timestamptz,
  traite_par uuid,
  UNIQUE (source, message_id, signale_par)
);
ALTER TABLE public.signalements_messages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.signalements_messages FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.message_signaler(p_source text, p_message_id text, p_motif text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); v_auteur text; v_dest text[] := '{}'; v_extrait text; v_conv text; v_salon boolean;
  v_motif text := btrim(regexp_replace(coalesce(p_motif, ''), '\s+', ' ', 'g')); v_id bigint; v_mineur boolean;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_motif = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'motif_requis'); END IF;
  v_motif := left(v_motif, 500);
  IF p_source = 'courrier' THEN
    SELECT coalesce(nullif(m.from_real, ''), m.from_player), ARRAY[m.to_player], left(m.subject || ' — ' || m.body, 2000)
      INTO v_auteur, v_dest, v_extrait
      FROM public.mails m WHERE m.id::text = p_message_id AND v_moi IN (m.to_player, m.from_player, m.from_real);
  ELSIF p_source = 'forum' THEN
    SELECT coalesce(nullif(p.author_real, ''), p.author), '{}'::text[], left(p.content, 2000)
      INTO v_auteur, v_dest, v_extrait
      FROM public.forum_posts p WHERE p.id::text = p_message_id;
  ELSIF p_source = 'conversation' THEN
    SELECT c.auteur, c.conversation_id, coalesce(c.salon, false), left(c.message, 2000)
      INTO v_auteur, v_conv, v_salon, v_extrait FROM public.messages_chat c WHERE c.id::text = p_message_id;
    IF v_conv IS NOT NULL THEN
      v_dest := CASE WHEN v_salon THEN ARRAY(SELECT s.membre FROM public.salons_membres s WHERE s.salon_id::text = v_conv)
                     ELSE string_to_array(v_conv, '__') END;
      IF NOT v_moi = ANY (v_dest) AND v_moi IS DISTINCT FROM v_auteur THEN v_auteur := NULL; v_extrait := NULL; END IF;
      v_dest := array_remove(v_dest, v_auteur);
    END IF;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'source_inconnue');
  END IF;
  IF v_auteur IS NULL AND v_extrait IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_introuvable'); END IF;
  v_mineur := public.personnage_est_mineur(v_auteur)
           OR EXISTS (SELECT 1 FROM unnest(v_dest) d WHERE public.personnage_est_mineur(d));
  INSERT INTO public.signalements_messages (source, message_id, signale_par, motif, auteur, destinataires, mineur, extrait)
  VALUES (p_source, p_message_id, v_moi, v_motif, v_auteur, coalesce(v_dest, '{}'), v_mineur, v_extrait)
  ON CONFLICT (source, message_id, signale_par) DO NOTHING RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'deja', v_id IS NULL);
END $$;
REVOKE ALL ON FUNCTION public.message_signaler(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.message_signaler(text, text, text) TO authenticated;

-- File du MJ : ouverts d'abord, impliquant un mineur en tête, puis les plus anciens.
CREATE OR REPLACE FUNCTION public.admin_signalements_lire(p_tous boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true, 'signalements', coalesce((
    SELECT jsonb_agg(to_jsonb(s) ORDER BY (s.statut = 'ouvert') DESC, s.mineur DESC, s.cree_le ASC)
      FROM public.signalements_messages s WHERE p_tous OR s.statut = 'ouvert'), '[]'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION public.admin_signalement_traiter(p_id bigint, p_statut text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid := public.admin_exiger();
BEGIN
  IF p_statut NOT IN ('traite', 'rejete', 'ouvert') THEN RETURN jsonb_build_object('ok', false, 'raison', 'statut_inconnu'); END IF;
  UPDATE public.signalements_messages SET statut = p_statut,
         traite_le = CASE WHEN p_statut = 'ouvert' THEN NULL ELSE now() END,
         traite_par = CASE WHEN p_statut = 'ouvert' THEN NULL ELSE v_uid END
   WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'signalement_introuvable'); END IF;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE ALL ON FUNCTION public.admin_signalements_lire(boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_signalement_traiter(bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_signalements_lire(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_signalement_traiter(bigint, text) TO authenticated;

COMMIT;
