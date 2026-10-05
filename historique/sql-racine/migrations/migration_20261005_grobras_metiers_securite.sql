-- ===========================================================================
-- GROBRAS SECURITE — LOT 2 : LES DEUX PROFILS METIER
-- 5 octobre 2026
-- ---------------------------------------------------------------------------
-- DEUX LIGNES. C'est tout, et c'est le resultat de l'audit d'architecture : le
-- socle PNJ porte deja la position, les PA, les six caracteristiques, la
-- propriete, le chef, l'equipement et la mort. Il ne manquait que la fiche
-- signaletique de deux metiers.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS, ET NE DOIT PAS FAIRE :
--   - elle ne cree AUCUN PNJ (aucune ligne dans pnj_membres) ;
--   - elle n'ouvre AUCUN recrutement : employe_metiers_recrutables() n'est pas
--     touchee, donc employe_recruter('agent_securite') repond encore
--     `metier_non_recrutable`, et c'est voulu ;
--   - elle ne cree aucune table, aucune fonction, aucune colonne, aucune caisse,
--     aucun contrat, aucune mission, aucune interface.
--
-- ---------------------------------------------------------------------------
-- POURQUOI LA FAMILLE EST « employe », ET POURQUOI LA CLASSE N'EST PAS ICI
-- ---------------------------------------------------------------------------
-- Deux fonctions du socle decident de tout, et elles ont ete relues avant
-- d'ecrire une ligne :
--
--   pnj_metier_de(id) : « CASE WHEN famille = 'employe' THEN pnj_employes_metier.job
--                         ELSE famille END »
--     => un metier DISTINCT de sa famille n'existe QUE pour la famille employe.
--        C'est deja ainsi que vivent escort, informateur et codetenu. Un agent de
--        securite est un employe d'un joueur : il est a sa place.
--
--   pnj_classe_de(id) : « COALESCE(pnj_membres.classe,
--                                  pnj_familles_classes[famille].classe) »
--     => L'INDIVIDU D'ABORD, le defaut de sa famille ensuite. La classe ne vit
--        donc NI dans pnj_metiers_profils (qui n'a pas cette colonne), NI dans le
--        metier : elle se pose sur la ligne du PNJ, a sa creation.
--
-- Consequence directe, et c'est la bonne nouvelle de l'audit : un agent Grobras
-- pourra etre cree en `classe = 'alpha'` SANS promouvoir la famille employe, donc
-- sans toucher aux escortes ni aux informateurs, qui restent beta. La classe est
-- portee par l'individu depuis la migration du 27 septembre 2026
-- (socle_pnj_classe_portee_par_individu_pas_par_famille) -- c'est exactement le
-- cran prevu par l'architecture, et il n'a pas encore ete franchi.
--
-- Ce que « alpha » apportera alors, et que beta refuse : pnj_pa_garde() rejette
-- toute variation de PA hors classe alpha (« Seule la classe alpha voit ses PA
-- varier pour agir »). Un agent qui doit depenser des PA DOIT donc etre alpha.
-- Rien a declarer ici pour cela ; tout se jouera a la creation du PNJ.
--
-- Faute de colonne, l'intention est inscrite dans `note`, comme le font deja les
-- huit metiers existants (« Metier de la famille employe, classe beta... »).
--
-- ---------------------------------------------------------------------------
-- LES VALEURS, ET CE QUI A ETE ARBITRE PAR FRED
-- ---------------------------------------------------------------------------
-- Arbitre : PER 12 / VOL 16 pour l'agent de securite, PER 16 / VOL 14 pour le
-- maitre-chien. Ces quatre nombres viennent du game design, et rien d'autre.
--
-- NON ARBITRE, et pourtant obligatoire : les six caracteristiques sont NOT NULL.
-- INT, CHA, DUP et ENT doivent donc exister. Plutot que d'inventer, elles sont
-- RECOPIEES du profil `policier` (INT 10, CHA 8, DUP 8, ENT 10) -- le metier deja
-- arbitre le plus proche d'un agent de securite, et celui dont `douanier` partage
-- deja les six valeurs a l'identique. Aucune n'est tiree au hasard, aucune n'est
-- inventee : si l'une d'elles doit changer, c'est un arbitrage d'une ligne.
--
-- pa_initial = 12 : ce n'est pas un choix de jeu, c'est la valeur du socle
-- (pnj_pa_max() rend 12, pnj_membres.pa vaut 12 par defaut). Elle est posee parce
-- que employe_recruter fait `COALESCE(p_pa, profil.pa_initial)` : un NULL ici
-- passerait un NULL explicite a une colonne NOT NULL au lieu de laisser le defaut
-- s'appliquer. C'est une precaution, pas une decision.
--
-- cout_initial et cout_jour restent NULL, DELIBEREMENT. Les cinq metiers non
-- achetables du jeu portent 0 ; ici NULL dit autre chose, et dit vrai : le tarif
-- n'est pas arbitre. 0 signifierait « gratuit », ce qui serait une decision que
-- ce lot n'a pas le droit de prendre.
-- ===========================================================================

begin;

insert into public.pnj_metiers_profils
  (metier, car_int, car_cha, car_vol, car_per, car_dup, car_ent,
   pa_initial, cout_initial, cout_jour, note, quota_note)
values
  ('agent_securite', 10, 8, 16, 12, 8, 10, 12, null, null,
   'Metier de la famille employe, destine a la classe ALPHA (posee sur l''individu a sa creation, pas ici). Agent de securite prive de l''agence Grobras Securite, Luthecia. VOL 16 et PER 12 arbitres par le GD le 5 octobre 2026 ; INT/CHA/DUP/ENT recopies du profil policier, le metier deja arbitre le plus proche. Aucune valeur inventee.',
   'Aucun quota, aucun plafond propre : ce metier n''est PAS recrutable. Il ne figure pas dans employe_metiers_recrutables(), donc employe_recruter le refuse. Le plafond commun de 10 employes s''appliquera le jour ou il sera ouvert.'),

  ('maitre_chien',   10, 8, 14, 16, 8, 10, 12, null, null,
   'Metier de la famille employe, destine a la classe ALPHA (posee sur l''individu a sa creation, pas ici). Maitre-chien de l''agence Grobras Securite, Luthecia. PER 16 et VOL 14 arbitres par le GD le 5 octobre 2026 ; INT/CHA/DUP/ENT recopies du profil policier. Le chien n''est PAS un PNJ : il fait partie du maitre, comme le cynophile de la police (pnj_force_publique_metier.chien_nom) n''a jamais eu de ligne propre.',
   'Aucun quota, aucun plafond propre : ce metier n''est PAS recrutable. Il ne figure pas dans employe_metiers_recrutables(), donc employe_recruter le refuse.')
on conflict (metier) do update set
  car_int      = excluded.car_int,
  car_cha      = excluded.car_cha,
  car_vol      = excluded.car_vol,
  car_per      = excluded.car_per,
  car_dup      = excluded.car_dup,
  car_ent      = excluded.car_ent,
  pa_initial   = excluded.pa_initial,
  cout_initial = excluded.cout_initial,
  cout_jour    = excluded.cout_jour,
  note         = excluded.note,
  quota_note   = excluded.quota_note;


-- ---------------------------------------------------------------------------
-- GARDES — la migration echoue plutot que de poser un socle a moitie juste
-- ---------------------------------------------------------------------------
do $$
declare
  v_n integer;
  v_p jsonb;
begin
  -- 1. Les deux metiers existent, et pnj_metier_profil() les rend correctement.
  v_p := public.pnj_metier_profil('agent_securite');
  if v_p is null then raise exception 'agent_securite absent de pnj_metiers_profils'; end if;
  if (v_p->>'PER')::int <> 12 or (v_p->>'VOL')::int <> 16 then
    raise exception 'agent_securite : PER/VOL non conformes a l''arbitrage (% / %)',
      v_p->>'PER', v_p->>'VOL';
  end if;

  v_p := public.pnj_metier_profil('maitre_chien');
  if v_p is null then raise exception 'maitre_chien absent de pnj_metiers_profils'; end if;
  if (v_p->>'PER')::int <> 16 or (v_p->>'VOL')::int <> 14 then
    raise exception 'maitre_chien : PER/VOL non conformes a l''arbitrage (% / %)',
      v_p->>'PER', v_p->>'VOL';
  end if;

  -- 2. Les six clefs du referentiel sont toutes servies, sans trou.
  if (select count(*) from jsonb_object_keys(public.pnj_metier_profil('agent_securite'))) <> 6 then
    raise exception 'agent_securite ne rend pas les six caracteristiques';
  end if;

  -- 3. AUCUN AUTRE METIER N'A BOUGE. Les huit profils d'avant ce lot sont
  --    compares a leurs valeurs connues, une par une.
  select count(*) into v_n from public.pnj_metiers_profils
   where (metier, car_int, car_cha, car_vol, car_per, car_dup, car_ent) in (
     ('agent',       13, 12, 12, 13, 13, 10),
     ('codetenu',    10, 10, 10, 12, 12, 10),
     ('douanier',    10,  8, 12, 12,  8, 10),
     ('escort',      10, 15, 10, 10, 12, 10),
     ('informateur', 10, 10,  8, 15, 12,  8),
     ('militant',     9, 12, 15,  9,  8, 12),
     ('policier',    10,  8, 12, 12,  8, 10),
     ('soldat',       9,  8, 12, 10,  8, 12));
  if v_n <> 8 then
    raise exception 'un metier preexistant a change : % profils intacts sur 8', v_n;
  end if;

  -- 4. Le recrutement reste FERME pour les deux nouveaux metiers.
  if 'agent_securite' = any (public.employe_metiers_recrutables())
     or 'maitre_chien' = any (public.employe_metiers_recrutables()) then
    raise exception 'un des nouveaux metiers est devenu recrutable : ce lot ne doit pas l''ouvrir';
  end if;

  -- 5. Aucun PNJ n'a ete cree, et aucun ne porte ces metiers.
  select count(*) into v_n from public.pnj_employes_metier
   where job in ('agent_securite', 'maitre_chien');
  if v_n <> 0 then
    raise exception 'ce lot ne doit creer aucun PNJ (% trouve[s])', v_n;
  end if;
end $$;

commit;
