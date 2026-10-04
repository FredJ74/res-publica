-- ===========================================================================
-- GROBRAS SECURITE — LOT 3 : LE PREMIER EMPLOYEUR DU JEU
-- 5 octobre 2026
-- ---------------------------------------------------------------------------
-- CE LOT NE CREE PAS « LE RECRUTEMENT GROBRAS ». Il cree le socle d'embauche
-- des agences, et Grobras en est la PREMIERE LIGNE DE DONNEES. C'est la
-- contrainte posee par Fred, et elle commande toute la forme du fichier :
--
--   « Le systeme doit rester totalement generique. Aucune hypothese ne doit
--     etre faite sur le fait que Grobras sera l'unique agence. Demain, une
--     agence creee par un joueur devra pouvoir reutiliser exactement le meme
--     socle de recrutement sans modification d'architecture. »
--
-- Test de genericite applique a chaque ligne ecrite ici : « si une deuxieme
-- agence ouvrait demain, faudrait-il modifier du CODE ? » Reponse exigee :
-- non, seulement des DONNEES (une ligne dans pnj_employeurs, N lignes dans
-- pnj_candidats_catalogue). Le mot « grobras » n'apparait donc dans AUCUN
-- corps de fonction : uniquement dans les inserts de donnees de la section 8.
--
-- ---------------------------------------------------------------------------
-- L'ERREUR D'ARCHITECTURE QUE CE LOT CORRIGE, ET NE CONTOURNE PAS
-- ---------------------------------------------------------------------------
-- Demande explicite de Fred : « Aujourd'hui le navigateur reutilise le cout
-- d'embauche comme cout journalier. Je ne souhaite pas contourner ce probleme.
-- Je souhaite le corriger proprement. »
--
-- En cherchant le defaut annonce, on en a trouve TROIS, dont deux cote serveur :
--
--   1. employe_recruter recoit `p_cost` DEPUIS LE NAVIGATEUR. Le prix
--      d'embauche voyageait donc dans la requete. payer_ordre le revalidait
--      contre le miroir de data.js, ce n'etait donc pas une faille -- mais
--      c'etait une source de verite de trop, et c'est de la que vient la
--      confusion : un seul nombre circulait pour deux notions.
--      => CORRIGE : employeur_embaucher(candidat_id) ne prend QUE l'identite.
--         Le prix et les PA sont lus par le SERVEUR dans ordres_couts, qui est
--         deja la reference de payer_ordre. Le navigateur ne transmet plus
--         aucun montant. C'est le principe des escortes, pousse d'un cran.
--
--   2. `pnj_metiers_profils.pa_initial` N'EST PAS les PA du PNJ : c'est le
--      COUT EN PA DE L'ACTE DE RECRUTEMENT (employe_recruter en fait
--      `COALESCE(p_pa, pa_initial, 0)` puis le passe a payer_ordre). Preuve
--      par les valeurs deployees : escort 0 (son bouton n'est pas un ordre),
--      informateur 1 (son ordre coute 1 PA), militant 2, tous les autres 0.
--      Les PA du PNJ, eux, viennent du DEFAUT de la colonne pnj_membres.pa
--      (12 = pnj_pa_max()).
--      => Le lot 2 avait donc pose `pa_initial = 12` sur un contresens : un
--         agent aurait coute DOUZE PA a embaucher. Corrige a 1, qui est
--         exactement l'arbitrage rendu (« L'ordre de recrutement coute 1 PA
--         pour les deux metiers »). La garde 9.4 verifie desormais que
--         pa_initial egale le PA declare dans ordres_couts, pour que le
--         contresens ne puisse plus revenir en silence.
--
--   3. Cote navigateur, doRecruterInformateurPNJ ecrivait le prix de l'ordre
--      dans `state.employes[].cout`, que payerEmployes() preleve CHAQUE NUIT.
--      Invisible jusqu'ici parce que l'informateur vaut 150 a l'embauche ET
--      150 par jour ; mortel avec 500 et 0. Corrige dans plateau-multijoueur.js
--      au meme commit, en alignant l'informateur sur ce que les escortes
--      faisaient deja juste : `cout: r.cout_jour`.
--
-- Consequence des trois : cout d'embauche et cout journalier sont desormais
-- stockes separement (cout_initial / cout_jour), lus separement et utilises
-- separement, du referentiel jusqu'au reveil du joueur.
--
-- ---------------------------------------------------------------------------
-- CE QUE CE LOT NE FAIT PAS
-- ---------------------------------------------------------------------------
-- Aucune mission, aucune affectation, aucun deplacement, aucune protection de
-- batiment, aucune surveillance, aucun malus de vol, aucun appel police,
-- aucune bagarre, aucun garde du corps PJ, aucune rupture automatique, aucun
-- prelevement quotidien (cout_jour = 0 pour les deux metiers : « Le joueur ne
-- doit subir aucun prelevement quotidien dans ce lot »).
--
-- escort_recruter N'EST PAS TOUCHEE : elle tourne en production avec son
-- interface, et la faire passer par la porte generique est un lot a part,
-- prouvable separement. Elle est la DERNIERE porte specifique ; il n'en sera
-- pas creee de troisieme, et c'est tout l'objet de la section 5.
-- ===========================================================================

begin;

-- ===========================================================================
-- 1. LE REFERENTIEL DES METIERS PORTE DESORMAIS LES REGLES D'EMBAUCHE
-- ---------------------------------------------------------------------------
-- Cinq colonnes, et chacune remplace une decision aujourd'hui CODEE EN DUR
-- dans un corps de fonction. C'est la condition de la genericite : ouvrir un
-- metier a une agence future doit etre un INSERT, pas un patch de fonction.
--
--   classe           : la classe du PNJ a sa creation. employe_recruter posait
--                      'beta' en dur. pnj_classe_de() prend l'individu
--                      d'abord, donc un `employe` peut etre alpha sans
--                      promouvoir la famille -- c'est le cran prevu par le
--                      socle depuis le 27 septembre, jamais franchi.
--                      NECESSAIRE, pas decoratif : pnj_pa_garde() refuse toute
--                      variation de PA hors alpha.
--   role_libelle     : le libelle du METIER, sans l'agence. L'agence est
--                      concatenee a l'embauche (« Agent de securite — Grobras
--                      Securite »), comme escort_recruter le fait deja avec
--                      escorts_agences.nom. Un CASE en dur sur le nom du
--                      metier n'aurait pas survecu a la deuxieme agence.
--   recrutable       : remplace le ARRAY['informateur'] litteral de
--                      employe_metiers_recrutables(). Ouvrir un metier
--                      devient une donnee.
--   quota_par_joueur : remplace le test « EXISTS => quota_metier_atteint »,
--                      qui supposait UN SEUL representant par metier. Fred :
--                      « Le moteur ne doit pas supposer qu'un metier n'a qu'un
--                      seul representant. » NULL vaut 1 : le comportement
--                      actuel de l'informateur est donc preserve a l'identique.
--   ordre_fn         : l'ordre declare par lequel ce metier s'embauche. C'est
--                      lui qui permet au SERVEUR d'aller chercher le prix dans
--                      ordres_couts au lieu de le recevoir du navigateur.
-- ===========================================================================

