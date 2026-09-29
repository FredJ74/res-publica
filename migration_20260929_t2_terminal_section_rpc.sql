-- ===========================================================================
-- T2 — TERMINAL DE SECTION : LES CINQ PORTES DU LIEUTENANT
-- 29 septembre 2026. Suite de T1 (militaire_ma_section, arme deduite).
-- ===========================================================================
-- CINQ PORTES, ET RIEN D'AUTRE. Aucune ne prend d'identifiant de compagnie ni de
-- section : le serveur resout lui-meme la section de l'appelant. Un joueur qui
-- n'est pas le Lieutenant structurel d'une section recoit toujours le meme refus,
-- quel que soit son grade -- Capitaine, Commandant et Ministre de la Defense
-- compris, conformement a l'arbitrage.
--
-- LES QUATRE PORTES MUTANTES SONT IDEMPOTENTES par cle de requete, motif deja
-- employe par C6 (apports_matieres) et la production (productions_references) :
-- rejouer la meme cle rend le meme resultat sans seconde ecriture.

-- ---------------------------------------------------------------------------
-- 0. SIGNATURE D'UN OBJET — CE QUI PERMET DE COMPTER ET DE DEPLACER N UNITES
-- ---------------------------------------------------------------------------
-- LE PROBLEME REEL : les objets militaires ne sont PAS empilables. Dix rations,
-- ce sont dix LIGNES d'inventaire sans `qty` ni `stackKey`. « Donner 3 rations
-- sur 10 » ne peut donc pas etre « fractionner une pile » -- il n'y a pas de
-- pile. On raisonne par SIGNATURE : deux objets de meme signature sont
-- interchangeables, et une quantite est un NOMBRE D'UNITES de cette signature.
--
-- La signature reprend la convention que le moteur de combat utilise deja pour
-- reconnaitre une arme -- coalesce(produitMilitaire, name) -- augmentee du type,
-- parce que deux objets homonymes de types differents existent reellement dans ce
-- jeu (l'explosif legal et l'explosif subtilise). Elle n'invente rien.
--
-- UN OBJET EMPILABLE RESTE EMPILE. Si la ligne porte `qty`, la quantite deplacee
-- se retranche de ce compteur : on ne transforme aucun objet unique en pile, et
-- on ne casse aucune pile existante.
create or replace function public.militaire_objet_signature(p_objet jsonb)
returns text
language sql
immutable
as $fn$
  SELECT lower(btrim(coalesce(nullif(btrim(coalesce(p_objet->>'produitMilitaire','')), ''),
                              p_objet->>'name', '?')))
      || '|' || lower(coalesce(p_objet->>'type', ''));
$fn$;

comment on function public.militaire_objet_signature(jsonb) is
  'Signature d''interchangeabilite d''un objet : coalesce(produitMilitaire, name) + type, la meme convention que militaire_armes_bonus utilise pour reconnaitre une arme. Deux objets de meme signature sont comptables ensemble ; c''est ce qui permet de transferer N unites sans exiger que les objets soient empilables.';

-- Unites reellement detenues pour une signature. Un objet empilable compte pour
-- son `qty`, un objet unique pour 1 : le meme calcul que le plafond
-- d'encombrement du jeu (greatest(1, coalesce(qty, encombrement, 1))) applique au
-- comptage plutot qu'a la place.
create or replace function public.militaire_unites_objet(p_objet jsonb)
returns integer
language sql
immutable
as $fn$
  SELECT greatest(1, floor(coalesce((p_objet->>'qty')::numeric, 1))::integer);
$fn$;

-- ---------------------------------------------------------------------------
-- 1. LECTURE DU TERMINAL — LA PORTE QUI REMPLACE LA LECTURE DU BLOB
-- ---------------------------------------------------------------------------
-- CE QU'ELLE FERME. L'ecran actuel appelle sbGetCompagnies, c'est-a-dire un
-- SELECT REST sur compagnies_militaires, dont la policy ouvre la lecture a TOUT
-- joueur authentifie du pays : ordre de bataille complet. Le terminal ne s'appuie
-- plus sur cette fuite -- il ne recoit QUE sa section. La policy elle-meme n'est
-- pas refermee dans ce lot : d'autres ecrans militaires la consomment encore.
--
-- ELLE NE REND AUCUNE POSITION PRECISE D'AUTRUI. Pour un soldat qui n'est pas
-- avec l'appelant, elle rend la VILLE et rien de plus fin : ni batiment, ni
-- piece. C'est la meme prudence que le retrait de sbPnjPositionEffective.
create or replace function public.militaire_terminal_section()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_pa_max          constant integer := 12;
  c_par_tente       constant integer := 13;   -- 13 personnes, PJ compris
  c_max_ration_jour constant integer := 2;
  g record; v_sec jsonb; v_jour text;
  v_ville text; v_bat text; v_room text; v_pays text;
  v_radio_moi boolean; v_tentes integer; v_pj_groupe integer;
  v_soldats jsonb; v_inv jsonb;
