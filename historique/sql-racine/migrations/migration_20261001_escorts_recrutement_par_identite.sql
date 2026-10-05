-- ===========================================================================
-- RECRUTER UNE PERSONNE, ET NON UN GENRE (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- CE QUI CHANGE. Le recrutement portait sur un NOM LIBRE transmis par le
-- navigateur, et le serveur n'autorisait qu'une escort par genre. Il porte
-- desormais sur un `escort_id` du catalogue, valide contre une liste fermee, et
-- le quota par genre disparait : un joueur fortune peut s'entourer de plusieurs
-- escorts, ce qui etait la demande de game design.
--
-- L'IDENTIFIANT D'EMPLOI DERIVE DE L'IDENTITE, PLUS DU NOM. `employe_pnj_id`
-- recoit l'escort_id a la place du nom affiche. Consequence : renommer une
-- escort ne casse aucun contrat en cours. Et comme l'identifiant reste construit
-- sur (proprietaire, escort), deux joueurs qui emploient la meme personne
-- produisent deux lignes distinctes -- l'exigence multijoueur est satisfaite par
-- la forme de la cle, sans regle supplementaire.
--
-- LE NOM DE L'AGENCE VIENT DE LA DONNEE. `employe_recruter` ecrivait en dur
-- « Escort — Agence Roxane Velours » pour les quatre empires. Le libelle est
-- desormais lu dans escorts_agences, donc propre a l'empire, conformement a la
-- regle de socle : les mecaniques se mutualisent, les contenus jamais.
--
-- L'ANCIENNE PORTE EST FERMEE AU SERVEUR, pas seulement debranchee du client.
-- `escort` sort de la liste des metiers que `employe_recruter` accepte : elle y
-- rend desormais `metier_non_recrutable`. Laisser vivre une seconde
-- implementation de la meme regle -- avec son quota par genre -- serait
-- exactement la dette que ce chantier supprime.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. L'EMPLOI SAIT QUELLE IDENTITE IL INSTANCIE
-- ---------------------------------------------------------------------------
-- Nullable : les informateurs n'ont pas de catalogue d'identites (leur propre
-- dette, hors perimetre de ce lot).
alter table public.pnj_employes_metier
  add column if not exists escort_id text;

comment on column public.pnj_employes_metier.escort_id is
  'Identite du catalogue que cet emploi instancie, pour le metier escort. Nul pour les autres metiers. C''est ce qui relie un contrat a une personne, et permet a deux joueurs d''employer la meme sans collision.';

update public.pnj_metiers_profils
   set quota_note = 'Aucun quota par genre depuis le 1er octobre 2026 : plusieurs escorts par joueur, c''est le game design. Seul subsiste le plafond commun de 10 employes.'
 where metier = 'escort';

-- ---------------------------------------------------------------------------
-- 2. RECRUTER UNE IDENTITE
-- ---------------------------------------------------------------------------
create or replace function public.escort_recruter(p_escort_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  c_max_employes constant integer := 10;
  v_moi text; v_pays text; v_agence text; v_id text;
  v_esc  public.escorts_catalogue%ROWTYPE;
  v_prof public.pnj_metiers_profils%ROWTYPE;
  v_deja integer; v_pay jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  -- L'EMPIRE N'EST PAS UN PARAMETRE : il vient de la position du joueur. Un
  -- client ne peut donc pas recruter une escort d'un empire ou il ne se trouve pas.
  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO v_esc FROM public.escorts_catalogue
   WHERE escort_id = p_escort_id AND pays = v_pays AND actif;
  IF v_esc.escort_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'escort_inconnue'); END IF;

  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = 'escort';
  IF v_prof.metier IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;

  -- PLAFOND COMMUN A TOUS LES EMPLOYES, informateurs compris. C'est le seul
  -- quota qui subsiste.
  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'employe' AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_max_employes THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_employes',
                              'plafond', c_max_employes); END IF;

  -- L'identifiant derive de l'IDENTITE et du proprietaire. Employer deux fois la
  -- meme personne est donc impossible par construction ; deux joueurs qui
  -- l'emploient produisent deux lignes differentes.
  v_id := public.employe_pnj_id(v_moi, 'escort', p_escort_id);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_employee',
                              'pnj_id', v_id, 'nom', v_esc.nom); END IF;

  v_pay := public.debiter_fonds_ordinaires(v_moi, v_prof.cout_initial);
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse',
                              'paiement', v_pay, 'cout', v_prof.cout_initial); END IF;

  SELECT nom INTO v_agence FROM public.escorts_agences WHERE pays = v_pays;

  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
                                  leader_pj, pa, statut,
                                  car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'employe', 'beta', v_esc.nom, v_pays, v_moi, v_moi, 12, 'actif',
          v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
          v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
    statut = 'actif', nom = EXCLUDED.nom,
    proprietaire_pj = EXCLUDED.proprietaire_pj, leader_pj = EXCLUDED.leader_pj,
    ville = NULL, building_id = NULL, room_id = NULL,
    car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
    car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
    maj_le = now();

  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour, genre,
                                          escort_id, depuis_jour)
  VALUES (v_id, 'escort',
          'Escort — ' || coalesce(v_agence, 'Agence'),
          v_prof.cout_jour, v_esc.genre, v_esc.escort_id, NULL)
  ON CONFLICT (pnj_id) DO UPDATE SET
    job = EXCLUDED.job, role_libelle = EXCLUDED.role_libelle,
    cout_jour = EXCLUDED.cout_jour, genre = EXCLUDED.genre,
    escort_id = EXCLUDED.escort_id;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id,
    'escort_id', v_esc.escort_id, 'nom', v_esc.nom, 'genre', v_esc.genre,
    'portrait', v_esc.portrait, 'vignette', v_esc.vignette, 'cadrage', v_esc.cadrage,
    'agence', v_agence, 'cout_jour', v_prof.cout_jour, 'cout_initial', v_prof.cout_initial,
    'caracteristiques', public.pnj_metier_profil('escort'),
    'paiement', v_pay, 'employes', v_deja + 1, 'plafond', c_max_employes);