alter table public.pnj_metiers_profils
  add column if not exists classe           text,
  add column if not exists role_libelle     text,
  add column if not exists recrutable       boolean not null default false,
  add column if not exists quota_par_joueur integer,
  add column if not exists ordre_fn         text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'pnj_metiers_profils_classe_connue') then
    alter table public.pnj_metiers_profils
      add constraint pnj_metiers_profils_classe_connue
      check (classe is null or classe in ('alpha', 'beta', 'gamma'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'pnj_metiers_profils_quota_positif') then
    alter table public.pnj_metiers_profils
      add constraint pnj_metiers_profils_quota_positif
      check (quota_par_joueur is null or quota_par_joueur >= 1);
  end if;
end $$;


-- ---------------------------------------------------------------------------
-- 1b. LES METIERS DEJA EN PRODUCTION DECLARENT CE QU'ILS FAISAIENT DEJA
-- ---------------------------------------------------------------------------
-- AUCUN CHANGEMENT DE COMPORTEMENT ICI, et c'est le point : on inscrit dans le
-- referentiel ce que le code en dur decidait, pour pouvoir ensuite supprimer le
-- code en dur sans rien deplacer. informateur etait le seul recrutable, en
-- beta, libelle « Informateur », quota 1, ordre a 1 PA / 150 FR. La garde 9.9
-- verifie qu'il n'a rien perdu.
update public.pnj_metiers_profils set
  classe           = 'beta',
  role_libelle     = 'Informateur',
  recrutable       = true,
  quota_par_joueur = 1,
  ordre_fn         = 'recruter_informateur_pnj'
 where metier = 'informateur';

-- escort : NON recrutable par cette porte (retiree le 1er octobre, elle passe
-- par escort_recruter). Son quota reste NULL : sa regle est particuliere -- une
-- par GENRE -- et elle reste codee dans employe_recruter, inchangee. Le libelle
-- est pose pour que la porte generique puisse la servir le jour ou les deux
-- moteurs convergeront.
update public.pnj_metiers_profils set
  classe       = 'beta',
  role_libelle = 'Escort'
 where metier = 'escort';

-- codetenu : metier prevu, jamais active. Reste non recrutable, comme avant.
update public.pnj_metiers_profils set classe = 'beta', role_libelle = 'Codétenu'
 where metier = 'codetenu';

-- Les metiers de la force publique et de l'armee ne s'embauchent pas chez un
-- joueur : ils ne sont pas recrutables et n'ont pas d'ordre. On ne leur pose
-- qu'un libelle lisible, pour les ecrans qui affichent un metier.
update public.pnj_metiers_profils as pr set role_libelle = x.lib
  from (values ('agent', 'Agent de renseignement'), ('douanier', 'Douanier'),
               ('militant', 'Militant'), ('policier', 'Policier'),
               ('soldat', 'Soldat')) as x(m, lib)
 where pr.metier = x.m;


-- ---------------------------------------------------------------------------
-- 1c. LES DEUX METIERS DE SECURITE RECOIVENT LEURS ARBITRAGES
-- ---------------------------------------------------------------------------
-- Arbitrages rendus par Fred le 5 octobre 2026, et rien d'autre :
--   prix d'embauche  : agent 500 FR, maitre-chien 700 FR (« frais d'embauche,
--                      ce ne sont pas les salaires journaliers ») ;
--   cout en PA       : 1 pour les deux ;
--   quotas           : 4 agents, 2 maitres-chiens par joueur ;
--   cout journalier  : NUL pour ce lot, le mecanisme n'etant pas arbitre.
--
-- cout_jour passe de NULL a 0, et ce n'est pas un detail de typage. Au lot 2,
-- NULL disait « tarif non arbitre » -- c'etait vrai, et 0 aurait menti. Fred a
-- depuis tranche : « conserver un cout journalier nul tant que ce mecanisme
-- n'est pas encore arbitre. Le joueur ne doit subir aucun prelevement
-- quotidien. » 0 est donc desormais la valeur VRAIE : zero est arbitre.
--
-- pa_initial passe de 12 a 1 : correction du contresens du lot 2 expose en
-- tete de fichier. Les 12 PA du PNJ viennent du defaut de pnj_membres.pa.
--
-- La classe alpha est ce qui donne a ces PNJ le droit de depenser des PA
-- (pnj_pa_garde), et elle est posee sur l'INDIVIDU a sa creation : escortes et
-- informateurs restent beta, la famille `employe` n'est pas promue.
--
-- Les six caracteristiques ne sont PAS touchees : elles ont ete arbitrees au
-- lot 2 et la garde 9.2 verifie qu'aucune n'a bouge.
update public.pnj_metiers_profils set
  classe           = 'alpha',
  role_libelle     = 'Agent de sécurité',
  recrutable       = true,
  quota_par_joueur = 4,
  ordre_fn         = 'embaucher_agent_securite',
  pa_initial       = 1,
  cout_initial     = 500,
  cout_jour        = 0,
  quota_note       = 'Quota 4 par joueur (arbitrage GD du 5 octobre 2026), porte par quota_par_joueur et applique par employeur_embaucher. Le plafond commun de 10 employes s''applique en plus, pas a la place.'
 where metier = 'agent_securite';

update public.pnj_metiers_profils set
  classe           = 'alpha',
  role_libelle     = 'Maître-chien',
  recrutable       = true,
  quota_par_joueur = 2,
  ordre_fn         = 'embaucher_maitre_chien',
  pa_initial       = 1,
  cout_initial     = 700,
  cout_jour        = 0,
  quota_note       = 'Quota 2 par joueur (arbitrage GD du 5 octobre 2026). Le chien n''est PAS un PNJ : il fait partie du maitre, comme le cynophile de la police n''a jamais eu de ligne propre. Son nom vit dans l''accroche du candidat.'
 where metier = 'maitre_chien';