BEGIN
  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(g.o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = g.o_section;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  SELECT country, current_city, current_building, current_room
    INTO v_pays, v_ville, v_bat, v_room
    FROM public.personnages_donnees WHERE name = g.o_moi;

  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
           jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                     THEN pd.inventory ELSE '[]'::jsonb END) i
           WHERE pd.name = g.o_moi AND i->>'produitMilitaire' = 'radio') INTO v_radio_moi;

  -- TENTES DU GROUPE : celles de l'appelant, celles des PJ de la section presents
  -- au meme endroit, celles des PNJ qu'il mene. « Peu importe qui la transporte »,
  -- c'est la regle arbitree.
  SELECT coalesce((
    SELECT count(*) FROM public.personnages_donnees pd,
           jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                     THEN pd.inventory ELSE '[]'::jsonb END) i
     WHERE i->>'produitMilitaire' = 'tente'
       AND (pd.name = g.o_moi
            OR (pd.current_city = v_ville AND pd.current_building IS NOT DISTINCT FROM v_bat
                AND pd.current_room IS NOT DISTINCT FROM v_room
                AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
                             WHERE coalesce((s->>'pj')::boolean,false) AND s->>'nom' = pd.name)))
  ), 0) + coalesce((
    SELECT count(*) FROM public.pnj_possessions p
      JOIN public.pnj_membres m ON m.id = p.pnj_id
      JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND m.leader_pj = g.o_moi
       AND p.objet->>'produitMilitaire' = 'tente'
  ), 0) INTO v_tentes;

  -- PLACES DEJA OCCUPEES PAR DES PJ. L'appelant en occupe une, et chaque soldat
  -- PJ de sa section present avec lui aussi.
  SELECT 1 + coalesce((
    SELECT count(*) FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
      JOIN public.personnages_donnees pd ON pd.name = s->>'nom'
     WHERE coalesce((s->>'pj')::boolean,false) AND s->>'nom' <> g.o_moi
       AND pd.current_city = v_ville
       AND pd.current_building IS NOT DISTINCT FROM v_bat
       AND pd.current_room IS NOT DISTINCT FROM v_room), 0) INTO v_pj_groupe;

  -- MON INVENTAIRE, REGROUPE PAR SIGNATURE. C'est ce regroupement qui rend
  -- « donner 3 rations sur 10 » lisible : le joueur voit une ligne et un nombre,
  -- pas dix lignes identiques.
  SELECT coalesce(jsonb_agg(t.ligne ORDER BY t.nom), '[]'::jsonb) INTO v_inv
    FROM (
      SELECT public.militaire_objet_signature(i) AS sig,
             min(coalesce(i->>'name','?')) AS nom,
             jsonb_build_object(
               'signature', public.militaire_objet_signature(i),
               'name', min(coalesce(i->>'name','?')),
               'icon', min(coalesce(i->>'icon','ti-package')),
               'type', min(coalesce(i->>'type','')),
               'qte', sum(public.militaire_unites_objet(i))::integer,
               'arme', bool_or(i->>'type' = 'arme')) AS ligne
        FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                       THEN pd.inventory ELSE '[]'::jsonb END) i
       WHERE pd.name = g.o_moi
       GROUP BY public.militaire_objet_signature(i)
    ) t;

  -- LES SOLDATS. PA et leader viennent du SOCLE ; les compteurs journaliers du
  -- blob, qui en est le magasin metier.
  SELECT coalesce(jsonb_agg(x.ligne ORDER BY x.matricule), '[]'::jsonb) INTO v_soldats
    FROM (
      SELECT sm.matricule,
             jsonb_build_object(
               'matricule', sm.matricule,
               'pa', m.pa, 'pa_max', c_pa_max,
               'arme', coalesce(sm.arme, 'corps_a_corps'),
               'arme_feu', EXISTS (SELECT 1 FROM public.militaire_armes_bonus b
                                    WHERE b.cle = coalesce(sm.arme,'corps_a_corps') AND b.mode='feu'),
               'avec_moi', (m.leader_pj = g.o_moi),
               'leader', m.leader_pj,
               -- Position : la VILLE seulement, et rien pour qui est avec moi.
               'ville', CASE WHEN m.leader_pj = g.o_moi THEN NULL ELSE pe.ville END,
               'copresent', public.pnj_co_present(g.o_moi, m.id),
               'radio', EXISTS (SELECT 1 FROM public.pnj_possessions p
                                 WHERE p.pnj_id = m.id AND p.objet->>'produitMilitaire' = 'radio'),
               'a_ration', EXISTS (SELECT 1 FROM public.pnj_possessions p
                                    WHERE p.pnj_id = m.id
                                      AND p.objet->>'produitMilitaire' = 'ration_combat'),
               'rations_jour', CASE WHEN coalesce(b.sol->>'dernier_ration','') = v_jour
                                    THEN coalesce((b.sol->>'nb_ration')::integer, 1) ELSE 0 END,
               'max_ration_jour', c_max_ration_jour,
               'a_dormi', (coalesce(sm.dernier_sommeil,'') = v_jour),
               'possessions', coalesce((
                  SELECT jsonb_agg(q.ligne ORDER BY q.nom)
                    FROM (SELECT min(coalesce(p2.objet->>'name','?')) AS nom,
                                 jsonb_build_object(
                                   'signature', public.militaire_objet_signature(p2.objet),
                                   'name', min(coalesce(p2.objet->>'name','?')),
                                   'icon', min(coalesce(p2.objet->>'icon','ti-package')),
                                   'type', min(coalesce(p2.objet->>'type','')),
                                   'qte', sum(public.militaire_unites_objet(p2.objet))::integer) AS ligne
                            FROM public.pnj_possessions p2 WHERE p2.pnj_id = m.id
                           GROUP BY public.militaire_objet_signature(p2.objet)) q
                  ), '[]'::jsonb)
             ) AS ligne
        FROM public.pnj_soldats_metier sm
        JOIN public.pnj_membres m ON m.id = sm.pnj_id
        LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
        LEFT JOIN LATERAL (
          SELECT s AS sol FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
           WHERE s->>'matricule' = sm.matricule LIMIT 1) b ON true
       WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
         AND m.statut = 'actif' AND coalesce(sm.en_reserve, false) = false
    ) x;

  RETURN jsonb_build_object('ok', true,
    'moi', g.o_moi, 'pays', v_pays, 'enseigne', g.o_data->>'nom',
    'ma_ville', v_ville, 'suis_a_la_caserne', (v_bat = 'caserne-militaire'),
    'radio_moi', coalesce(v_radio_moi, false),
    'tentes', coalesce(v_tentes, 0),
    'capacite_tente', coalesce(v_tentes,0) * c_par_tente,
    'par_tente', c_par_tente,
    'places_pj', v_pj_groupe,
    'places_tente_libres', greatest(0, coalesce(v_tentes,0) * c_par_tente - v_pj_groupe),
    'mon_inventaire', v_inv,
    'soldats', v_soldats,
    'effectif', jsonb_array_length(v_soldats));
