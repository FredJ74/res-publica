-- PAYE DES DOUANIERS : RPC METIER DEDIEE (26 septembre 2026)
-- APPLIQUE EN PRODUCTION ET RECETTE. Feu vert explicite du concepteur.
--
-- LE DEFAUT, demontre par la telemetrie. Ecrire effectifsDouane exige le poste chef_douanes
-- (batiment_etat_sous_cle_ecrire), mais debiter <pays>_gouvernement-min_int exige le poste
-- min_int, parce que caisse_postes_requis deduit le poste du NOM de la caisse
-- ('gouvernement-<poste>') et retourne AVANT meme de consulter caisses_autorites. Ces deux
-- postes sont mutuellement exclusifs : la paye echouait donc systematiquement.
--   Arnie          -200 FR  republic_gouvernement-min_int  refuse  autorite_insuffisante  26/09 07:41
--   Vince Kubrick  -200 FR  republic_gouvernement-min_int  refuse  autorite_insuffisante  20/09 21:00
--   Arnie          -200 FR  republic_gouvernement-min_int  refuse  autorite_insuffisante  20/09 15:57
-- Sur TOUTE la telemetrie des caisses c'est la seule qui echoue : la police fonctionne parce
-- qu'elle debite la caisse du commissariat, ou caisses_autorites autorise bien le commissaire.
-- dernierPaiementJour etait fige au 12 septembre 2026, veille de la fermeture de batiments_etat.
--
-- CE QUI N'EST PAS FAIT, volontairement : aucune ligne ajoutee a caisses_autorites. Y mettre
-- chef_douanes lui donnerait un droit GENERIQUE sur toute la caisse du Ministere de
-- l'Interieur, ce que le concepteur a explicitement exclu.
--
-- CE QUI EST FAIT : une RPC metier dediee. Le Chef des Douanes ne gagne aucun droit sur la
-- caisse ; la seule chose possible est de payer exactement la masse salariale douaniere, une
-- fois par journee mondiale, pour un montant que le serveur calcule et que l'appelant ne
-- choisit pas -- la caisse n'est pas davantage un parametre. La porte utilisee est celle que
-- caisse_institution_mouvement_plafonne prevoit elle-meme :
-- current_setting('rp.caisse_interne') = 'on', pose en SET LOCAL (troisieme argument true de
-- set_config), donc limite a cette transaction, et seulement APRES verification de l'autorite
-- propre a l'operation.
--
-- REGLES CONSERVEES A L'IDENTIQUE, aucun changement economique :
--   standard 50 FR/jour, cynophile 100 FR/jour ; un douanier sans cle 'type' compte comme
--   standard, ce qui est le cas des 4 douaniers reels, semes avant que 'type' n'existe ;
--   fonds insuffisants -> debit plafonne et les DERNIERS RECRUTES partent d'abord, equivalent
--   exact du slice(0, nbGardes) du chemin client ;
--   AUCUN rappel d'arriere : les journees non payees depuis le 12/09 ne sont pas dues.
--
-- TEMPORALITE : la journee mondiale ECOULEE, exactement comme le rapport de renseignement.
-- Une seule temporalite canonique dans tout le jeu, et une paye se regle a terme echu.
-- Aucune horloge nouvelle.
--
-- AUTORITE : le serveur (cron) OU le titulaire de chef_douanes du pays. Le cron doit pouvoir
-- payer meme si le poste est VACANT : c'est le Ministere qui paie, le Chef ne fait que gerer
-- les effectifs. C'est aussi ce qui permet de sortir le traitement du doDormir() d'un joueur.
--
-- RECETTE PASSEE :
--   1) production, 4 douaniers standard : du 200, verse 200, solde min_int 67172 -> 66972,
--      dernierPaiementJour 2026-09-12 -> 2026-09-25, effectif inchange. Premiere paye
--      reussie depuis le 12 septembre.
--   2) second appel immediat : {ok:true, raison:'deja_paye', verse:0} -- idempotent.
--   3) banc jetable zzpays, caisse a 120 FR, 2 standards + 1 cynophile (du 200) :
--      verse 120, partis 1, effectif 3 -> 2, survivants ZZ-1 et ZZ-2 (les deux premiers
--      recrutes), solde 0. Regle des fonds insuffisants reproduite a l'identique.
--   4) appel REST avec la cle anon : 42501 permission denied.
--   Banc supprime, aucun residu.
--
-- APPELANTS : api/cron-minuit.js, tache quotidienne 'paye_douane', pour les quatre empires.
-- L'ancien chemin client payerEffectifsDouaneQuotidien() est neutralise (return en tete,
-- corps conserve inatteignable comme trace de la regle economique).