-- ===========================================================================
-- 2. LE REGISTRE DES EMPLOYEURS
-- ---------------------------------------------------------------------------
-- Une agence est une LIGNE, pas un cas particulier. Trois champs portent toute
-- la genericite demandee :
--
--   pays            : un casting n'existe jamais hors de son empire (regle de
--                     socle du 1er octobre). Le serveur refuse une agence d'un
--                     autre empire, comme escorts_agence le fait deja.
--   caisse_id       : facultatif. Les frais d'embauche y sont credites quand il
--                     est renseigne. Une agence sans caisse est un etat valide,
--                     et le code le traite comme tel.
--   proprietaire_pj : NULL = agence du decor. C'EST LE POINT D'EXTENSION de
--                     « demain, une agence creee par un joueur » : il n'y aura
--                     rien a modifier, seulement ce champ a remplir.
-- ===========================================================================

create table if not exists public.pnj_employeurs (
  employeur_id    text primary key,
  pays            text    not null,
  nom             text    not null,
  caisse_id       text,
  proprietaire_pj text,
  actif           boolean not null default true,
  note            text,
  cree_le         timestamptz not null default now()
);

alter table public.pnj_employeurs enable row level security;
revoke all on public.pnj_employeurs from anon, authenticated;
grant  all on public.pnj_employeurs to service_role;


-- ---------------------------------------------------------------------------
-- 2b. LE CATALOGUE D'IDENTITES
-- ---------------------------------------------------------------------------
-- « Je ne veux pas de catalogue JavaScript. Je souhaite reprendre exactement le
--   principe retenu pour les escortes. Les identites doivent vivre cote
--   serveur. Aucune liste de noms codee dans le navigateur. »
--
-- Modele : escorts_catalogue. Trois differences, chacune motivee :
--
--   la clef est (employeur, metier) et non (pays, genre) : c'est ce qui rend la
--   table utilisable par n'importe quelle agence pour n'importe quel metier, au
--   lieu d'etre la table d'un seul metier ;
--
--   portrait / vignette / cadrage sont NULLABLE, alors qu'ils sont NOT NULL
--   chez les escortes : une escort se choisit sur un visage, un vigile derriere
--   un comptoir n'en a pas besoin, et Fred a valide au lot 1 que ces PNJ
--   prennent l'icone de leur metier. Un portrait reste possible plus tard, sans
--   migration ;
--
--   `accroche` : une ligne de presentation libre. Pour un maitre-chien, c'est
--   la ou vit le nom du chien -- le chien n'etant PAS un PNJ (precedent du
--   cynophile de la police, qui n'a jamais eu de ligne propre).
-- ---------------------------------------------------------------------------

create table if not exists public.pnj_candidats_catalogue (
  candidat_id  text primary key,
  employeur_id text    not null references public.pnj_employeurs(employeur_id) on delete cascade,
  metier       text    not null references public.pnj_metiers_profils(metier),
  nom          text    not null,
  genre        text,
  accroche     text,
  portrait     text,
  vignette     text,
  cadrage      text,
  rang         integer not null default 0,
  actif        boolean not null default true,
  constraint pnj_candidat_genre_connu check (genre is null or genre in ('H', 'F'))
);

create index if not exists idx_pnj_candidats_employeur
  on public.pnj_candidats_catalogue (employeur_id, metier, rang, nom);

alter table public.pnj_candidats_catalogue enable row level security;
revoke all on public.pnj_candidats_catalogue from anon, authenticated;
grant  all on public.pnj_candidats_catalogue to service_role;


-- L'EMPLOYE GARDE LE LIEN VERS SON IDENTITE DE CATALOGUE, exactement comme
-- pnj_employes_metier.escort_id le fait pour les escortes. Sans lui, le
-- comptoir ne saurait pas qui est deja a votre service, et un joueur se verrait
-- proposer un agent qu'il emploie.
alter table public.pnj_employes_metier
  add column if not exists candidat_id text references public.pnj_candidats_catalogue(candidat_id);