END; $fn$;

comment on function public.militaire_terminal_section() is
  'Tout ce que le terminal du Lieutenant affiche, en UN appel : ses soldats PNJ (matricule, PA, arme deduite, position reduite a la VILLE, possessions regroupees par signature, radio, compteurs du jour), son propre inventaire regroupe par signature, et la capacite reelle sous tente. Ne rend QUE la section dont l''appelant est le Lieutenant : c''est la porte qui dispense le terminal de lire le blob des compagnies, ouvert par policy a tout joueur du pays.';

revoke all on function public.militaire_terminal_section() from public, anon, authenticated;
grant execute on function public.militaire_terminal_section() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. LIAISON DE COMMANDEMENT — PRESENCE, OU RADIO DES DEUX COTES
-- ---------------------------------------------------------------------------
-- La regle existante (militaire_ordre_collectif) exigeait deux radios : celle du
-- Lieutenant et celle du LEADER du groupe. On la conserve, en la completant du cas
-- que l'arbitrage nomme : si le groupe distant n'a pas de leader PJ, c'est le PNJ
-- QUI PORTE LA RADIO qui fait office de leader pour cette liaison. Aucune
-- nomination manuelle a creer.
--
-- Un soldat physiquement present avec l'appelant ne demande aucune radio : il est
-- la, on lui parle.
create or replace function public.militaire_terminal_liaison(p_moi text, p_pnj_id text)
returns boolean
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_radio_moi boolean; v_leader text; pe record; v_radio_groupe boolean;
BEGIN
  IF public.pnj_co_present(p_moi, p_pnj_id) THEN RETURN true; END IF;

  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
           jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                     THEN pd.inventory ELSE '[]'::jsonb END) i
           WHERE pd.name = p_moi AND i->>'produitMilitaire' = 'radio') INTO v_radio_moi;
  IF NOT coalesce(v_radio_moi, false) THEN RETURN false; END IF;

  SELECT leader_pj INTO v_leader FROM public.pnj_membres WHERE id = p_pnj_id;
  IF v_leader IS NOT NULL THEN
    -- Groupe mene par un PJ : c'est SA radio qui compte.
    SELECT EXISTS (SELECT 1 FROM public.personnages_donnees pd,
             jsonb_array_elements(CASE WHEN jsonb_typeof(pd.inventory)='array'
                                       THEN pd.inventory ELSE '[]'::jsonb END) i
             WHERE pd.name = v_leader AND i->>'produitMilitaire' = 'radio') INTO v_radio_groupe;
    RETURN coalesce(v_radio_groupe, false);
  END IF;

  -- Groupe de PNJ sans chef joueur : le porteur de radio EST le leader. On cherche
  -- une radio parmi les PNJ qui se tiennent exactement au meme endroit.
  SELECT * INTO pe FROM public.pnj_position_effective(p_pnj_id);
  IF pe.ville IS NULL THEN RETURN false; END IF;
  SELECT EXISTS (
    SELECT 1 FROM public.pnj_membres m2
      JOIN public.pnj_possessions p ON p.pnj_id = m2.id
     WHERE m2.statut = 'actif' AND m2.pays = pe.pays
       AND m2.ville = pe.ville
       AND m2.building_id IS NOT DISTINCT FROM pe.building_id
       AND m2.room_id IS NOT DISTINCT FROM pe.room_id
       AND p.objet->>'produitMilitaire' = 'radio') INTO v_radio_groupe;
  RETURN coalesce(v_radio_groupe, false);
