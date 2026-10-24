-- APPLIQUEE le 24/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261024185323.
-- Eprouvee avant application en transaction annulee : 14 cas joueur PNJ + 4 cas ambassadeur joueur.
-- Droits verifies apres coup : aucune fonction pour anon ; table fermee a anon et authenticated.
-- Baseline NON reextrait (comme les autres migrations de ce repertoire) : a faire au prochain
-- passage de reextraction (WORKFLOW-SUPABASE.md, etape 5).
-- ============================================================================
-- AUDIENCES AUPRES DES AMBASSADEURS (24 octobre 2026, arbitrage de Fred)
-- ============================================================================
-- LE PARCOURS DECIDE PAR FRED :
--   1. Le joueur demande audience a l'accueil du Quartier des Ambassades : 1 PA, une seule
--      demande en cours par ambassade.
--   2. Il recoit aussitot un mail : la demande est transmise, reponse dans les plus brefs delais.
--   3a. Ambassadeur PNJ : le serveur tire a la demande un delai entre tout de suite et 3 jours.
--       Jamais de refus.
--   3b. Ambassadeur joueur (quand les autres empires seront codes) : il accorde quand il veut.
--   4. A l'accord, un mail « audience accordee » ; le bureau de cet ambassadeur s'ouvre pour ce
--      joueur seul pendant 48 heures.
--
-- UNE SEULE REALITE, CELLE DU SERVEUR (regle de Fred, meme jour). Le delai est tire ICI, a la
-- demande, et jamais revele au navigateur. L'acces au bureau est decide ICI. Le navigateur ne
-- fait qu'afficher ce que ces fonctions rendent.
--
-- L'ACCORD EST CONSTATE PAR LE SERVEUR, PAS PAR UNE HORLOGE DU NAVIGATEUR. Une demande dont
-- l'echeance est passee devient « accordee » au premier passage serveur qui la voit : la
-- prochaine action du joueur sur ses audiences, la verification de ses mails tant qu'il a une
-- demande en cours, ou la passe de nuit (api/cron-minuit.js) pour les joueurs absents. Les
-- 48 heures courent a partir de ce constat, qui est aussi l'heure du mail : le joueur n'est
-- jamais prive d'une partie de sa fenetre par une absence.
--
-- Idempotente : IF NOT EXISTS, CREATE OR REPLACE, DROP ... IF EXISTS. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ambassades_audiences (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  demandeur       text NOT NULL,
  pays_hote       text NOT NULL,
  empire          text NOT NULL CHECK (empire IN ('khalija','soviet','narco')),
  -- Le joueur ambassadeur en poste AU MOMENT de la demande ; NULL = l'ambassadeur PNJ recoit.
  ambassadeur_pj  text,
  statut          text NOT NULL DEFAULT 'demandee'
                  CHECK (statut IN ('demandee','accordee','expiree')),
  demandee_le     timestamptz NOT NULL DEFAULT now(),
  -- PNJ seulement : l'echeance tiree a la demande. Jamais renvoyee au navigateur.
  accord_prevu_le timestamptz,
  accordee_le     timestamptz,
  expire_le       timestamptz,
  CHECK (ambassadeur_pj IS NOT NULL OR accord_prevu_le IS NOT NULL),
  CHECK (statut = 'demandee' OR (accordee_le IS NOT NULL AND expire_le IS NOT NULL))
);

-- UNE DEMANDE EN COURS PAR AMBASSADE ET PAR JOUEUR : garantie par la base, pas par l'ecran.
CREATE UNIQUE INDEX IF NOT EXISTS ambassades_audiences_une_en_cours
  ON public.ambassades_audiences (demandeur, empire)
  WHERE statut IN ('demandee','accordee');
CREATE INDEX IF NOT EXISTS ambassades_audiences_echeances
  ON public.ambassades_audiences (statut, accord_prevu_le);

ALTER TABLE public.ambassades_audiences ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ambassades_audiences FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.ambassades_audiences IS
  'HG audiences ambassades v1 (24/10/2026) : lue et ecrite uniquement par les fonctions ambassade_*';