-- ===========================================================================
-- 3. employe_metiers_recrutables() LIT LE REFERENTIEL
-- ---------------------------------------------------------------------------
-- Elle rendait un ARRAY litteral. Elle rend maintenant ce que le referentiel
-- declare, ce qui fait d'« ouvrir un metier » une donnee et non un deploiement.
-- Passe IMMUTABLE -> STABLE (elle lit une table) et SECURITY DEFINER (pour
-- rester appelable meme sans droit de lecture sur le referentiel : elle ne rend
-- qu'une liste de mots de metier, rien de sensible).
-- ===========================================================================
create or replace function public.employe_metiers_recrutables()
returns text[]
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  -- codetenu : metier prevu, jamais active (recrutable = false).
  -- escort : retiree de cette porte le 1er octobre 2026, elle se recrute par
  -- son identite via escort_recruter(escort_id).
  select coalesce(array_agg(metier order by metier), array[]::text[])
    from public.pnj_metiers_profils
   where recrutable;
$$;


-- ===========================================================================
-- 4. LE COMPTOIR : CE QUE L'AGENCE A A PRESENTER
-- ---------------------------------------------------------------------------
-- Calque de escorts_agence(). Le navigateur ne connait qu'un employeur_id, pose
-- dans l'ordre de data.js ; tout le reste vient de la base : les noms, les
-- prix, les quotas, les caracteristiques, et qui est deja a votre service.
--
-- `metiers` porte quota et deja-employes : le comptoir peut donc afficher
-- « 2 places sur 4 » sans jamais recalculer une regle cote navigateur. Un
-- navigateur qui recalcule une regle est un navigateur qui finira par la
-- contredire.
-- ===========================================================================
create or replace function public.employeur_candidats(p_employeur_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  c_max_employes constant integer := 10;
  v_moi text; v_pays text;
  v_emp public.pnj_employeurs%rowtype;
  v_deja integer;
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); end if;

  select coalesce(country, 'republic') into v_pays
    from public.personnages_donnees where name = v_moi;

  select * into v_emp from public.pnj_employeurs
   where employeur_id = p_employeur_id and pays = v_pays and actif;
  if v_emp.employeur_id is null then
    return jsonb_build_object('ok', false, 'raison', 'employeur_inconnu'); end if;

  select count(*) into v_deja from public.pnj_membres m
   where m.famille = 'employe' and m.proprietaire_pj = v_moi and m.statut = 'actif';

  return jsonb_build_object(
    'ok', true,
    'employeur_id', v_emp.employeur_id,
    'employeur', v_emp.nom,
    'pays', v_pays,
    'plafond_employes', c_max_employes,
    'employes_actuels', v_deja,

    'metiers', coalesce((
      select jsonb_agg(jsonb_build_object(
               'metier',           pr.metier,
               'libelle',          pr.role_libelle,
               'recrutable',       pr.recrutable,
               'cout_embauche',    coalesce(pr.cout_initial, 0),
               'cout_jour',        coalesce(pr.cout_jour, 0),
               'pa',               coalesce(pr.pa_initial, 0),
               'quota',            coalesce(pr.quota_par_joueur, 1),
               'employes',         (select count(*) from public.pnj_membres m
                                      join public.pnj_employes_metier e on e.pnj_id = m.id
                                     where m.proprietaire_pj = v_moi and m.statut = 'actif'
                                       and e.job = pr.metier),
               'caracteristiques', public.pnj_metier_profil(pr.metier))
             order by pr.metier)
        from public.pnj_metiers_profils pr
       where pr.metier in (select c.metier from public.pnj_candidats_catalogue c
                            where c.employeur_id = v_emp.employeur_id and c.actif)
    ), '[]'::jsonb),

    'candidats', coalesce((
      select jsonb_agg(jsonb_build_object(
               'candidat_id',  c.candidat_id,
               'metier',       c.metier,
               'nom',          c.nom,
               'genre',        c.genre,
               'accroche',     c.accroche,
               'portrait',     c.portrait,
               'vignette',     c.vignette,
               'cadrage',      c.cadrage,
               'deja_employe', exists (select 1 from public.pnj_membres m
                                         join public.pnj_employes_metier e on e.pnj_id = m.id
                                        where m.proprietaire_pj = v_moi and m.statut = 'actif'
                                          and e.candidat_id = c.candidat_id))
             order by c.metier, c.rang, c.nom)
        from public.pnj_candidats_catalogue c
       where c.employeur_id = v_emp.employeur_id and c.actif
    ), '[]'::jsonb));
end;
$$;


-- ===========================================================================
-- 5. EMBAUCHER — LA PORTE GENERIQUE
-- ---------------------------------------------------------------------------
-- UN SEUL ARGUMENT : une identite. Ni metier, ni nom, ni genre, ni PA, ni prix.
-- C'est la correction du point 1 de l'en-tete : le navigateur ne transmet plus
-- aucun montant, et n'a donc plus rien a confondre. Le serveur resout le
-- candidat, son employeur, son metier, son ordre, et lit le prix dans
-- ordres_couts -- la meme table que payer_ordre revalide ensuite.
--
-- POURQUOI CETTE FONCTION ET PAS UNE TROISIEME COPIE. employe_recruter et
-- escort_recruter sont deja deux fois le meme corps de 70 lignes. Ecrire
-- « agent_securite_recruter » aurait fait trois, et la consigne etait de ne
-- creer aucun moteur nouveau si une brique equivalente existe. Celle-ci est
-- donc la generalisation des deux : meme ordre d'operations que
-- escort_recruter, mais l'agence, le metier, le quota, la classe, le libelle et
-- le prix sont LUS au lieu d'etre connus.
--
-- Ordre des operations, repris de escort_recruter : tout ce qui peut refuser
-- refuse AVANT le premier debit, et la creation suit dans la MEME transaction.
-- Un refus ne laisse ni argent preleve, ni employe orphelin.
-- ===========================================================================
create or replace function public.employeur_embaucher(p_candidat_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  c_max_employes constant integer := 10;
  v_moi text; v_pays text; v_id text; v_libelle text;
  v_cand public.pnj_candidats_catalogue%rowtype;
  v_emp  public.pnj_employeurs%rowtype;
  v_prof public.pnj_metiers_profils%rowtype;
  v_deja integer; v_quota integer; v_nb integer;
  v_pa integer; v_cost integer; v_pay jsonb; v_caisse jsonb := null;
begin
  v_moi := public.mon_personnage();
  if v_moi is null then
    return jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); end if;

  select coalesce(country, 'republic') into v_pays
    from public.personnages_donnees where name = v_moi;

  -- 5.1 L'IDENTITE EXISTE-T-ELLE ?
  select * into v_cand from public.pnj_candidats_catalogue
   where candidat_id = p_candidat_id and actif;
  if v_cand.candidat_id is null then
    return jsonb_build_object('ok', false, 'raison', 'candidat_inconnu'); end if;

  -- 5.2 L'AGENCE EXISTE-T-ELLE, ET DANS MON EMPIRE ?
  select * into v_emp from public.pnj_employeurs
   where employeur_id = v_cand.employeur_id and actif;
  if v_emp.employeur_id is null then
    return jsonb_build_object('ok', false, 'raison', 'employeur_inconnu'); end if;
  if v_emp.pays <> v_pays then
    return jsonb_build_object('ok', false, 'raison', 'employeur_hors_pays'); end if;

  -- 5.3 LE METIER EST-IL OUVERT ? Lu au referentiel, pas en dur.
  select * into v_prof from public.pnj_metiers_profils where metier = v_cand.metier;
  if v_prof.metier is null then
    return jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); end if;
  if not v_prof.recrutable then
    return jsonb_build_object('ok', false, 'raison', 'metier_non_recrutable',
                              'metier', v_cand.metier); end if;

  -- 5.4 LE PLAFOND COMMUN DE 10 EMPLOYES, toutes agences et tous metiers
  --     confondus. Il ne remplace pas le quota : il s'y ajoute.
  select count(*) into v_deja from public.pnj_membres m
   where m.famille = 'employe' and m.proprietaire_pj = v_moi and m.statut = 'actif';
  if v_deja >= c_max_employes then
    return jsonb_build_object('ok', false, 'raison', 'plafond_employes',
                              'plafond', c_max_employes); end if;

  -- 5.5 LE QUOTA PAR METIER, LU AU REFERENTIEL. NULL vaut 1 : l'ancienne regle
  --     en dur devient un defaut, et cesse d'etre une hypothese.
  v_quota := coalesce(v_prof.quota_par_joueur, 1);
  select count(*) into v_nb from public.pnj_membres m
    join public.pnj_employes_metier e on e.pnj_id = m.id
   where m.proprietaire_pj = v_moi and m.statut = 'actif' and e.job = v_cand.metier;
  if v_nb >= v_quota then
    return jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
      'metier', v_cand.metier, 'quota', v_quota, 'employes', v_nb); end if;

  -- 5.6 CETTE PERSONNE-LA EST-ELLE DEJA A MON SERVICE ? L'identifiant est
  --     derive du CANDIDAT, pas du nom : un candidat renomme garde son PNJ.
  v_id := public.employe_pnj_id(v_moi, v_cand.metier, v_cand.candidat_id);
  if exists (select 1 from public.pnj_membres where id = v_id and statut = 'actif') then
    return jsonb_build_object('ok', false, 'raison', 'deja_employe',
                              'pnj_id', v_id, 'nom', v_cand.nom); end if;

  -- 5.7 LE PRIX. Il n'arrive PAS du navigateur : il vient du REFERENTIEL
  --     (pa_initial / cout_initial), et le miroir des ordres ne sert qu'a le
  --     VALIDER. L'ordre des deux comptait :
  --
  --     ordres_couts a pour clef primaire (fn, pa, cost), PAS (fn) : un meme
  --     ordre peut donc etre declare a plusieurs tarifs selon l'endroit ou il
  --     est propose. Lire « le » prix d'un fn aurait choisi une ligne au
  --     hasard parmi plusieurs -- hypothese fausse que le socle ne doit pas
  --     faire. On lit donc le triplet au referentiel, source unique, et on
  --     exige qu'il soit declare : payer_ordre le revalidera de son cote, et
  --     la garde 9.4 verifie l'egalite a chaque migration.
  --
  --     Un metier sans ordre declare passe par le debit ordinaire, comme
  --     l'escort, dont le bouton n'est pas un ordre.
  if v_prof.ordre_fn is not null then
    v_pa   := coalesce(v_prof.pa_initial, 0);
    v_cost := coalesce(v_prof.cout_initial, 0);
    if not exists (select 1 from public.ordres_couts o
                    where o.fn = v_prof.ordre_fn and o.pa = v_pa and o.cost = v_cost) then
      return jsonb_build_object('ok', false, 'raison', 'ordre_non_declare',
                                'fn', v_prof.ordre_fn, 'pa', v_pa, 'cout', v_cost); end if;
    v_pay := public.payer_ordre(v_moi, v_prof.ordre_fn, v_pa, v_cost);
  else
    v_pa   := 0;
    v_cost := coalesce(v_prof.cout_initial, 0);
    if v_cost > 0 then v_pay := public.debiter_fonds_ordinaires(v_moi, v_cost);
                  else v_pay := jsonb_build_object('ok', true, 'montant', 0); end if;
  end if;
  if coalesce((v_pay->>'ok')::boolean, false) is not true then
    return jsonb_build_object('ok', false, 'raison', 'paiement_refuse',
                              'paiement', v_pay, 'cout', v_cost); end if;

  -- 5.8 LES FRAIS D'EMBAUCHE VONT A L'AGENCE, quand elle a une caisse.
  --     L'argent ne disparait pas : il change de main. `rp.caisse_interne`
  --     declare un mouvement serveur -- sans quoi la caisse, reservee au
  --     serveur, refuserait le mouvement. Une agence sans caisse est un etat
  --     valide : rien n'est credite, et l'embauche aboutit quand meme.
  if v_emp.caisse_id is not null and v_cost > 0 then
    perform set_config('rp.caisse_interne', 'on', true);
    v_caisse := public.caisse_institution_mouvement(v_emp.caisse_id, v_cost, false);
  end if;

  -- 5.9 LA CREATION. La classe vient du referentiel (alpha pour les metiers de
  --     securite, sans promouvoir la famille `employe`). Les PA ne sont PAS
  --     poses : le DEFAUT de la colonne (12 = pnj_pa_max()) fait autorite, et
  --     c'est lui qui doit evoluer si le socle change un jour.
  insert into public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      leader_pj, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  values (v_id, 'employe', coalesce(v_prof.classe, 'beta'), v_cand.nom, v_pays,
      v_moi, v_moi, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  on conflict (id) do update set
      statut = 'actif', nom = excluded.nom, classe = excluded.classe,
      proprietaire_pj = excluded.proprietaire_pj, leader_pj = excluded.leader_pj,
      ville = null, building_id = null, room_id = null,
      car_int = excluded.car_int, car_cha = excluded.car_cha, car_vol = excluded.car_vol,
      car_per = excluded.car_per, car_dup = excluded.car_dup, car_ent = excluded.car_ent,
      maj_le = now();

  -- 5.10 LE LIBELLE est compose : metier + agence. C'est ce qui permet au meme
  --      metier d'exister chez deux agences sans dupliquer une ligne de code.
  v_libelle := coalesce(v_prof.role_libelle, initcap(v_cand.metier)) || ' — ' || v_emp.nom;

  -- cout_jour est le COUT JOURNALIER, et lui seul. Le prix d'embauche (v_cost)
  -- n'entre pas ici : c'est tout l'objet de la correction demandee.
  insert into public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour,
      genre, photo_url, photo_pos, candidat_id, depuis_jour)
  values (v_id, v_cand.metier, v_libelle, coalesce(v_prof.cout_jour, 0),
      v_cand.genre, v_cand.portrait, v_cand.cadrage, v_cand.candidat_id, null)
  on conflict (pnj_id) do update set
      job = excluded.job, role_libelle = excluded.role_libelle,
      cout_jour = excluded.cout_jour, genre = excluded.genre,
      photo_url = excluded.photo_url, photo_pos = excluded.photo_pos,
      candidat_id = excluded.candidat_id;

  return jsonb_build_object('ok', true,
    'pnj_id', v_id, 'candidat_id', v_cand.candidat_id, 'metier', v_cand.metier,
    'nom', v_cand.nom, 'genre', v_cand.genre, 'accroche', v_cand.accroche,
    'portrait', v_cand.portrait, 'vignette', v_cand.vignette, 'cadrage', v_cand.cadrage,
    'role_libelle', v_libelle,
    'employeur_id', v_emp.employeur_id, 'employeur', v_emp.nom,
    'cout_embauche', v_cost, 'cout_jour', coalesce(v_prof.cout_jour, 0), 'pa', v_pa,
    'caracteristiques', public.pnj_metier_profil(v_cand.metier),
    'paiement', v_pay, 'caisse_agence', v_caisse,
    'employes', v_deja + 1, 'plafond', c_max_employes,
    'quota', v_quota, 'employes_metier', v_nb + 1);