END; $fn$;

comment on function public.militaire_terminal_liaison(text,text) is
  'Le Lieutenant peut-il commander ce soldat ? Vrai s''il est physiquement present avec lui, sinon vrai seulement si le Lieutenant porte une radio ET que le groupe distant en porte une -- celle de son leader PJ, ou, a defaut de leader joueur, celle d''un PNJ place au meme endroit, qui fait alors office de leader pour cette liaison.';

-- ---------------------------------------------------------------------------
-- 3. TRANSFERT D'OBJET, AVEC QUANTITE, DANS LES DEUX SENS
-- ---------------------------------------------------------------------------
-- GENERALISATION DU RAIL SOCLE, PAS UN TROISIEME INVENTAIRE. La destination reste
-- pnj_possessions, l'origine reste personnages_donnees.inventory, et la forme des
-- objets n'est jamais reecrite : on deplace l'objet TEL QUEL.
--
-- AUCUNE LISTE BLANCHE. N'importe quel objet passe, y compris un objet qui
-- n'existe pas encore aujourd'hui. Le seul filtre de l'ancien ecran -- le champ
-- `produitMilitaire` exige cote navigateur -- disparait.
--
-- CO-PRESENCE OBLIGATOIRE DANS LES DEUX SENS : une radio transmet un ordre, elle
-- ne teleporte pas un paquetage.
create or replace function public.militaire_terminal_transferer(
  p_requete text, p_matricule text, p_signature text, p_qte integer, p_sens text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_plafond constant integer := 100;
  g record; v_deja record; v_pnj text; v_qte integer := coalesce(p_qte, 0);
  v_inv jsonb; v_reste integer; v_dispo integer := 0; v_occupe numeric;
  v_ligne jsonb; v_pos integer; v_u integer; v_nouv jsonb := '[]'::jsonb;
  v_bouge integer := 0; v_nom text; v_arme text; v_id bigint; v_objet jsonb;
  v_res jsonb; i integer;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF coalesce(p_sens,'') NOT IN ('donner','reprendre') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide'); END IF;
  IF v_qte < 1 OR v_qte > 100 OR v_qte IS DISTINCT FROM p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  IF coalesce(btrim(coalesce(p_signature,'')),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  SELECT sm.pnj_id INTO v_pnj
    FROM public.pnj_soldats_metier sm JOIN public.pnj_membres m ON m.id = sm.pnj_id
   WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
     AND sm.matricule = p_matricule AND m.statut = 'actif';
  IF v_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_introuvable'); END IF;
  IF NOT public.pnj_co_present(g.o_moi, v_pnj) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents'); END IF;

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = g.o_moi FOR UPDATE;

  IF p_sens = 'donner' THEN
    SELECT coalesce(sum(public.militaire_unites_objet(i)), 0)::integer INTO v_dispo
      FROM jsonb_array_elements(v_inv) i
     WHERE public.militaire_objet_signature(i) = p_signature;
    IF v_dispo < v_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante',
        'disponibles', v_dispo, 'demande', v_qte); END IF;

    -- On parcourt les lignes une fois. Une ligne EMPILEE plus grosse que le reste
    -- demande est scindee par son `qty` ; une ligne unitaire part en entier.
    v_reste := v_qte;
    FOR v_ligne IN SELECT value FROM jsonb_array_elements(v_inv) LOOP
      IF v_reste > 0 AND public.militaire_objet_signature(v_ligne) = p_signature THEN
        v_u := public.militaire_unites_objet(v_ligne);
        v_nom := coalesce(v_ligne->>'name', '?');
        IF v_u <= v_reste THEN
          INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
          VALUES (v_pnj, v_ligne, 'socle');
          v_reste := v_reste - v_u; v_bouge := v_bouge + v_u;
        ELSE
          INSERT INTO public.pnj_possessions (pnj_id, objet, origine)
          VALUES (v_pnj, v_ligne || jsonb_build_object('qty', v_reste), 'socle');
          v_nouv := v_nouv || jsonb_build_array(v_ligne || jsonb_build_object('qty', v_u - v_reste));
          v_bouge := v_bouge + v_reste; v_reste := 0;
        END IF;
      ELSE
        v_nouv := v_nouv || jsonb_build_array(v_ligne);
      END IF;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_nouv, updated_at = now()
     WHERE name = g.o_moi;

  ELSE
    SELECT coalesce(sum(public.militaire_unites_objet(p.objet)), 0)::integer INTO v_dispo
      FROM public.pnj_possessions p
     WHERE p.pnj_id = v_pnj AND public.militaire_objet_signature(p.objet) = p_signature;
    IF v_dispo < v_qte THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quantite_insuffisante_soldat',
        'disponibles', v_dispo, 'demande', v_qte); END IF;

    -- Le plafond d'encombrement du Lieutenant est celui du jeu, repris tel quel.
    SELECT coalesce(sum(greatest(1, coalesce((i->>'qty')::numeric,
             (i->>'encombrement')::numeric, 1))), 0) INTO v_occupe
      FROM jsonb_array_elements(v_inv) i;
    IF v_occupe + v_qte > c_plafond THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein',
        'occupe', v_occupe, 'plafond', c_plafond, 'demande', v_qte); END IF;

    v_reste := v_qte;
    FOR v_id, v_objet IN
      SELECT p.id, p.objet FROM public.pnj_possessions p
       WHERE p.pnj_id = v_pnj AND public.militaire_objet_signature(p.objet) = p_signature
       ORDER BY p.id FOR UPDATE
    LOOP
      EXIT WHEN v_reste <= 0;
      v_u := public.militaire_unites_objet(v_objet);
      v_nom := coalesce(v_objet->>'name', '?');
      IF v_u <= v_reste THEN
        DELETE FROM public.pnj_possessions WHERE id = v_id;
        v_inv := v_inv || jsonb_build_array(v_objet);
        v_reste := v_reste - v_u; v_bouge := v_bouge + v_u;
      ELSE
        UPDATE public.pnj_possessions
           SET objet = v_objet || jsonb_build_object('qty', v_u - v_reste) WHERE id = v_id;
        v_inv := v_inv || jsonb_build_array(v_objet || jsonb_build_object('qty', v_reste));
        v_bouge := v_bouge + v_reste; v_reste := 0;
      END IF;
    END LOOP;
    UPDATE public.personnages_donnees SET inventory = v_inv, updated_at = now()
     WHERE name = g.o_moi;
  END IF;

  -- L'ARME SUIT LE PAQUETAGE. C'est ici que le divorce disparait : quelle que soit
  -- la nature de l'objet deplace, l'armement operationnel est reconstruit depuis ce
  -- que le soldat porte reellement.
  v_arme := public.militaire_arme_recalculer(v_pnj);

  v_res := jsonb_build_object('ok', true, 'sens', p_sens, 'matricule', p_matricule,
    'signature', p_signature, 'quantite', v_bouge, 'objet', v_nom, 'arme', v_arme);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'transfert', v_res);
  RETURN v_res;
