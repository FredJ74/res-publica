-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010095302 (UTC), nom `affaire_la_transmission_au_tribunal_est_une_porte`.
-- Le registre passe de 611 a 612 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 74410c7b1140f906ccd8d04f1ae2f85f, 7583 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- LE CYCLE DE VIE D'UNE AFFAIRE N'A PLUS D'ECRITURE CLIENTE
--
-- Chantier 5 : les trois ecritures clientes restantes sur `plaintes_en_cours` etaient des upserts
-- du blob entier par `sbSavePlainte`, toutes avalees par un `.catch(() => {})`. Cette migration
-- livre la premiere des trois portes, `affaire_transmettre`, dont l'identifiant est derive de
-- l'acte et non d'un `Date.now()`. Les deux autres portes sont dans la migration suivante.
--
-- AVERTISSEMENT DE L'ARCHIVISTE : le corps ci-dessous affirme, au point 2 de son en-tete, qu'un
-- client modifie pouvait poser `status = 'jugee'` sur sa propre affaire. C'est FAUX -- le trigger
-- `plaintes_epingler_verdict` le lui reprenait. La migration 20261010095636 (registre 614)
-- rectifie ce point. Le corps est archive tel qu'il a ete applique.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE CYCLE DE VIE D'UNE AFFAIRE N'A PLUS D'ECRITURE CLIENTE
-- Chantier 5, les trois `sbSavePlainte` avales (10 octobre 2026).
--
-- CE QUE L'INSPECTION A MESURE, avant toute correction. `plaintes_en_cours` porte DEUX objets :
-- la plainte de police (creee par `plainte_deposer`, qui porte `commissaire_pj` et que les trois
-- policies excluent explicitement de toute ecriture cliente) et l'AFFAIRE au tribunal, qui
-- n'avait aucune porte. Les trois ecritures restantes etaient toutes des upserts du blob entier
-- par `sbSavePlainte`, toutes avalees par un `.catch(() => {})`, et la RLS les traitait
-- differemment -- c'est cette difference qui dit la gravite de chacune :
--
--   1. TRANSMISSION AU TRIBUNAL (`transmettreAffaireAuTribunal`). La policy d'INSERT demande
--      `affaire_autorite_de(city) OR affaire_me_concerne(data)`. Les deux appelants sont bien le
--      commissaire de la ville, donc l'insertion passait -- mais l'identifiant etait
--      `'affaire-' || Date.now()` : deux conclusions de la meme enquete le meme jour creaient
--      DEUX affaires contre la meme personne, et l'accuse devait se defendre deux fois.
--
--   2. DEFENSE DE L'ACCUSE (`doDefense`). `affaire_me_concerne(data)` est vrai pour la cible :
--      l'accuse pouvait donc reecrire sa propre affaire EN ENTIER, y compris `status`. Un client
--      modifie posait `status = 'jugee'` sans jet, sans PA et sans les 300 FR. A l'inverse, quand
--      l'ecriture echouait pour de bon, le juge ne voyait ni la circonstance attenuante ni
--      l'aggravation : les 2 PA et les 300 FR de la defense etaient perdus en silence.
--
--   3. CLASSEMENT MINISTERIEL (`annulerAffaire`). Le Ministre de la Justice n'est ni juge ni
--      commissaire, et une affaire ne le « concerne » pas : la policy d'UPDATE REFUSAIT son
--      ecriture, toujours, et le `.catch()` l'avalait. Les 250 FR quittaient la caisse du
--      gouvernement et la plainte restait ouverte. La politique de lecture, elle, nomme deja
--      `min_just` -- l'autorite existait, elle n'etait simplement appliquee nulle part.
--
-- CE QUE CES PORTES NE FONT PAS. Elles ne refont pas la sentence : `justice_rendre_sentence`
-- existe, verifie `affaire_autorite_de`, derive son identifiant de l'affaire et clot le dossier
-- dans la meme transaction que le jugement. Les trois portes ci-dessous s'arretent donc ou la
-- sienne commence, et `status = 'jugee'` n'est pose par aucune d'elles -- sauf la reussite
-- eclatante de la defense, qui classe l'affaire : c'est la regle de jeu existante.
--
-- CE QUI RESTE DANS LE NAVIGATEUR, ET POURQUOI. Le JET de la defense reste au client. Son taux
-- est `50 + (getStatEffective('CHA') - 8) * 3 - 35 si preuve reelle`, et `getStatEffective`
-- additionne un `bonusFormation` qui N'EST PERSISTE DANS AUCUNE COLONNE : il vit dans la memoire
-- de la session du navigateur et disparait au sommeil. Le serveur ne peut donc pas le connaitre.
-- Refaire le tirage ici reviendrait soit a supprimer l'effet de ce bonus sur la defense, soit a
-- le rendre persistant : les deux changent la regle. L'issue reste donc annoncee par le client,
-- mais dans une LISTE CLOSE de quatre valeurs, sur une affaire dont le serveur verifie qu'elle
-- est bien la sienne et qu'elle est encore jugeable. C'est strictement moins que ce qu'il
-- pouvait faire avant, et la limite est nommee au rapport.