END;
$fn$;

comment on function public.escort_recruter(text) is
  'Engage une escort du catalogue de l''empire OU SE TROUVE le joueur. Aucun quota par genre : plusieurs escorts par joueur. L''identifiant d''emploi derive de (proprietaire, escort_id), donc deux joueurs peuvent employer la meme personne, et un meme joueur ne peut pas l''employer deux fois. Le libelle de role vient de escorts_agences, jamais d''un litteral.';

revoke all on function public.escort_recruter(text) from public, anon;
grant execute on function public.escort_recruter(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. FERMETURE DE L'ANCIENNE PORTE
-- ---------------------------------------------------------------------------
-- PAS DE CHIRURGIE SUR employe_recruter. Cette fonction porte des regles
-- anciennes qu'il serait facile de perdre en la retapant, et une retouche de
-- texte sur son corps serait fragile. Elle possede heureusement un point
-- d'extension : elle refuse tout metier absent de employe_metiers_recrutables(),
-- dont elle est l'unique lectrice. Retirer `escort` de cette liste ferme donc la
-- porte au SERVEUR -- pas seulement dans le navigateur -- en reecrivant deux
-- lignes d'une fonction triviale.
--
-- Un appel a employe_recruter('escort', ...) rend desormais `metier_non_recrutable`
-- en nommant les metiers restants. Le quota par genre qui vit encore dans son
-- corps devient inatteignable pour les escorts : il n'y a plus deux
-- implementations concurrentes de la meme regle.
create or replace function public.employe_metiers_recrutables()
returns text[]
language sql
immutable
as $fn$
  -- codetenu volontairement exclu : metier prevu, jamais active.
  -- escort retire le 1er octobre 2026 : elle se recrute par son identite, via
  -- escort_recruter(escort_id), qui valide contre le catalogue de l'empire.
  SELECT ARRAY['informateur']::text[];
$fn$;

comment on function public.employe_metiers_recrutables() is
  'Metiers que employe_recruter accepte encore. `escort` en a ete retire le 1er octobre 2026 : elle passe par escort_recruter(escort_id). Liste fermee : ajouter un metier ici l''ouvre au chemin generique.';