end;
$$;

-- Les deux RPC sont appelees depuis le navigateur authentifie, comme
-- escorts_agence et escort_recruter. Elles sont SECURITY DEFINER et resolvent
-- l'acteur par mon_personnage() : aucune identite n'est transmise.
grant execute on function public.employeur_candidats(text) to anon, authenticated, service_role;
grant execute on function public.employeur_embaucher(text) to anon, authenticated, service_role;


-- ===========================================================================
-- 6. employe_recruter PERD SES DECISIONS EN DUR
-- ---------------------------------------------------------------------------
-- Cette porte reste celle de l'informateur (metier + nom, nom tire au sort dans
-- le navigateur). Elle n'est PAS supprimee et son comportement ne change pas
-- d'un iota pour l'informateur -- les valeurs du referentiel posees en 1b sont
-- exactement celles qu'elle appliquait en dur. Trois decisions passent du corps
-- de la fonction au referentiel :
--
--   la classe        : 'beta' en dur  ->  coalesce(profil.classe, 'beta')
--   le libelle       : CASE en dur    ->  coalesce(profil.role_libelle, CASE...)
--   le quota         : EXISTS (= 1)   ->  comptage contre quota_par_joueur
--
-- et une quatrieme corrige un refus brut : v_prof.cout_jour pouvait etre NULL
-- alors que pnj_employes_metier.cout_jour est NOT NULL -- le lot 2 avait fait
-- tomber la fonction sur un 23502 nu. coalesce(..., 0) le ferme.
--
-- La regle PARTICULIERE de l'escort -- une par genre, et non une par metier --
-- est conservee telle quelle : c'est une regle de jeu, pas un cas en dur a
-- generaliser, et elle ne concerne que cette porte.
-- ===========================================================================
create or replace function public.employe_recruter(
  p_metier text, p_nom text, p_genre text default null,
  p_fn text default null, p_pa integer default null, p_cost integer default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
DECLARE
  c_max_employes constant integer := 10;
  v_moi text; v_prof record; v_id text; v_nom text; v_pay jsonb;
  v_pa integer; v_cost integer; v_deja integer; v_quota integer; v_nb integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT (p_metier = ANY (public.employe_metiers_recrutables())) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'metier_non_recrutable',
      'metier', COALESCE(p_metier, '<NULL>'),
      'recrutables', public.employe_metiers_recrutables()); END IF;

  v_nom := btrim(COALESCE(p_nom, ''));
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;

  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = p_metier;
  IF v_prof IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;

  SELECT count(*) INTO v_deja
    FROM public.pnj_membres m WHERE m.famille = 'employe'
     AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_max_employes THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_employes',
      'plafond', c_max_employes); END IF;

  IF p_metier = 'escort' THEN
    -- REGLE PROPRE A L'ESCORT : une par genre, pas une par metier. Conservee.
    IF EXISTS (SELECT 1 FROM public.pnj_membres m
                 JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
                WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif'
                  AND e.job = 'escort' AND e.genre IS NOT DISTINCT FROM p_genre) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier, 'genre', p_genre); END IF;
  ELSE
    -- QUOTA GENERIQUE : plus aucune hypothese d'un representant unique.
    v_quota := COALESCE(v_prof.quota_par_joueur, 1);
    SELECT count(*) INTO v_nb FROM public.pnj_membres m
      JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
     WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif' AND e.job = p_metier;
    IF v_nb >= v_quota THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier, 'quota', v_quota, 'employes', v_nb); END IF;
  END IF;

  v_id := public.employe_pnj_id(v_moi, p_metier, v_nom);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_employe', 'pnj_id', v_id); END IF;

  v_pa   := COALESCE(p_pa,   v_prof.pa_initial,   0);
  v_cost := COALESCE(p_cost, v_prof.cout_initial, 0);
  IF p_fn IS NOT NULL THEN
    v_pay := public.payer_ordre(v_moi, p_fn, v_pa, v_cost);
  ELSIF v_cost > 0 THEN
    v_pay := public.debiter_fonds_ordinaires(v_moi, v_cost);
  ELSE
    v_pay := jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse', 'paiement', v_pay); END IF;

  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      leader_pj, pa, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'employe', COALESCE(v_prof.classe, 'beta'), v_nom,
      (SELECT COALESCE(country, 'republic') FROM public.personnages_donnees WHERE name = v_moi),
      v_moi, v_moi, 12, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
      statut = 'actif', classe = EXCLUDED.classe,
      proprietaire_pj = EXCLUDED.proprietaire_pj,
      leader_pj = EXCLUDED.leader_pj, ville = NULL, building_id = NULL, room_id = NULL,
      car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
      car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
      maj_le = now();

  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour, genre, depuis_jour)
  VALUES (v_id, p_metier,
          COALESCE(v_prof.role_libelle,
                   CASE p_metier WHEN 'escort' THEN 'Escort — Agence Roxane Velours'
                                 WHEN 'informateur' THEN 'Informateur'
                                 ELSE initcap(p_metier) END),
          COALESCE(v_prof.cout_jour, 0), p_genre, NULL)
  ON CONFLICT (pnj_id) DO UPDATE SET
      job = EXCLUDED.job, role_libelle = EXCLUDED.role_libelle,
      cout_jour = EXCLUDED.cout_jour, genre = EXCLUDED.genre;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id, 'metier', p_metier, 'nom', v_nom,
    'genre', p_genre, 'cout_jour', COALESCE(v_prof.cout_jour, 0),
    'cout_initial', v_cost, 'pa', v_pa,
    'caracteristiques', public.pnj_metier_profil(p_metier),
    'paiement', v_pay, 'employes', v_deja + 1, 'plafond', c_max_employes);