CREATE OR REPLACE FUNCTION public.douane_payer_effectifs(p_pays text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  c_cout_standard  constant integer := 50;
  c_cout_cynophile constant integer := 100;
  c_ville    constant text := 'ville_a';
  c_batiment constant text := 'port-sainte-marie';
  v_serveur boolean; v_moi text; v_poste text;
  v_id text; v_data jsonb; v_etat jsonb; v_eff jsonb; v_liste jsonb;
  v_jour date; v_deja text;
  v_du numeric := 0; v_verse numeric; v_r jsonb;
  v_n integer; v_gardes integer := 0; v_cumul numeric := 0; v_el jsonb;
  v_caisse text;
BEGIN
  IF COALESCE(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_serveur := public.est_appel_serveur();
  IF NOT v_serveur THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT (poste->>'id') INTO v_poste FROM public.personnages_donnees WHERE name = v_moi;
    IF v_poste IS DISTINCT FROM 'chef_douanes' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
                    WHERE name = v_moi AND country = p_pays) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pays_hors_autorite');
    END IF;
  END IF;

  v_jour   := ((now() AT TIME ZONE 'Europe/Paris')::date - 1);
  v_id     := p_pays || '_' || c_ville || '_' || c_batiment;
  v_caisse := p_pays || '_gouvernement-min_int';

  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'aucun_service', 'verse', 0);
  END IF;
  v_etat := COALESCE(public.batiment_etat_lire(v_data), '{}'::jsonb);
  v_eff  := v_etat -> 'effectifsDouane';
  IF v_eff IS NULL OR jsonb_typeof(v_eff) <> 'object' THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'aucun_service', 'verse', 0);
  END IF;

  v_deja := v_eff ->> 'dernierPaiementJour';
  IF v_deja = v_jour::text THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_paye', 'jour', v_jour, 'verse', 0);
  END IF;

  v_liste := COALESCE(v_eff -> 'douaniers', '[]'::jsonb);
  IF jsonb_typeof(v_liste) <> 'array' THEN v_liste := '[]'::jsonb; END IF;
  v_n := jsonb_array_length(v_liste);
  IF v_n = 0 THEN
    v_etat := jsonb_set(v_etat, ARRAY['effectifsDouane','dernierPaiementJour'],
                        to_jsonb(v_jour::text), true);
    UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
     WHERE id = v_id;
    RETURN jsonb_build_object('ok', true, 'raison', 'effectif_vide', 'jour', v_jour, 'verse', 0);
  END IF;

  FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    v_du := v_du + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                        THEN c_cout_cynophile ELSE c_cout_standard END;
  END LOOP;

  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_r := public.caisse_institution_mouvement_plafonne(v_caisse, v_du);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT COALESCE((v_r->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','debit_refuse'));
  END IF;
  v_verse := COALESCE((v_r->>'verse')::numeric, 0);

  FOR v_el IN SELECT value FROM jsonb_array_elements(v_liste) LOOP
    v_cumul := v_cumul + CASE WHEN COALESCE(v_el->>'type','standard') = 'cynophile'
                              THEN c_cout_cynophile ELSE c_cout_standard END;
    EXIT WHEN v_cumul > v_verse;
    v_gardes := v_gardes + 1;
  END LOOP;

  IF v_gardes < v_n THEN
    SELECT COALESCE(jsonb_agg(e ORDER BY o), '[]'::jsonb) INTO v_liste
      FROM jsonb_array_elements(v_liste) WITH ORDINALITY AS t(e, o)
     WHERE o <= v_gardes;
    v_etat := jsonb_set(v_etat, ARRAY['effectifsDouane','douaniers'], v_liste, true);
  END IF;
  v_etat := jsonb_set(v_etat, ARRAY['effectifsDouane','dernierPaiementJour'],
                      to_jsonb(v_jour::text), true);

  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'du', v_du, 'verse', v_verse,
                            'effectif_avant', v_n, 'effectif_apres', v_gardes,
                            'partis', v_n - v_gardes, 'caisse', v_caisse);
END;
$fn$;

REVOKE ALL ON FUNCTION public.douane_payer_effectifs(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.douane_payer_effectifs(text) TO authenticated, service_role;

COMMENT ON FUNCTION public.douane_payer_effectifs(text) IS
  'Paye quotidienne des douaniers du port : 50 FR par standard, 100 par cynophile, sur la '
  'caisse du Ministere de l''Interieur. Montant et caisse calcules par le serveur, jamais '
  'choisis par l''appelant. Idempotente par journee mondiale ecoulee. Appelable par le cron '
  'meme si le poste chef_douanes est vacant : c''est le Ministere qui paie.';