END; $fn$;

comment on function public.militaire_terminal_transferer(text,text,text,integer,text) is
  'Deplace N unites d''une signature d''objet entre le Lieutenant et un de ses soldats PNJ, dans les deux sens. Aucune liste blanche : n''importe quel objet passe, y compris ceux qui n''existent pas encore. Co-presence exigee dans les deux sens. Un objet empile est scinde par son qty, un objet unitaire part en entier. Recalcule l''armement du soldat apres chaque mouvement. Idempotente par cle de requete.';

revoke all on function public.militaire_terminal_transferer(text,text,text,integer,text) from public, anon, authenticated;
grant execute on function public.militaire_terminal_transferer(text,text,text,integer,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. MANGER — LA RATION EST UN BONUS, PLUS UNE CONDITION
-- ---------------------------------------------------------------------------
-- CE QUI CHANGE PAR RAPPORT A militaire_ordre_collectif (conservee intacte pour
-- ses appelants) : le secours automatique disparait. L'ancienne fonction prenait
-- une ration DANS L'INVENTAIRE DU LIEUTENANT pour tout soldat qui n'en avait pas,
-- et refusait l'ordre ENTIER si le chef n'en avait pas assez (rations_insuffisantes).
-- Desormais : chacun mange la SIENNE, celui qui n'en a pas mange sans bonus, et
-- le paquetage du Lieutenant n'est jamais touche.
--
-- VALEURS REPRISES A L'IDENTIQUE : +1 PA, deux rations par jour au maximum, et
-- seulement sous 12 PA -- une ration au plafond serait gaspillee.
create or replace function public.militaire_terminal_manger(p_requete text, p_matricules text[])
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_gain constant integer := 1;
  c_pa_max constant integer := 12;
  c_max_jour constant integer := 2;
  g record; v_deja record; v_jour text; r record; v_res jsonb;
  v_avec integer := 0; v_sans integer := 0; v_refus jsonb := '[]'::jsonb;
  v_ids text[] := '{}'; v_mats text[] := '{}'; v_id bigint; v_u integer; v_objet jsonb;
  v_data jsonb; v_sec jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF p_matricules IS NULL OR array_length(p_matricules, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_selection'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(g.o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = g.o_section;

  FOR r IN
    SELECT sm.pnj_id, sm.matricule, m.pa,
           CASE WHEN coalesce(b.sol->>'dernier_ration','') = v_jour
                THEN coalesce((b.sol->>'nb_ration')::integer, 1) ELSE 0 END AS nb
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN LATERAL (
        SELECT s AS sol FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
         WHERE s->>'matricule' = sm.matricule LIMIT 1) b ON true
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND coalesce(sm.en_reserve,false) = false
       AND sm.matricule = ANY(p_matricules)
     ORDER BY sm.matricule
  LOOP
    IF NOT public.militaire_terminal_liaison(g.o_moi, r.pnj_id) THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'hors_liaison');
      CONTINUE;
    END IF;

    -- REMISE A NUL OBLIGATOIRE : sans elle, un soldat sans ration heriterait de
    -- la ligne du soldat precedent et se verrait prelever la ration d'un autre.
    v_id := NULL; v_objet := NULL;
    SELECT p.id, p.objet INTO v_id, v_objet FROM public.pnj_possessions p
     WHERE p.pnj_id = r.pnj_id AND p.objet->>'produitMilitaire' = 'ration_combat'
     ORDER BY p.id LIMIT 1 FOR UPDATE;

    IF v_id IS NULL OR r.pa >= c_pa_max OR r.nb >= c_max_jour THEN
      -- IL MANGE QUAND MEME. Sans ration personnelle, sans bonus, et SURTOUT sans
      -- que la ration du Lieutenant soit prelevee. Ce n'est pas un refus.
      v_sans := v_sans + 1;
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison',
        CASE WHEN v_id IS NULL THEN 'sans_ration'
             WHEN r.pa >= c_pa_max THEN 'pa_au_maximum'
             ELSE 'maximum_quotidien' END, 'execute', true);
      CONTINUE;
    END IF;

    v_u := public.militaire_unites_objet(v_objet);
    IF v_u <= 1 THEN DELETE FROM public.pnj_possessions WHERE id = v_id;
    ELSE UPDATE public.pnj_possessions
            SET objet = v_objet || jsonb_build_object('qty', v_u - 1) WHERE id = v_id; END IF;

    v_ids  := v_ids  || r.pnj_id;
    v_mats := v_mats || r.matricule;
    v_avec := v_avec + 1;
  END LOOP;

  IF v_avec > 0 THEN
    PERFORM public.pnj_pa_crediter(v_ids, c_gain);
    -- Les compteurs journaliers vivent dans le blob : c'est une donnee metier.
    SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = g.o_compagnie FOR UPDATE;
    UPDATE public.compagnies_militaires
       SET data = jsonb_set(v_data, '{sections}', (
             SELECT coalesce(jsonb_agg(
               CASE WHEN s->>'id' = g.o_section
                    THEN jsonb_set(s, '{soldats}', (
                           SELECT coalesce(jsonb_agg(
                             CASE WHEN (so->>'matricule') = ANY(v_mats)
                                  THEN so || jsonb_build_object('dernier_ration', v_jour,
                                         'nb_ration', (CASE WHEN coalesce(so->>'dernier_ration','') = v_jour
                                                            THEN coalesce((so->>'nb_ration')::integer,1)
                                                            ELSE 0 END) + 1)
                                  ELSE so END ORDER BY o2), '[]'::jsonb)
                             FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb))
                                  WITH ORDINALITY AS t2(so, o2)))
                    ELSE s END ORDER BY o1), '[]'::jsonb)
               FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb))
                    WITH ORDINALITY AS t1(s, o1))),
           updated_at = now()
     WHERE id = g.o_compagnie;
    PERFORM public.militaire_blob_projeter(g.o_compagnie);
  END IF;

  v_res := jsonb_build_object('ok', true, 'action', 'manger',
    'avec_ration', v_avec, 'sans_ration', v_sans, 'gain_pa', c_gain, 'details', v_refus);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'manger', v_res);
  RETURN v_res;