END; $$;


-- ===========================================================================
-- 7. LES DEUX ORDRES DECLARES (miroir de data.js)
-- ---------------------------------------------------------------------------
-- payer_ordre refuse tout triplet (fn, pa, cost) absent de ce miroir, avec
-- `cout_non_declare`. Ces deux lignes doivent donc etre RIGOUREUSEMENT egales
-- aux ordres poses dans data.js au meme commit -- la garde 9.4 le verifie
-- contre le referentiel, et le banc d'economie contre data.js lui-meme.
--
-- LA CLEF PRIMAIRE EST (fn, pa, cost), PAS (fn) : le miroir autorise un meme
-- ordre a plusieurs tarifs. `do nothing` est donc le bon conflit -- un `do
-- update` sur (fn) n'existe pas, et vouloir « corriger » un tarif ici
-- reviendrait a ajouter une ligne, pas a en modifier une. Si un tarif change
-- dans data.js, c'est une regeneration du miroir, pas un UPDATE a la main.
-- ===========================================================================
insert into public.ordres_couts (fn, pa, cost) values
  ('embaucher_agent_securite', 1, 500),
  ('embaucher_maitre_chien',   1, 700)
on conflict (fn, pa, cost) do nothing;


-- ===========================================================================
-- 8. GROBRAS SECURITE — LA PREMIERE LIGNE DE DONNEES
-- ---------------------------------------------------------------------------
-- A partir d'ici, plus une seule ligne de logique : uniquement des donnees. Si
-- une deuxieme agence ouvrait demain, c'est EXACTEMENT ce bloc, et lui seul,
-- qui serait a recopier.
-- ===========================================================================

-- 8.1 LA CAISSE, A ZERO. L'identifiant suit la convention `<pays>_<motif>`, et
--     le motif est volontairement PREFIXE `agence-` : la regle d'autorite posee
--     juste apres couvre donc toutes les agences futures d'un coup, sans
--     migration supplementaire. C'est la difference concrete entre une donnee
--     generique et un cas particulier.
insert into public.caisses_batiments (id, data, updated_at)
values ('republic_agence-grobras-securite', jsonb_build_object('solde', 0), now())
on conflict (id) do nothing;