-- ---------------------------------------------------------------------------
-- Les trois ambassadeurs PNJ de Luthecia (arbitrage de Fred, 24/10/2026).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ambassade_identite(p_empire text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE p_empire
    WHEN 'soviet'  THEN jsonb_build_object('ambassadeur','Valery Antonov',      'ambassade','Ambassade de Sovarka')
    WHEN 'narco'   THEN jsonb_build_object('ambassadeur','Guillermo Vasquez',   'ambassade','Ambassade d''El Estado')
    WHEN 'khalija' THEN jsonb_build_object('ambassadeur','Mohamed Al-Mansoori', 'ambassade','Ambassade d''Al-Khalija')
  END;
$function$;

-- ---------------------------------------------------------------------------
-- LE CONSTAT DES ECHEANCES. Interne : jamais appelable depuis le navigateur.
-- p_demandeur NULL = tous les joueurs (passe de nuit).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ambassades_audiences_echoir(p_demandeur text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_id jsonb; v_n integer := 0;
BEGIN
  UPDATE public.ambassades_audiences SET statut = 'expiree'
   WHERE statut = 'accordee' AND expire_le <= now()
     AND (p_demandeur IS NULL OR demandeur = p_demandeur);

  FOR r IN SELECT * FROM public.ambassades_audiences
            WHERE statut = 'demandee' AND ambassadeur_pj IS NULL
              AND accord_prevu_le <= now()
              AND (p_demandeur IS NULL OR demandeur = p_demandeur)
            FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.ambassades_audiences
       SET statut = 'accordee', accordee_le = now(), expire_le = now() + interval '48 hours'
     WHERE id = r.id;
    v_id := public.ambassade_identite(r.empire);
    PERFORM public.mail_systeme_poser_interne(
      v_id ->> 'ambassade', r.demandeur, 'Audience accordée',
      'Son Excellence <strong>' || (v_id ->> 'ambassadeur') || '</strong> accepte de vous recevoir.<br><br>'
      || 'Présentez-vous à son bureau, au Quartier des Ambassades de Luthécia, dans les <strong>48 heures</strong>. '
      || 'Passé ce délai, l''audience sera caduque et il vous faudra en solliciter une nouvelle.<br><br>'
      || 'Le secrétariat de l''' || (v_id ->> 'ambassade'));
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END; $function$;
REVOKE ALL ON FUNCTION public.ambassades_audiences_echoir(text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- DEMANDER AUDIENCE. Le PA est preleve dans la meme transaction que l'enregistrement.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ambassade_demander_audience(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_batiment text; v_pj text; v_id uuid;
  v_paie jsonb; v_ident jsonb; v_statut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  v_ident := public.ambassade_identite(p_empire);
  IF v_ident IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  SELECT country, current_building INTO v_pays, v_batiment
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL OR v_pays = p_empire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ambassade_inconnue');
  END IF;
  IF v_batiment IS DISTINCT FROM 'quartier-ambassades' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  PERFORM public.ambassades_audiences_echoir(v_moi);

  SELECT statut INTO v_statut FROM public.ambassades_audiences
   WHERE demandeur = v_moi AND empire = p_empire AND statut IN ('demandee','accordee');
  IF v_statut = 'demandee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_en_cours');
  ELSIF v_statut = 'accordee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'audience_deja_accordee');
  END IF;

  -- L'ambassadeur joueur en poste ici, s'il y en a un (inexistant tant que les autres empires
  -- ne sont pas codes : la branche est prete, et c'est tout).
  SELECT nullif(btrim(coalesce(a.data ->> 'ambassadeur','')), '') INTO v_pj
    FROM public.ambassades_ouvertes a
   WHERE a.pays_hote = v_pays AND a.empire = p_empire;

  -- ENREGISTRER AVANT DE PAYER : l'index unique arbitre une course entre deux onglets sans
  -- prelever le perdant. Si le paiement est refuse, la ligne est retiree.
  BEGIN
    INSERT INTO public.ambassades_audiences (demandeur, pays_hote, empire, ambassadeur_pj, accord_prevu_le)
    VALUES (v_moi, v_pays, p_empire, v_pj,
            CASE WHEN v_pj IS NULL THEN now() + random() * interval '3 days' END)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_en_cours');
  END;

  v_paie := public.payer_ordre(v_moi, 'demander_audience_ambassadeur', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    DELETE FROM public.ambassades_audiences WHERE id = v_id;
    RETURN v_paie;
  END IF;

  PERFORM public.mail_systeme_poser_interne(
    'Quartier des Ambassades', v_moi, 'Demande d''audience transmise',
    'Votre demande d''audience auprès de l''<strong>' || (v_ident ->> 'ambassade') || '</strong> a bien été transmise.<br><br>'
    || 'Vous recevrez une réponse dans les plus brefs délais.<br><br>'
    || 'Le secrétariat du Quartier des Ambassades');

  IF v_pj IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne(
      'Quartier des Ambassades', v_pj, 'Demande d''audience',
      '<strong>' || v_moi || '</strong> sollicite une audience auprès de votre ambassade.<br><br>'
      || 'Si vous l''accordez, votre bureau lui sera ouvert pendant 48 heures.'
      || '[[act:audience_accorder|' || v_id::text || ']]');
  END IF;

  -- Un delai tire a zero ou presque : l'audience est accordee sur-le-champ.
  PERFORM public.ambassades_audiences_echoir(v_moi);
  SELECT statut INTO v_statut FROM public.ambassades_audiences WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'statut', v_statut,
                            'ambassadeur', v_ident ->> 'ambassadeur',
                            'ambassadeur_joueur', v_pj IS NOT NULL,
                            'pa', v_paie -> 'pa');
END; $function$;
REVOKE ALL ON FUNCTION public.ambassade_demander_audience(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ambassade_demander_audience(text) TO authenticated;

-- Suite : migrations/20261024184600_ambassades_audiences_acces.sql (le canal MCP borne une
-- migration a ~12 500 caracteres).