-- 1 -- LA TRANSMISSION AU TRIBUNAL
CREATE OR REPLACE FUNCTION public.affaire_transmettre(
  p_cible text, p_motif text, p_city text, p_fait jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE
  v_nom text; v_pays text; v_jour integer; v_ville text;
  v_cible text; v_motif text; v_id text; v_data jsonb; v_n integer;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_cible := nullif(btrim(coalesce(p_cible, '')), '');
  v_motif := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_cible IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente'); END IF;
  IF v_motif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent'); END IF;
  v_ville := coalesce(nullif(btrim(coalesce(p_city, '')), ''), 'capitale');

  -- MEME REGLE QUE LA POLICY D'INSERT, lue en base : seule l'autorite judiciaire de la ville de
  -- l'affaire transmet au tribunal. Les deux appelants verifient deja leur juridiction cote
  -- client (`commissaireLocalValide`) -- ce qui etait verifie nulle part, c'est que l'ecriture
  -- avait abouti.
  IF NOT public.affaire_autorite_de(v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee', 'ville', v_ville);
  END IF;

  SELECT d.country, coalesce(d.day, 1) INTO v_pays, v_jour
    FROM public.personnages_donnees d WHERE d.name = v_nom LIMIT 1;
  v_pays := coalesce(v_pays, 'republic');

  -- L'IDENTIFIANT EST DERIVE DE L'ACTE, jamais d'une horloge : la meme affaire transmise deux
  -- fois le meme jour est la MEME ligne. La reference du fait demasque entre dans la cle quand
  -- elle existe, parce que deux actes traces distincts de la meme personne sont deux affaires.
  v_id := 'affaire-' || v_pays || '-' || v_ville || '-' || v_jour || '-'
          || substr(md5(v_cible || '|' || v_motif || '|' || coalesce(p_fait ->> 'refId', '')), 1, 12);

  v_data := jsonb_build_object('id', v_id, 'country', v_pays, 'city', v_ville,
                               'cible', v_cible, 'motif', v_motif, 'jour', v_jour,
                               'status', 'deposee', 'transmise_par', v_nom);
  IF p_fait IS NOT NULL AND jsonb_typeof(p_fait) = 'object' THEN
    IF nullif(p_fait ->> 'victime', '') IS NOT NULL THEN v_data := v_data || jsonb_build_object('victime', p_fait ->> 'victime'); END IF;
    IF p_fait ? 'jourFait' AND p_fait ->> 'jourFait' IS NOT NULL THEN v_data := v_data || jsonb_build_object('jourFait', (p_fait ->> 'jourFait')::integer); END IF;
    IF nullif(p_fait ->> 'refType', '') IS NOT NULL THEN v_data := v_data || jsonb_build_object('refType', p_fait ->> 'refType'); END IF;
    IF nullif(p_fait ->> 'refId', '') IS NOT NULL THEN v_data := v_data || jsonb_build_object('refId', p_fait ->> 'refId'); END IF;
  END IF;

  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_id, v_pays, v_ville, v_data::text)
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    SELECT CASE WHEN data IS NULL THEN NULL ELSE data::jsonb END INTO v_data
      FROM public.plaintes_en_cours WHERE id = v_id;
    RETURN jsonb_build_object('ok', true, 'deja_transmise', true, 'affaire', v_data, 'id', v_id);
  END IF;
  RETURN jsonb_build_object('ok', true, 'deja_transmise', false, 'affaire', v_data, 'id', v_id);
END; $fn$;

-- APPELABLE PAR UN JOUEUR, PAR PERSONNE D'AUTRE. Depuis le correctif des privileges de fonction
-- (registre 561), une fonction neuve ne recoit AUCUN droit nomme : il faut l'accorder. `anon`
-- n'en recoit jamais.
REVOKE ALL ON FUNCTION public.affaire_transmettre(text, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.affaire_transmettre(text, text, text, jsonb) TO authenticated, service_role;

-- SEPARATION TECHNIQUE, PAS LOGIQUE. Les deux autres portes du cycle -- `plainte_defendre` et
-- `plainte_classer_ministere` -- et les sept preuves structurelles des trois sont dans la
-- migration suivante : l'ensemble depasse la limite de transport du canal de migration
-- (~12 500 caracteres de SQL), constatee cinq fois sur ce chantier.