-- 8.2 AUCUN POSTE NE PEUT DEBITER UNE CAISSE D'AGENCE. postes_debit = '{}' fait
--     repondre `caisse_reservee_au_serveur` a caisse_client_mouvement : seul le
--     serveur y touche, par les chemins qu'il declare (ici le credit des frais
--     d'embauche). Un tableau VIDE et un NULL ne disent pas la meme chose :
--     NULL ferait sauter toute verification d'autorite.
insert into public.caisses_autorites (motif, est_prefixe, postes_debit, note)
values ('agence-', true, '{}'::text[],
        'Agences privees (Grobras Securite et suivantes) : caisse reservee au serveur. Aucun poste public ne debite la caisse d''une entreprise privee.')
on conflict (motif) do update set
  est_prefixe  = excluded.est_prefixe,
  postes_debit = excluded.postes_debit,
  note         = excluded.note;

-- 8.3 L'AGENCE. proprietaire_pj reste NULL : agence du decor, pas d'un joueur.
insert into public.pnj_employeurs (employeur_id, pays, nom, caisse_id, proprietaire_pj, actif, note)
values ('grobras-securite', 'republic', 'Grobras Sécurité',
        'republic_agence-grobras-securite', null, true,
        'Premier employeur du jeu (5 octobre 2026). Luthecia, centre d''affaires, piece grobras_securite. Dirigee par Gaston Grobras, secretariat Sandra Pelle -- deux animateurs narratifs, PAS des candidats : ils ne figurent pas au catalogue. Le panneau « NOUS RECRUTONS » de la vitrine devient effectif avec ce lot.')
on conflict (employeur_id) do update set
  pays = excluded.pays, nom = excluded.nom, caisse_id = excluded.caisse_id,
  actif = excluded.actif, note = excluded.note;

-- 8.4 LE CATALOGUE DE LA BETA : 8 agents de securite, 4 maitres-chiens.
--     Aucun portrait : valide au lot 1, ces PNJ prennent l'icone de leur
--     metier. `accroche` porte une ligne de presentation ; pour un maitre-chien
--     c'est la ou vit le nom du chien, puisque le chien n'est pas un PNJ.
--     Les noms suivent la tradition de la maison (Harry Cover, Pat Hounette,
--     Momo Fouine) : ce sont des PROPOSITIONS, modifiables par un UPDATE sans
--     toucher au code -- et c'est tout l'interet d'un catalogue en base.
insert into public.pnj_candidats_catalogue
  (candidat_id, employeur_id, metier, nom, genre, accroche, rang)
values
  ('grobras-ag-01', 'grobras-securite', 'agent_securite', 'Gérard Menvussa',  'H',
   'Quinze ans de faction. N''a jamais rien vu, et le dit avec aplomb.', 1),
  ('grobras-ag-02', 'grobras-securite', 'agent_securite', 'Albert Hagarde',   'H',
   'Ancien veilleur de nuit à la raffinerie. Dort les yeux ouverts, prétend-il.', 2),
  ('grobras-ag-03', 'grobras-securite', 'agent_securite', 'Firmin Poigné',    'H',
   'Poignée de main qui laisse une trace. Peu de mots, jamais deux fois le même.', 3),
  ('grobras-ag-04', 'grobras-securite', 'agent_securite', 'Sylvain Guérite',  'H',
   'Né dans une cabine de gardien, dit la légende de l''agence.', 4),
  ('grobras-ag-05', 'grobras-securite', 'agent_securite', 'Léon Tourniquet',  'H',
   'Tenait l''entrée du stade. Compte les gens par réflexe, même au café.', 5),
  ('grobras-ag-06', 'grobras-securite', 'agent_securite', 'Rachel Barrage',   'F',
   'Un mètre quatre-vingts dans un couloir d''un mètre vingt. Personne ne passe.', 6),
  ('grobras-ag-07', 'grobras-securite', 'agent_securite', 'Brigitte Ronde',   'F',
   'Fait le tour du bâtiment toutes les vingt minutes, montre à la main.', 7),
  ('grobras-ag-08', 'grobras-securite', 'agent_securite', 'Josette Cadenas',  'F',
   'Vérifie trois fois chaque serrure. La troisième fois est pour elle.', 8),

  ('grobras-mc-01', 'grobras-securite', 'maitre_chien',   'Roger Croquignol', 'H',
   'Avec Mâchefer, berger noir de sept ans. Ne lâche jamais la laisse.', 1),
  ('grobras-mc-02', 'grobras-securite', 'maitre_chien',   'Marcel Mordu',     'H',
   'Avec Sucrette, malinois. Le nom est de sa fille ; le caractère ne l''est pas.', 2),
  ('grobras-mc-03', 'grobras-securite', 'maitre_chien',   'Ginette Molosse',  'F',
   'Avec Praline, rottweiler. Parle au chien, pas aux clients.', 3),
  ('grobras-mc-04', 'grobras-securite', 'maitre_chien',   'Anatole Crocs',    'H',
   'Avec Réglisse, dobermann. Les deux ont le même regard.', 4)
on conflict (candidat_id) do update set
  employeur_id = excluded.employeur_id, metier = excluded.metier,
  nom = excluded.nom, genre = excluded.genre,
  accroche = excluded.accroche, rang = excluded.rang;


-- ===========================================================================
-- 9. GARDES — la migration echoue plutot que de livrer un socle a moitie juste
-- ===========================================================================
do $$
declare
  v_n integer; v_t text; v_a integer; v_c integer;