END; $fn$;

comment on function public.militaire_terminal_manger(text,text[]) is
  'Ordre collectif de manger. Chaque soldat selectionne consomme SA propre ration et gagne 1 PA (plafond 12, deux par jour) ; celui qui n''en a pas execute l''ordre sans bonus et ne fait pas echouer l''ordre. La ration du Lieutenant n''est JAMAIS prelevee pour un PNJ -- c''est ce qui distingue cette porte de militaire_ordre_collectif. Idempotente par cle de requete.';

revoke all on function public.militaire_terminal_manger(text,text[]) from public, anon, authenticated;
grant execute on function public.militaire_terminal_manger(text,text[]) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. DORMIR — ET LA TENTE, DONT LA CAPACITE COMPTE LES JOUEURS
-- ---------------------------------------------------------------------------
-- VALEURS REPRISES DE militaire_reposer_section, SANS UNE UNITE D'ECART :
-- a la caserne le repos remet a 12 ; sur le terrain il rend 8 ; sous la tente
-- 8 + 2 = 10. Une fois par jour, et jamais pour un soldat a 0 PA (le repos ne
-- ressuscite rien).
--
-- CE QUI CHANGE : le joueur DESIGNE qui dort et qui a une place sous la tente, au
-- lieu d'un tri automatique par matricule. La capacite est donc verifiee ici, et
-- elle compte 13 PERSONNES par tente, PJ COMPRIS -- l'arbitrage est explicite.
-- Si la selection sous tente depasse la capacite, l'ordre ENTIER est refuse :
-- attribuer arbitrairement les places restantes serait decider a la place du
-- joueur.
create or replace function public.militaire_terminal_dormir(
  p_requete text, p_matricules text[], p_tentes text[])
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_pa_max constant integer := 12;
  c_gain_terrain constant integer := 8;
  c_bonus_tente constant integer := 2;
  g record; v_deja record; v_jour text; r record; v_res jsonb; v_etat jsonb;
  v_tentes text[] := coalesce(p_tentes, '{}'::text[]);
  v_libres integer; v_caserne text[] := '{}'; v_sous_tente text[] := '{}';
  v_terrain text[] := '{}'; v_mats text[] := '{}'; v_refus jsonb := '[]'::jsonb;
  v_data jsonb; v_sec jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF p_matricules IS NULL OR array_length(p_matricules, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_selection'); END IF;
  IF EXISTS (SELECT 1 FROM unnest(v_tentes) t WHERE t <> ALL(p_matricules)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tente_hors_selection'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  -- La capacite est celle que le terminal affiche : une seule source de verite.
  v_etat := public.militaire_terminal_section();
  v_libres := coalesce((v_etat->>'places_tente_libres')::integer, 0);
  IF coalesce(array_length(v_tentes,1), 0) > v_libres THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_tente_depassee',
      'demande', coalesce(array_length(v_tentes,1),0), 'places_libres', v_libres,
      'tentes', v_etat->'tentes', 'par_tente', v_etat->'par_tente',
      'places_pj', v_etat->'places_pj'); END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(g.o_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = g.o_section;

  FOR r IN
    SELECT sm.pnj_id, sm.matricule, m.pa, coalesce(sm.dernier_sommeil,'') AS marqueur,
           coalesce(pd.current_building, m.building_id) AS batiment
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN public.personnages_donnees pd ON pd.name = m.leader_pj
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND coalesce(sm.en_reserve,false) = false
       AND sm.matricule = ANY(p_matricules)
     ORDER BY sm.matricule
  LOOP
    IF NOT public.militaire_terminal_liaison(g.o_moi, r.pnj_id) THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'hors_liaison');
      CONTINUE;
    END IF;
    IF r.pa <= 0 THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'epuise');
      CONTINUE;
    END IF;
    IF r.marqueur = v_jour THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'deja_repose');
      CONTINUE;
    END IF;

    v_mats := v_mats || r.matricule;
    IF coalesce(r.batiment,'') = 'caserne-militaire' THEN v_caserne := v_caserne || r.pnj_id;
    ELSIF r.matricule = ANY(v_tentes)                THEN v_sous_tente := v_sous_tente || r.pnj_id;
    ELSE                                                  v_terrain := v_terrain || r.pnj_id;
    END IF;
  END LOOP;

  IF array_length(v_caserne,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_fixer(v_caserne, c_pa_max); END IF;
  IF array_length(v_sous_tente,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_sous_tente, c_gain_terrain + c_bonus_tente); END IF;
  IF array_length(v_terrain,1) IS NOT NULL THEN
    PERFORM public.pnj_pa_crediter(v_terrain, c_gain_terrain); END IF;

  IF array_length(v_mats,1) IS NOT NULL THEN
    SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = g.o_compagnie FOR UPDATE;
    UPDATE public.compagnies_militaires
       SET data = jsonb_set(v_data, '{sections}', (
             SELECT coalesce(jsonb_agg(
               CASE WHEN s->>'id' = g.o_section
                    THEN jsonb_set(s, '{soldats}', (
                           SELECT coalesce(jsonb_agg(
                             CASE WHEN (so->>'matricule') = ANY(v_mats)
                                  THEN so || jsonb_build_object('dernier_sommeil', v_jour)
                                  ELSE so END ORDER BY o2), '[]'::jsonb)
                             FROM jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb))
                                  WITH ORDINALITY AS t2(so, o2)))
                    ELSE s END ORDER BY o1), '[]'::jsonb)
               FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb))
                    WITH ORDINALITY AS t1(s, o1))),
           updated_at = now()
     WHERE id = g.o_compagnie;
    PERFORM public.militaire_blob_projeter(g.o_compagnie);
  END IF;

  v_res := jsonb_build_object('ok', true, 'action', 'dormir',
    'caserne', coalesce(array_length(v_caserne,1),0),
    'tente', coalesce(array_length(v_sous_tente,1),0),
    'terrain', coalesce(array_length(v_terrain,1),0),
    'reposes', coalesce(array_length(v_mats,1),0),
    'details', v_refus);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'dormir', v_res);
  RETURN v_res;