begin
  -- 9.1 LES ARBITRAGES SONT DANS LE REFERENTIEL, AU CHIFFRE PRES.
  select count(*) into v_n from public.pnj_metiers_profils
   where (metier, classe, recrutable, quota_par_joueur, pa_initial, cout_initial, cout_jour) in (
     ('agent_securite', 'alpha', true, 4, 1, 500, 0),
     ('maitre_chien',   'alpha', true, 2, 1, 700, 0));
  if v_n <> 2 then
    raise exception 'arbitrages GD non appliques : % metier(s) conforme(s) sur 2', v_n;
  end if;

  -- 9.2 AUCUNE CARACTERISTIQUE N'A BOUGE, ni celles du lot 2 ni celles des huit
  --     metiers anterieurs. Ce lot ne touche pas une seule caracteristique.
  select count(*) into v_n from public.pnj_metiers_profils
   where (metier, car_int, car_cha, car_vol, car_per, car_dup, car_ent) in (
     ('agent',          13, 12, 12, 13, 13, 10),
     ('agent_securite', 10,  8, 16, 12,  8, 10),
     ('codetenu',       10, 10, 10, 12, 12, 10),
     ('douanier',       10,  8, 12, 12,  8, 10),
     ('escort',         10, 15, 10, 10, 12, 10),
     ('informateur',    10, 10,  8, 15, 12,  8),
     ('maitre_chien',   10,  8, 14, 16,  8, 10),
     ('militant',        9, 12, 15,  9,  8, 12),
     ('policier',       10,  8, 12, 12,  8, 10),
     ('soldat',          9,  8, 12, 10,  8, 12));
  if v_n <> 10 then
    raise exception 'une caracteristique a bouge : % profils intacts sur 10', v_n;
  end if;

  -- 9.3 LE RECRUTEMENT EST OUVERT AUX TROIS METIERS ATTENDUS, ET A EUX SEULS.
  --     Verifie contre la FONCTION, pas contre la colonne : c'est elle que
  --     employe_recruter interroge.
  if not ('agent_securite' = any (public.employe_metiers_recrutables())
      and 'maitre_chien'   = any (public.employe_metiers_recrutables())
      and 'informateur'    = any (public.employe_metiers_recrutables())) then
    raise exception 'un metier attendu n''est pas recrutable : %',
      public.employe_metiers_recrutables();
  end if;
  if coalesce(array_length(public.employe_metiers_recrutables(), 1), 0) <> 3 then
    raise exception 'un metier inattendu est devenu recrutable : %',
      public.employe_metiers_recrutables();
  end if;
  -- escort ne doit PAS revenir par cette porte : elle a la sienne.
  if 'escort' = any (public.employe_metiers_recrutables()) then
    raise exception 'escort est redevenue recrutable par employe_recruter';
  end if;

  -- 9.4 LE PRIX DU REFERENTIEL ET CELUI DU MIROIR DES ORDRES SONT LE MEME.
  --     C'est la garde qui empeche les deux notions de divergeer en silence --
  --     et celle qui aurait attrape le contresens `pa_initial = 12` du lot 2.
  for v_t, v_a, v_c in
    select pr.ordre_fn, pr.pa_initial, pr.cout_initial
      from public.pnj_metiers_profils pr where pr.ordre_fn is not null
  loop
    if not exists (select 1 from public.ordres_couts o
                    where o.fn = v_t and o.pa = v_a and o.cost = v_c) then
      raise exception 'referentiel et miroir des ordres divergent pour % (referentiel : pa %, cout %) ; miroir : %',
        v_t, v_a, v_c,
        coalesce((select format('pa %s cout %s', o.pa, o.cost)
                    from public.ordres_couts o where o.fn = v_t), 'absent');
    end if;
  end loop;

  -- 9.5 LE COUT JOURNALIER EST NUL POUR LES DEUX METIERS. Arbitrage explicite :
  --     « Le joueur ne doit subir aucun prelevement quotidien dans ce lot. »
  if exists (select 1 from public.pnj_metiers_profils
              where metier in ('agent_securite', 'maitre_chien')
                and coalesce(cout_jour, -1) <> 0) then
    raise exception 'un metier de securite porte un cout journalier non nul';
  end if;

  -- 9.6 L'AGENCE, SA CAISSE A ZERO ET FERMEE, ET SON CATALOGUE COMPLET.
  if not exists (select 1 from public.pnj_employeurs
                  where employeur_id = 'grobras-securite' and pays = 'republic' and actif) then
    raise exception 'l''agence Grobras est absente du registre des employeurs';
  end if;
  if coalesce((select (data->>'solde')::numeric from public.caisses_batiments
                where id = 'republic_agence-grobras-securite'), -1) <> 0 then
    raise exception 'la caisse de l''agence n''est pas a zero';
  end if;
  if public.caisse_postes_requis('republic_agence-grobras-securite', 'republic') is null then
    raise exception 'la caisse de l''agence n''a aucune regle d''autorite : elle serait debitable sans controle';
  end if;
  if array_length(public.caisse_postes_requis('republic_agence-grobras-securite', 'republic'), 1) is not null then
    raise exception 'la caisse de l''agence n''est pas reservee au serveur';
  end if;

  select count(*) into v_n from public.pnj_candidats_catalogue
   where employeur_id = 'grobras-securite' and metier = 'agent_securite' and actif;
  if v_n <> 8 then raise exception 'catalogue : % agents de securite sur 8 attendus', v_n; end if;
  select count(*) into v_n from public.pnj_candidats_catalogue
   where employeur_id = 'grobras-securite' and metier = 'maitre_chien' and actif;
  if v_n <> 4 then raise exception 'catalogue : % maitres-chiens sur 4 attendus', v_n; end if;
  -- Les deux animateurs du lieu ne sont PAS des candidats.
  if exists (select 1 from public.pnj_candidats_catalogue
              where nom in ('Gaston Grobras', 'Sandra Pelle')) then
    raise exception 'un animateur du lieu a ete inscrit au catalogue des candidats';
  end if;

  -- 9.7 AUCUN PNJ N'A ETE CREE PAR CETTE MIGRATION. Le recrutement est OUVERT,
  --     mais c'est au joueur de l'exercer.
  select count(*) into v_n from public.pnj_employes_metier
   where job in ('agent_securite', 'maitre_chien');
  if v_n <> 0 then
    raise exception 'cette migration ne doit creer aucun PNJ (% trouve[s])', v_n;
  end if;

  -- 9.8 LES TABLES NEUVES SONT FERMEES AU NAVIGATEUR. Lecon de la doctrine de
  --     controle : un catalogue lisible par `anon`, c'est le casting entier
  --     aspirable, et des identites connues avant d'etre rencontrees.
  if exists (select 1 from information_schema.role_table_grants
              where table_schema = 'public'
                and table_name in ('pnj_employeurs', 'pnj_candidats_catalogue')
                and grantee in ('anon', 'authenticated')) then
    raise exception 'une table du socle employeur est ouverte a anon/authenticated';
  end if;
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
              where n.nspname = 'public'
                and c.relname in ('pnj_employeurs', 'pnj_candidats_catalogue')
                and not c.relrowsecurity) then
    raise exception 'une table du socle employeur n''a pas la RLS activee';
  end if;

  -- 9.9 L'INFORMATEUR N'A RIEN PERDU. Son comportement doit etre IDENTIQUE a
  --     l'avant-lot : recrutable, beta, quota 1, 1 PA, 150 FR a l'embauche et
  --     150 FR par jour. C'est la garde de non-regression de la seule mecanique
  --     d'emploi reellement utilisee aujourd'hui.
  if not exists (select 1 from public.pnj_metiers_profils
                  where metier = 'informateur' and classe = 'beta' and recrutable
                    and quota_par_joueur = 1 and pa_initial = 1
                    and cout_initial = 150 and cout_jour = 150
                    and role_libelle = 'Informateur'
                    and ordre_fn = 'recruter_informateur_pnj') then
    raise exception 'le profil informateur a change : ce lot ne doit pas le toucher';
  end if;
end $$;

commit;