END; $fn$;

comment on function public.militaire_terminal_dormir(text,text[],text[]) is
  'Ordre collectif de dormir, avec designation explicite de qui a une place sous la tente. Valeurs reprises de militaire_reposer_section : caserne 12, terrain +8, tente +8+2, une fois par jour, jamais a 0 PA. La capacite est de 13 personnes par tente PJ COMPRIS, et une selection qui la depasse refuse l''ordre ENTIER plutot que d''attribuer les places a la place du joueur. Idempotente par cle de requete.';

revoke all on function public.militaire_terminal_dormir(text,text[],text[]) from public, anon, authenticated;
grant execute on function public.militaire_terminal_dormir(text,text[],text[]) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. REJOINDRE — ET AUCUNE TELEPORTATION
-- ---------------------------------------------------------------------------
-- Meme ecriture que militaire_recuperer_soldats : leader_pj = moi, position propre
-- effacee (la contrainte pnj_position_deux_etats l'impose, et c'est le modele
-- « suivre un chef » du socle). Deux differences, toutes deux demandees :
--   - le perimetre est la VILLE et non plus la piece exacte, parce qu'un ordre
--     radio porte a l'echelle d'une ville ;
--   - une liaison de commandement est exigee quand le soldat n'est pas la.
--
-- UNE AUTRE VILLE EST REFUSEE, NOMMEMENT. On ne deplace personne entre villes
-- ici : le transport existe deja (le camion militaire) et reste le seul chemin.
create or replace function public.militaire_terminal_rejoindre(p_requete text, p_matricules text[])
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  g record; v_deja record; r record; v_res jsonb; v_ville text;
  v_ids text[] := '{}'; v_refus jsonb := '[]'::jsonb;
BEGIN
  IF p_requete IS NULL OR p_requete !~ '^mil-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF p_matricules IS NULL OR array_length(p_matricules, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_selection'); END IF;

  SELECT * INTO v_deja FROM public.militaire_terminal_requetes WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja.resultat || jsonb_build_object('rejeu', true); END IF;

  SELECT * INTO g FROM public.militaire_ma_section();
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;
  SELECT current_city INTO v_ville FROM public.personnages_donnees WHERE name = g.o_moi;
  IF coalesce(v_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue'); END IF;

  FOR r IN
    SELECT sm.pnj_id, sm.matricule, m.leader_pj, pe.ville AS ville_reelle
      FROM public.pnj_soldats_metier sm
      JOIN public.pnj_membres m ON m.id = sm.pnj_id
      LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
     WHERE sm.compagnie_id = g.o_compagnie AND sm.section_id = g.o_section
       AND m.statut = 'actif' AND coalesce(sm.en_reserve,false) = false
       AND sm.matricule = ANY(p_matricules)
     ORDER BY sm.matricule
  LOOP
    IF r.leader_pj = g.o_moi THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'deja_avec_vous');
      CONTINUE;
    END IF;
    IF NOT public.militaire_terminal_liaison(g.o_moi, r.pnj_id) THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule, 'raison', 'hors_liaison');
      CONTINUE;
    END IF;
    IF r.ville_reelle IS DISTINCT FROM v_ville THEN
      v_refus := v_refus || jsonb_build_object('matricule', r.matricule,
        'raison', 'autre_ville_transport_requis', 'ville', r.ville_reelle);
      CONTINUE;
    END IF;
    v_ids := v_ids || r.pnj_id;
  END LOOP;

  IF array_length(v_ids,1) IS NOT NULL THEN
    UPDATE public.pnj_membres
       SET leader_pj = g.o_moi, leader_pnj_id = NULL,
           ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL, maj_le = now()
     WHERE id = ANY(v_ids);
    PERFORM public.militaire_blob_projeter(g.o_compagnie);
  END IF;

  v_res := jsonb_build_object('ok', true, 'action', 'rejoindre',
    'rejoints', coalesce(array_length(v_ids,1),0), 'details', v_refus);
  INSERT INTO public.militaire_terminal_requetes (requete, acteur, action, resultat)
  VALUES (p_requete, g.o_moi, 'rejoindre', v_res);
  RETURN v_res;
END; $fn$;

comment on function public.militaire_terminal_rejoindre(text,text[]) is
  'Rappelle des soldats aupres du Lieutenant : leader_pj = lui, position propre effacee, comme militaire_recuperer_soldats. Le perimetre est la VILLE et non la piece, et une liaison de commandement est exigee a distance. Une autre ville est refusee nommement (autre_ville_transport_requis) : aucun soldat n''est teleporte, le transport reste le camion militaire existant.';

revoke all on function public.militaire_terminal_rejoindre(text,text[]) from public, anon, authenticated;
grant execute on function public.militaire_terminal_rejoindre(text,text[]) to authenticated, service_role;
