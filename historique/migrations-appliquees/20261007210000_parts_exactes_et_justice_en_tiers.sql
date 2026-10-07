-- =============================================================================
-- UNE PART DEVIENT UNE FRACTION EXACTE, ET LA JUSTICE SE PARTAGE EN TROIS TIERS
-- Chantier 4F — arbitrage « repartition budgetaire de la Justice », 7 octobre 2026
--
-- APPLIQUEE le 7 octobre 2026. Inscrite au registre Supabase sous la version
-- 20261007191006 (le registre horodate a l'APPLICATION ; le nom de ce fichier garde
-- l'horodatage de sa redaction).
--
-- REFUSEE UNE PREMIERE FOIS PAR SON PROPRE CONTROLE, et c'est ce qui l'a sauvee : le premier
-- jet sommait les parts en divisant d'abord, trois tiers rendaient 0,99999999999999999999, et
-- l'assertion a leve. RIEN n'avait ete applique. La version appliquee somme sur un
-- denominateur commun, par budget_part_totale().
--
-- CE QUI A ETE VERIFIE APRES COUP. Les trois tribunaux portent 1/3 chacun, une SEULE valeur
-- distincte -- aucune preference structurelle. La somme des parts de la Justice vaut 3/3,
-- verifiee en fractions. Sur une base de 2215 FR, non divisible par trois : distribuable 2215,
-- verse 2215, soit 739 + 738 + 738 -- aucun FR perdu. Le reliquat tourne : quatre decalages
-- consecutifs le donnent a capitale, ville_b, ville_a, capitale. Les autres circuits sont
-- inchanges au chiffre pres (QHS 0/100, Douanes 35/100, Caserne 65/100, cle nationale 100/100).
-- L'empreinte des 147 caisses est IDENTIQUE avant et apres l'application
-- (7f32b55325c5895b0a16a2cd9dab82cf, 1 223 164 FR) et le journal des versements est reste vide :
-- aucun solde de betatest touche, aucun versement retroactif. Eprouve en transaction annulee,
-- outils/bancs/banc-budget-cascade.sql, epreuves 5 et 6.
-- =============================================================================
--
-- L'ARBITRAGE. Au demarrage, le budget recurrent du Ministere de la Justice se repartit A PARTS
-- EGALES entre les trois tribunaux territoriaux : Luthecia, Port-Sainte-Marie, Montrouge. C'est
-- une repartition initiale EGALE, pas une difference structurelle -- et le ministre doit ensuite
-- pouvoir la modifier librement.
--
-- -----------------------------------------------------------------------------
-- LE PROBLEME ARITHMETIQUE, ET POURQUOI IL N'A PAS DE SOLUTION DECIMALE
-- -----------------------------------------------------------------------------
-- `part_pourcent numeric(5,2)` ne sait pas ecrire un tiers. Trois voies, toutes mauvaises :
--
--   33,33 / 33,33 / 33,33   somme 99,99 %. Le ministere distribue 99,99 % de son budget et
--                           garde 0,01 % par nuit sans que personne ne l'ait decide. La
--                           consigne demande 100 % exactement.
--   33,33 / 33,33 / 33,34   somme 100 %, mais Montrouge touche un centieme de point de plus
--                           CHAQUE NUIT, pour toujours. C'est exactement la hierarchie
--                           permanente que l'arbitrage interdit.
--   33,333333...            plus de chiffres ne rend pas 1/3 exact. Elargir l'echelle repousse
--                           le probleme, elle ne le resout pas.
--
-- -----------------------------------------------------------------------------
-- LA REPONSE : LA REGLE CANONIQUE DEVIENT UNE FRACTION, PAS UN POURCENTAGE
-- -----------------------------------------------------------------------------
-- La consigne autorise exactement cela : « Si le schema actuel de part_pourcent ne permet pas de
-- representer proprement trois parts egales tout en conservant ces proprietes, adapte la
-- representation generique plutot que d'introduire une exception Justice. »
--
-- `part_pourcent` est remplace par un couple EXACT : `part_numerateur` sur `part_denominateur`.
--
--   Presidence               9 / 100     identique a avant, au chiffre pres
--   Assemblee               19 / 100
--   Defense -> Caserne      65 / 100
--   Interieur -> Douanes    35 / 100
--   Interieur -> QHS         0 / 100     zero reste zero : une configuration, pas une absence
--   Justice -> chaque        1 / 3       un tiers EXACT, et les trois sont identiques
--   tribunal
--
-- UN POURCENTAGE EST UNE FRACTION SUR CENT. Ce n'est donc pas une exception pour la Justice :
-- c'est la generalisation dont le pourcentage est le cas particulier. Rien n'est perdu --
-- `part_numerateur / part_denominateur` dit tout ce que `part_pourcent` disait, et deux choses de
-- plus : les fractions non decimales, et l'egalite parfaite.
--
-- UN TROISIEME PIEGE, TROUVE PAR LE CONTROLE DE LA MIGRATION ELLE-MEME. Le premier jet de ce
-- fichier sommait les parts en divisant d'abord : `sum(part_numerateur / part_denominateur)`.
-- Trois tiers rendaient alors 0,99999999999999999999 -- la division numeric s'arrete a une
-- vingtaine de decimales, et trois tiers inexacts ne refont pas un. La migration a ete REFUSEE
-- par sa propre assertion « la somme des parts de la Justice vaut 0,99999... , pas 1 exactement »,
-- et rien n'a ete applique.
--
-- LA REPONSE : ON NE DIVISE PLUS AVANT DE SOMMER. budget_part_totale() rend la somme des parts
-- d'une source comme UNE SEULE FRACTION, sur un denominateur commun -- 3/3 pour la Justice,
-- 100/100 pour la cle nationale. Aucune division intermediaire, donc aucune perte. Et le
-- distribuable se calcule par `div()`, la division ENTIERE exacte, jamais par un floor sur une
-- division decimale.
--
-- Cette fonction est le SEUL endroit du systeme ou cette arithmetique vit : budget_repartir,
-- budget_repartition_fixer, budget_repartition_lire et budget_coherence l'appellent toutes.
--
-- LE POURCENTAGE RESTE, EN REPRESENTATION. budget_repartition_lire() le CALCULE
-- (`round(num * 100 / den, 4)`) pour l'interface, qui continue de saisir des pourcentages. Il
-- n'est stocke nulle part : une representation calculee a la lecture ne peut pas diverger de la
-- regle. C'est la meme doctrine que l'equivalent en FR, calcule sur le dernier versement reel.
--
-- -----------------------------------------------------------------------------
-- LE SECOND PIEGE : LE RELIQUAT ALLAIT TOUJOURS AU MEME
-- -----------------------------------------------------------------------------
-- Le plus fort reste departageait les egalites par le RANG declare. Avec trois parts
-- rigoureusement egales, les trois ont la meme partie decimale perdue : le FR orphelin partait
-- donc a Luthecia chaque nuit ou la base n'est pas divisible par trois. Deterministe, oui --
-- mais c'est une preference permanente, et l'arbitrage l'interdit aussi.
--
-- Le defaut n'avait rien de propre a la Justice : les NEUF caisses nationales a 9 % sont
-- egalement a egalite entre elles, et un reliquat de 2 ou plus serait parti dans l'ordre
-- Presidence, Premier ministre, Interieur -- toujours le meme ordre.
--
-- LE DEPARTAGE TOURNE DONC AVEC LE JOUR. Un decalage derive de la date -- le nombre de jours
-- depuis le 1er janvier 2026 -- fait pivoter l'ordre des ex aequo. Deterministe : la meme
-- journee rend toujours le meme resultat, et un rejeu donne les memes chiffres. Sans preference :
-- sur n jours, chacun des n beneficiaires occupe chaque position une fois. La rotation porte sur
-- une POSITION DENSE (row_number sur le rang) et non sur le rang brut, pour rester juste meme si
-- les rangs declares ne sont pas contigus.
--
-- -----------------------------------------------------------------------------
-- CE QUE CETTE MIGRATION NE FAIT PAS
-- -----------------------------------------------------------------------------
-- Aucun versement retroactif. Aucun solde de betatest touche. Le QHS, les Douanes et la Caserne
-- gardent leurs parts au chiffre pres -- 0 / 100, 35 / 100 et 65 / 100. Les budgets municipaux ne
-- sont pas abordes. Les dix caisses nationales sont inchangees.
--
-- LES DEUX TABLES SONT NEES HIER ET LE JOURNAL EST VIDE : remplacer la colonne ne detruit aucune
-- donnee vivante. Les 16 lignes de regle sont converties telles quelles, n / 100.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. LA REGLE : UNE FRACTION EXACTE
-- -----------------------------------------------------------------------------

ALTER TABLE public.repartitions_budgetaires
  ADD COLUMN part_numerateur   numeric,
  ADD COLUMN part_denominateur numeric;

-- Conversion sans perte : tout pourcentage est une fraction sur cent.
-- trim_scale() ramene l'echelle au minimum : 9.00 devient 9, et la fraction s'ecrira « 9/100 »
-- et non « 9.00/100 ». Une representation lisible n'est pas un detail quand c'est elle que le
-- ministre lit a l'ecran.
UPDATE public.repartitions_budgetaires
   SET part_numerateur = trim_scale(part_pourcent), part_denominateur = 100
 WHERE part_pourcent IS NOT NULL;

ALTER TABLE public.repartitions_budgetaires
  DROP CONSTRAINT IF EXISTS repartitions_budgetaires_part_bornee,
  DROP COLUMN part_pourcent;

ALTER TABLE public.repartitions_budgetaires
  ADD CONSTRAINT repartitions_budgetaires_part_entiere
    CHECK ((part_numerateur IS NULL) = (part_denominateur IS NULL)),
  ADD CONSTRAINT repartitions_budgetaires_denominateur_positif
    CHECK (part_denominateur IS NULL OR part_denominateur > 0),
  ADD CONSTRAINT repartitions_budgetaires_part_bornee
    CHECK (part_numerateur IS NULL
           OR (part_numerateur >= 0 AND part_numerateur <= part_denominateur));

COMMENT ON COLUMN public.repartitions_budgetaires.part_numerateur IS
  'Numerateur de la part, sur part_denominateur. NULL = part NON ARBITREE, que budget_repartir ignore entierement. ZERO = part DECIDEE a zero : le beneficiaire est reconnu, la regle s''applique et verse zero. Ne jamais confondre les deux, et ne jamais ecrire coalesce(part_numerateur, 0).';
COMMENT ON COLUMN public.repartitions_budgetaires.part_denominateur IS
  'Denominateur de la part. Vaut 100 quand la regle s''exprime naturellement en pourcentage, et autre chose quand elle ne s''y exprime pas EXACTEMENT : trois parts rigoureusement egales sont 1/3, que 33,33 % ne sait pas ecrire. Un pourcentage est le cas particulier d''une fraction sur cent.';

-- -----------------------------------------------------------------------------
-- 2. LE JOURNAL : REJOUABLE AU FRANC
-- -----------------------------------------------------------------------------
-- Le journal portait `part_pourcent numeric(5,2)` : il aurait inscrit 33,33 pour un tiers, et le
-- montant verse n'aurait plus ete recalculable depuis la trace. Il porte desormais la meme
-- fraction exacte que la regle. La table est vide : rien n'est perdu.

ALTER TABLE public.repartitions_versements
  ADD COLUMN part_numerateur   numeric,
  ADD COLUMN part_denominateur numeric;

ALTER TABLE public.repartitions_versements
  DROP COLUMN part_pourcent;

COMMENT ON COLUMN public.repartitions_versements.part_numerateur IS
  'La part EXACTE appliquee ce jour-la, numerateur. Avec base et part_denominateur, le montant verse se recalcule au franc depuis la seule trace.';
COMMENT ON COLUMN public.repartitions_versements.part_denominateur IS
  'La part EXACTE appliquee ce jour-la, denominateur.';

-- -----------------------------------------------------------------------------
-- 3. LA JUSTICE : TROIS TIERS, ET AUCUNE DIFFERENCE ENTRE EUX
-- -----------------------------------------------------------------------------
-- Les trois lignes existaient deja, part NON ARBITREE. Elles passent a 1/3 chacune : la somme
-- fait UN exactement, donc 100 % du budget du ministere est distribue, et les trois valeurs sont
-- rigoureusement identiques -- aucune n'est privilegiee, pas meme d'un centieme de point.

UPDATE public.repartitions_budgetaires
   SET part_numerateur = 1, part_denominateur = 3,
       note = 'ARBITRAGE DU 7 OCTOBRE 2026 : repartition initiale EGALE entre les trois tribunaux territoriaux. UN TIERS EXACT, et non 33,33 % -- qui ne fait pas 100 a trois, ni 33,34 pour l''un d''eux -- qui creerait une preference permanente. Le ministre peut modifier librement cette repartition depuis son tableau de bord.'
 WHERE pays = 'republic' AND source = 'gouvernement-min_just'
   AND beneficiaire IN ('tribunal_capitale', 'tribunal_ville_a', 'tribunal_ville_b');

-- -----------------------------------------------------------------------------
-- 4. LA SOMME DES PARTS D'UNE SOURCE, EN UNE SEULE FRACTION EXACTE
-- -----------------------------------------------------------------------------
-- UN SEUL ENDROIT POUR CETTE ARITHMETIQUE. Quatre fonctions ont besoin de « combien part-il de
-- cette caisse ? ». Si chacune le recalculait, chacune pourrait se tromper differemment -- et
-- c'est exactement ce qui s'est passe au premier jet, ou la division precedait la somme.
--
-- LE DENOMINATEUR COMMUN est accumule par produit des denominateurs distincts, en sautant ceux
-- qui divisent deja le courant. Ce n'est pas le PPCM -- 3 et 6 donnent 18 et non 6 -- et c'est
-- sans importance : tout multiple commun fait l'affaire, et `commun / den` reste exact. numeric
-- n'a pas de borne de magnitude, donc la simplicite gagne sur l'optimalite.
--
-- Les parts NON ARBITREES (NULL) sont exclues : elles ne versent rien. Les parts a ZERO sont
-- incluses -- la regle existe et contribue zero, ce qui n'est pas la meme chose qu'etre absente.

CREATE OR REPLACE FUNCTION public.budget_part_totale(
  p_pays text, p_source text,
  OUT numerateur numeric, OUT denominateur numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d numeric;
BEGIN
  denominateur := 1;
  FOR d IN SELECT DISTINCT part_denominateur
             FROM public.repartitions_budgetaires
            WHERE pays = p_pays AND source = p_source AND part_numerateur IS NOT NULL
            ORDER BY part_denominateur
  LOOP
    IF denominateur % d <> 0 THEN denominateur := denominateur * d; END IF;
  END LOOP;
  SELECT coalesce(sum(part_numerateur * (denominateur / part_denominateur)), 0)
    INTO numerateur
    FROM public.repartitions_budgetaires
   WHERE pays = p_pays AND source = p_source AND part_numerateur IS NOT NULL;
END;
$function$;

COMMENT ON FUNCTION public.budget_part_totale(text, text) IS
  'La somme des parts declarees d''une source, rendue comme UNE SEULE FRACTION exacte (numerateur, denominateur). Aucune division intermediaire : trois tiers rendent 3/3, et non 0,99999999999999999999 -- la division numeric s''arrete a une vingtaine de decimales et trois tiers inexacts ne refont pas un. SEUL endroit du systeme ou cette arithmetique vit ; budget_repartir, budget_repartition_fixer, budget_repartition_lire et budget_coherence l''appellent toutes.';

REVOKE ALL ON FUNCTION public.budget_part_totale(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.budget_part_totale(text, text) TO service_role;

-- -----------------------------------------------------------------------------
-- 5. LA REPARTITION : FRACTIONS EXACTES ET RELIQUAT TOURNANT
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.budget_repartir(p_pays text, p_source text, p_base numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_base numeric := floor(coalesce(p_base, 0));
  v_num_total numeric; v_den_total numeric;
  v_distribuable numeric;
  v_decalage integer;
  v_lignes jsonb := '[]'::jsonb;
  v_verse numeric := 0;
  v_conserve numeric := 0;
  r record; v_rep jsonb;
BEGIN
  IF coalesce(btrim(p_pays), '') = '' OR coalesce(btrim(p_source), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_base <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'base_nulle', 'verse', 0, 'lignes', v_lignes);
  END IF;

  -- LE DECALAGE DU JOUR fait tourner le departage des ex aequo. Il ne depend que de la DATE :
  -- deux executions du meme jour rendent le meme resultat, et un rejeu donne les memes chiffres.
  v_decalage := (v_jour - DATE '2026-01-01');

  -- LA SOMME DES PARTS, EN UNE FRACTION EXACTE.
  SELECT numerateur, denominateur INTO v_num_total, v_den_total
    FROM public.budget_part_totale(p_pays, p_source);
  IF v_num_total <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'aucune_part_arbitree', 'verse', 0,
                              'lignes', v_lignes);
  END IF;

  -- DIVISION ENTIERE, PAS UN FLOOR SUR UNE DIVISION DECIMALE. div() est exacte ; floor(a/b) sur
  -- des numerics passe par un quotient tronque a une vingtaine de decimales.
  v_distribuable := div(v_base * v_num_total, v_den_total);

  -- PLUS FORT RESTE, EN UNE SEULE REQUETE. Aucune table temporaire : une fonction
  -- SECURITY DEFINER qui cree du DDL a chaque appel est une surprise de plus a maintenir, et le
  -- calcul se dit tres bien en CTE.
  --   parts   : la part exacte et son plancher, par beneficiaire declare ;
  --   denses  : une POSITION contigue 1..n, pour que la rotation soit juste meme si les rangs
  --             declares sautent des numeros ;
  --   classe  : les beneficiaires ordonnes par partie decimale perdue decroissante. A EGALITE,
  --             c'est le decalage du jour qui tranche, et non le rang : sinon le premier rang
  --             ramasserait le FR orphelin chaque nuit, pour toujours.
  --   le +1 va aux `distribuable - somme des planchers` premiers de ce classement.
  FOR r IN
    WITH parts AS (
      SELECT b.beneficiaire, b.part_numerateur AS num, b.part_denominateur AS den,
             b.rang, b.libelle,
             -- Le plancher par DIVISION ENTIERE : exact, quel que soit le denominateur.
             div(v_base * b.part_numerateur, b.part_denominateur) AS plancher,
             -- Et la fraction PERDUE par ce plancher, qui sert a classer. Elle est calculee en
             -- une seule division pour etre comparable entre denominateurs differents ; deux
             -- parts rigoureusement egales rendent ici la meme valeur, donc restent a egalite.
             (v_base * b.part_numerateur
              - div(v_base * b.part_numerateur, b.part_denominateur) * b.part_denominateur)
               / b.part_denominateur AS perdu
        FROM public.repartitions_budgetaires b
       WHERE b.pays = p_pays AND b.source = p_source AND b.part_numerateur IS NOT NULL
    ), denses AS (
      SELECT p.*, row_number() OVER (ORDER BY p.rang) AS position, count(*) OVER () AS combien
        FROM parts p
    ), reste AS (
      SELECT v_distribuable - coalesce(sum(plancher), 0) AS nb FROM parts
    ), classe AS (
      SELECT d.*, row_number() OVER (
          ORDER BY d.perdu DESC,
                   ((d.position - 1 + v_decalage) % d.combien),
                   d.rang) AS ordre
        FROM denses d
    )
    SELECT c.beneficiaire, c.num, c.den, c.libelle,
           c.plancher + CASE WHEN c.ordre <= (SELECT nb FROM reste) THEN 1 ELSE 0 END AS montant
      FROM classe c ORDER BY c.rang
  LOOP
    -- LA CLE DU JOURNAL EST LE GARDE-FOU. Un second passage le meme jour leve ici.
    BEGIN
      INSERT INTO public.repartitions_versements
        (pays, source, beneficiaire, jour, base, part_numerateur, part_denominateur,
         montant, transfere)
      VALUES (p_pays, p_source, r.beneficiaire, v_jour, v_base, r.num, r.den, r.montant,
              -- transfere DIT LA VERITE : il est faux aussi bien pour la part que le
              -- repartiteur conserve que pour un montant nul. Une part declaree a 0 est
              -- journalisee -- la regle a bien ete appliquee -- mais rien n'a bouge, et le
              -- journal ne doit pas pretendre le contraire.
              r.beneficiaire <> p_source AND r.montant > 0);
    EXCEPTION WHEN unique_violation THEN
      v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
        'beneficiaire', r.beneficiaire, 'montant', 0, 'raison', 'deja_verse_ce_jour'));
      CONTINUE;
    END;

    -- LA PART DU REPARTITEUR NE SE TRANSFERE PAS. C'est ce qui empeche la boucle : le MEco
    -- recoit tout, en distribue 91 %, et conserve ses 9 % la ou ils sont deja.
    IF r.beneficiaire = p_source THEN
      v_conserve := v_conserve + r.montant;
      v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
        'beneficiaire', r.beneficiaire, 'montant', r.montant, 'conserve', true));
      CONTINUE;
    END IF;

    IF r.montant <= 0 THEN
      v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
        'beneficiaire', r.beneficiaire, 'montant', 0));
      CONTINUE;
    END IF;

    -- DEBIT DE LA SOURCE PUIS CREDIT DU BENEFICIAIRE, par les primitives atomiques existantes.
    -- La porte interne est ouverte pour cette transaction : l'autorite de l'operation est celle
    -- du serveur, pas celle d'un poste.
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement(p_pays || '_' || p_source, -r.montant, true);
    IF coalesce((v_rep->>'ok')::boolean, false) THEN
      v_rep := public.caisse_institution_mouvement(p_pays || '_' || r.beneficiaire, r.montant, false);
    END IF;
    PERFORM set_config('rp.caisse_interne', '', true);

    IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
      -- FAIL CLOSED : rien n'a abouti, on retire la ligne de journal pour que le versement
      -- puisse etre retente, et on le dit.
      DELETE FROM public.repartitions_versements
       WHERE pays = p_pays AND source = p_source AND beneficiaire = r.beneficiaire AND jour = v_jour;
      v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
        'beneficiaire', r.beneficiaire, 'montant', 0,
        'raison', coalesce(v_rep->>'raison','transfert_refuse')));
      CONTINUE;
    END IF;

    v_verse := v_verse + r.montant;
    v_lignes := v_lignes || jsonb_build_array(jsonb_build_object(
      'beneficiaire', r.beneficiaire, 'montant', r.montant));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pays', p_pays, 'source', p_source, 'jour', v_jour,
                            'base', v_base,
                            'parts_totales', v_num_total::text || '/' || v_den_total::text,
                            'distribuable', v_distribuable,
                            'decalage_du_jour', v_decalage,
                            'verse', v_verse, 'conserve', v_conserve, 'lignes', v_lignes);
END;
$function$;

COMMENT ON FUNCTION public.budget_repartir(text, text, numeric) IS
  'Execute la repartition declaree pour (pays, source) sur une base donnee. La part est une FRACTION EXACTE (numerateur sur denominateur) : trois parts rigoureusement egales s''ecrivent 1/3, ce qu''aucun pourcentage decimal ne sait faire. Plus fort reste, aucun FR perdu. A EGALITE de reste, le departage TOURNE avec le jour -- deterministe pour une journee donnee, sans preference permanente pour un beneficiaire. Les parts NULL sont ignorees (rien n''est invente) ; les parts a 0 sont appliquees et journalisees a montant nul (la regle existe et donne zero). La ligne dont le beneficiaire est la source est journalisee mais jamais transferee : c''est ce qui empeche la boucle. La cle primaire du journal porte le jour : la double distribution est impossible par construction. RESERVEE AU SERVEUR.';

REVOKE ALL ON FUNCTION public.budget_repartir(text, text, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.budget_repartir(text, text, numeric) TO service_role;

-- -----------------------------------------------------------------------------
-- 6. MODIFIER UNE PART -- l'interface parle encore en pourcentage
-- -----------------------------------------------------------------------------
-- Le ministre saisit un POURCENTAGE : c'est la representation qu'il comprend, et la signature de
-- cette RPC ne change pas d'un caractere -- le navigateur n'a rien a apprendre. La valeur est
-- stockee en fraction sur cent.
--
-- CONSEQUENCE ASSUMEE : un ministre qui modifie une part exprimee en tiers la ramene a un
-- pourcentage. C'est SA decision, et il la prend en connaissance de cause -- l'ecran affiche la
-- fraction exacte a cote du pourcentage. Les lignes qu'il NE TOUCHE PAS gardent leur fraction :
-- le navigateur n'ecrit que les parts reellement changees.

CREATE OR REPLACE FUNCTION public.budget_repartition_fixer(p_source text, p_beneficiaire text, p_part numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; r record;
  v_part numeric; v_somme numeric;
  v_anc_num numeric; v_anc_den numeric; v_num numeric; v_den numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(country,'republic'), poste->>'id' INTO v_pays, v_poste
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO r FROM public.repartitions_budgetaires
   WHERE pays = v_pays AND source = p_source AND beneficiaire = p_beneficiaire;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'repartition_non_declaree',
                              'source', p_source, 'beneficiaire', p_beneficiaire);
  END IF;
  IF v_poste IS DISTINCT FROM r.poste_autorite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', r.poste_autorite);
  END IF;

  v_part := round(coalesce(p_part, 0)::numeric, 4);
  IF v_part < 0 OR v_part > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'part_hors_bornes');
  END IF;

  -- LA SOMME NE DEPASSE JAMAIS LE TOUT. Verifiee ICI, au serveur : une somme a 110 % versee par
  -- un client modifie distribuerait plus que les recettes.
  --
  -- LA COMPARAISON NE DIVISE PAS. On ecrit la ligne, on demande a budget_part_totale() la somme
  -- exacte de la source, et on compare numerateur et denominateur. Si le total depasse, on
  -- RESTAURE l'ancienne valeur et on refuse -- la verification est donc faite sur l'etat REEL,
  -- pas sur une simulation qui pourrait differer. Tout se passe dans une transaction : un refus
  -- ne laisse aucune trace.
  -- L'ancienne valeur est deja dans `r`, lu au debut : pas de seconde lecture.
  v_anc_num := r.part_numerateur;
  v_anc_den := r.part_denominateur;

  UPDATE public.repartitions_budgetaires
     SET part_numerateur = trim_scale(v_part), part_denominateur = 100
   WHERE pays = v_pays AND source = p_source AND beneficiaire = p_beneficiaire;

  SELECT numerateur, denominateur INTO v_num, v_den
    FROM public.budget_part_totale(v_pays, p_source);
  IF v_num > v_den THEN
    UPDATE public.repartitions_budgetaires
       SET part_numerateur = v_anc_num, part_denominateur = v_anc_den
     WHERE pays = v_pays AND source = p_source AND beneficiaire = p_beneficiaire;
    RETURN jsonb_build_object('ok', false, 'raison', 'somme_depasse_cent',
                              'somme_obtenue', round(v_num * 100 / v_den, 4));
  END IF;
  v_somme := round(v_num * 100 / v_den, 4);

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'source', p_source,
                            'beneficiaire', p_beneficiaire, 'part', v_part,
                            'somme', v_somme);
END;
$function$;

COMMENT ON FUNCTION public.budget_repartition_fixer(text, text, numeric) IS
  'Fixe la part d''un beneficiaire declare. L''acteur vient de mon_personnage(), son pays et son poste de sa fiche : le navigateur n''annonce jamais son droit. La ligne doit exister -- on ne cree pas un beneficiaire depuis un navigateur. Le parametre est un POURCENTAGE, stocke en fraction sur cent ; la somme des parts d''une source est verifiee en FRACTIONS EXACTES et ne peut jamais depasser le tout. Modifier une part exprimee en tiers la ramene a un pourcentage : c''est la decision du ministre, et l''ecran lui montre la fraction avant qu''il la remplace.';

REVOKE ALL ON FUNCTION public.budget_repartition_fixer(text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.budget_repartition_fixer(text, text, numeric) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. LIRE UNE REPARTITION -- une regle, trois representations
-- -----------------------------------------------------------------------------
-- LA FRACTION EST LA REGLE. Le pourcentage et le montant en FR sont des REPRESENTATIONS,
-- calculees a la lecture : aucune n'est stockee, donc aucune ne peut diverger de la regle.
--   . part_pourcent     round(num * 100 / den, 4) -- ce que l'interface fait saisir ;
--   . part_exacte       '1/3', pour que l'ecran puisse dire la verite quand le pourcentage
--                       n'est qu'un arrondi ;
--   . equivalent_fr     calcule sur le dernier versement REELLEMENT recu par la source.
--
-- total_pourcent est la somme EXACTE des parts, en pourcentage : trois tiers rendent 100,0000 et
-- non 99,9999. C'est elle que l'ecran doit afficher a l'ouverture, sans la recalculer depuis des
-- pourcentages arrondis.

DROP FUNCTION IF EXISTS public.budget_repartition_lire(text);

CREATE FUNCTION public.budget_repartition_lire(p_source text)
RETURNS TABLE (
  beneficiaire text, libelle text, part_pourcent numeric,
  part_numerateur numeric, part_denominateur numeric, part_exacte text,
  total_pourcent numeric, rang integer,
  poste_autorite text, est_la_source boolean,
  solde_beneficiaire numeric, base_reference numeric, equivalent_fr numeric,
  dernier_versement numeric, dernier_jour date, note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_base numeric; v_total numeric;
        v_num_total numeric; v_den_total numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN; END IF;
  SELECT coalesce(country,'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  -- La base de reference : ce que la SOURCE a recu lors du dernier versement la concernant.
  SELECT v.montant INTO v_base
    FROM public.repartitions_versements v
   WHERE v.pays = v_pays AND v.beneficiaire = p_source
   ORDER BY v.jour DESC LIMIT 1;

  -- LA SOMME EXACTE, par la fonction qui porte cette arithmetique : trois tiers rendent
  -- 100,0000 et non 99,9999. C'est ce total que l'ecran doit afficher a l'ouverture.
  SELECT numerateur, denominateur INTO v_num_total, v_den_total
    FROM public.budget_part_totale(v_pays, p_source);
  v_total := CASE WHEN v_den_total = 0 THEN 0 ELSE v_num_total / v_den_total END;

  RETURN QUERY
  SELECT b.beneficiaire, b.libelle,
         CASE WHEN b.part_numerateur IS NULL THEN NULL
              ELSE round(b.part_numerateur * 100 / b.part_denominateur, 4) END,
         b.part_numerateur, b.part_denominateur,
         -- Les deux valeurs sont stockees a l'echelle minimale (trim_scale), donc ::text rend
         -- « 1/3 », « 9/100 », « 33.33/100 » -- jamais « 9.00/100 ».
         CASE WHEN b.part_numerateur IS NULL THEN NULL
              ELSE trim_scale(b.part_numerateur)::text || '/'
                   || trim_scale(b.part_denominateur)::text END,
         round(v_num_total * 100 / v_den_total, 4),
         b.rang, b.poste_autorite,
         (b.beneficiaire = b.source) AS est_la_source,
         (SELECT CASE WHEN jsonb_typeof(c.data->'solde') = 'number'
                      THEN (c.data->>'solde')::numeric ELSE 0 END
            FROM public.caisses_batiments c WHERE c.id = v_pays || '_' || b.beneficiaire),
         v_base,
         CASE WHEN v_base IS NULL OR b.part_numerateur IS NULL THEN NULL
              ELSE floor(v_base * b.part_numerateur / b.part_denominateur) END,
         (SELECT v.montant FROM public.repartitions_versements v
           WHERE v.pays = b.pays AND v.source = b.source AND v.beneficiaire = b.beneficiaire
           ORDER BY v.jour DESC LIMIT 1),
         (SELECT v.jour FROM public.repartitions_versements v
           WHERE v.pays = b.pays AND v.source = b.source AND v.beneficiaire = b.beneficiaire
           ORDER BY v.jour DESC LIMIT 1),
         b.note
    FROM public.repartitions_budgetaires b
   WHERE b.pays = v_pays AND b.source = p_source
   ORDER BY b.rang;
END;
$function$;

COMMENT ON FUNCTION public.budget_repartition_lire(text) IS
  'Lit la repartition declaree d''une source, pour l''interface. UNE regle -- la FRACTION EXACTE num/den -- et TROIS representations, toutes calculees a la lecture donc incapables de diverger : le pourcentage arrondi (ce que l''interface fait saisir), la fraction ecrite en clair (pour que l''ecran puisse dire 1/3 la ou 33,3333 % mentirait), et l''equivalent en FR calcule sur le dernier versement REELLEMENT recu par la source. total_pourcent est la somme EXACTE des parts : trois tiers rendent 100,0000. base_reference NULL = la source n''a encore rien recu, et l''interface doit le dire plutot qu''inventer un montant.';

REVOKE ALL ON FUNCTION public.budget_repartition_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.budget_repartition_lire(text) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 8. LES CINQ INVARIANTS, EN FRACTIONS
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.budget_coherence()
RETURNS TABLE(probleme text, detail text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  -- La somme des parts d'une source ne doit jamais depasser le tout. Comparee en FRACTIONS :
  -- trois tiers font exactement UN, et ne declenchent donc pas cet invariant.
  SELECT 'somme des parts superieure a 100 %',
         string_agg(x.pays || '/' || x.source || ' = '
                    || round(x.num * 100 / x.den, 4)::text || ' %', ', ' ORDER BY x.source)
    FROM (SELECT s.pays, s.source, t.numerateur AS num, t.denominateur AS den
            FROM (SELECT DISTINCT pays, source FROM public.repartitions_budgetaires
                   WHERE part_numerateur IS NOT NULL) s
            CROSS JOIN LATERAL public.budget_part_totale(s.pays, s.source) t) x
   WHERE x.num > x.den
  HAVING count(*) > 0
  UNION ALL
  -- Un beneficiaire declare doit avoir une caisse qui existe, sinon le versement sera refuse
  -- chaque nuit en silence. Les parts NULL sont exclues : elles ne versent rien. Les parts a
  -- ZERO, elles, sont incluses -- la regle existe, elle s'appliquera le jour ou le ministre
  -- relevera la part, et la caisse doit donc etre la des maintenant.
  SELECT 'beneficiaire sans caisse en base',
         string_agg(b.pays || '_' || b.beneficiaire, ', ' ORDER BY b.beneficiaire)
    FROM public.repartitions_budgetaires b
   WHERE b.part_numerateur IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.caisses_batiments c
                      WHERE c.id = b.pays || '_' || b.beneficiaire)
  HAVING count(*) > 0
  UNION ALL
  -- Le poste d'autorite doit exister comme poste du jeu.
  SELECT 'poste d''autorite inconnu',
         string_agg(DISTINCT b.poste_autorite, ', ')
    FROM public.repartitions_budgetaires b
   WHERE NOT EXISTS (SELECT 1 FROM public.postes_nommes_regles p WHERE p.poste_id = b.poste_autorite)
     AND NOT EXISTS (SELECT 1 FROM public.salaires_caisses s WHERE s.poste_id = b.poste_autorite)
  HAVING count(*) > 0
  UNION ALL
  -- Deux versements le meme jour pour le meme couple : impossible par la cle primaire, mais on
  -- le verifie quand meme -- c'est l'invariant le plus couteux s'il tombe.
  SELECT 'double versement le meme jour',
         string_agg(v.source || '->' || v.beneficiaire || ' le ' || v.jour::text, ', ')
    FROM (SELECT pays, source, beneficiaire, jour, count(*) AS n
            FROM public.repartitions_versements
           GROUP BY pays, source, beneficiaire, jour) v
   WHERE v.n > 1
  HAVING count(*) > 0
  UNION ALL
  -- UNE CAISSE, UN FINANCEUR RECURRENT.
  SELECT 'caisse financee par deux sources',
         string_agg(y.pays || '_' || y.beneficiaire || ' <- ' || y.sources, ', ' ORDER BY y.beneficiaire)
    FROM (SELECT pays, beneficiaire, string_agg(source, ' et ' ORDER BY source) AS sources
            FROM public.repartitions_budgetaires
           WHERE beneficiaire <> source
           GROUP BY pays, beneficiaire
          HAVING count(*) > 1) y
  HAVING count(*) > 0;
$function$;

COMMENT ON FUNCTION public.budget_coherence() IS
  'Cinq invariants de l''architecture budgetaire, verifies en FRACTIONS EXACTES : aucune somme de parts au-dela du tout (trois tiers font UN, pas 100,01), aucun beneficiaire a part NON NULLE sans caisse en base (les parts a 0 comptent -- la regle existe), aucun poste d''autorite inconnu, aucun double versement le meme jour, et aucune caisse financee par deux sources differentes (une caisse, un financeur recurrent).';

REVOKE ALL ON FUNCTION public.budget_coherence() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.budget_coherence() TO service_role;

-- -----------------------------------------------------------------------------
-- 9. LE CONTROLE, DANS LA TRANSACTION
-- -----------------------------------------------------------------------------
-- Huit assertions, une par preuve demandee.

DO $$
DECLARE
  v_parts text; v_distinctes integer; v_pbs text;
  v_qhs text; v_douane text; v_caserne text;
  v_num numeric; v_den numeric;
BEGIN
  -- (1) et (4) LES TROIS TRIBUNAUX SONT A PARTS EGALES, et rigoureusement identiques.
  SELECT string_agg(trim_scale(part_numerateur)::text || '/'
                    || trim_scale(part_denominateur)::text, ' ' ORDER BY rang),
         count(DISTINCT part_numerateur / part_denominateur)
    INTO v_parts, v_distinctes
    FROM public.repartitions_budgetaires
   WHERE pays = 'republic' AND source = 'gouvernement-min_just';
  IF v_parts IS DISTINCT FROM '1/3 1/3 1/3' THEN
    RAISE EXCEPTION 'les trois tribunaux devraient porter 1/3 chacun, trouve : %', coalesce(v_parts,'(rien)');
  END IF;
  IF v_distinctes <> 1 THEN
    RAISE EXCEPTION 'les trois tribunaux portent % valeurs distinctes : une preference structurelle existe', v_distinctes;
  END IF;

  -- (2) LA SOMME DISTRIBUABLE EST EXACTEMENT 100 %.
  SELECT numerateur, denominateur INTO v_num, v_den
    FROM public.budget_part_totale('republic', 'gouvernement-min_just');
  IF v_num <> v_den THEN
    RAISE EXCEPTION 'la somme des parts de la Justice vaut %/%, pas le tout', v_num, v_den;
  END IF;
  -- Et la preuve au franc : sur une base NON divisible par trois, tout est distribue.
  IF div(2215 * v_num, v_den) <> 2215 THEN
    RAISE EXCEPTION 'sur une base de 2215 FR, le distribuable vaut % et non 2215',
      div(2215 * v_num, v_den);
  END IF;
  IF div(2215::numeric, 3) * 3 <> 2214 THEN
    RAISE EXCEPTION 'les planchers de 2215/3 ne font pas 2214';
  END IF;

  -- (7) LES AUTRES CIRCUITS SONT INCHANGES, au chiffre pres.
  SELECT trim_scale(part_numerateur)::text || '/' || trim_scale(part_denominateur)::text
    INTO v_qhs
    FROM public.repartitions_budgetaires
   WHERE pays='republic' AND source='gouvernement-min_int' AND beneficiaire='qhs-prison';
  SELECT trim_scale(part_numerateur)::text || '/' || trim_scale(part_denominateur)::text
    INTO v_douane
    FROM public.repartitions_budgetaires
   WHERE pays='republic' AND source='gouvernement-min_int' AND beneficiaire='douane';
  SELECT trim_scale(part_numerateur)::text || '/' || trim_scale(part_denominateur)::text
    INTO v_caserne
    FROM public.repartitions_budgetaires
   WHERE pays='republic' AND source='gouvernement-min_def' AND beneficiaire='caserne-militaire';
  IF v_qhs IS DISTINCT FROM '0/100' OR v_douane IS DISTINCT FROM '35/100'
     OR v_caserne IS DISTINCT FROM '65/100' THEN
    RAISE EXCEPTION 'un autre circuit a bouge -- QHS %, Douanes %, Caserne %', v_qhs, v_douane, v_caserne;
  END IF;
  SELECT numerateur, denominateur INTO v_num, v_den
    FROM public.budget_part_totale('republic', 'gouvernement-min_fin');
  IF v_num <> v_den THEN
    RAISE EXCEPTION 'la cle nationale ne fait plus 100 %% : %/%', v_num, v_den;
  END IF;

  -- (8) AUCUN SOLDE N'EST TOUCHE. Cela ne s'asserte PAS ici, et le premier jet de cette
  -- migration avait tort d'essayer : il levait si une caisse portait un updated_at recent, ce
  -- qu'une action de joueur produit a tout moment sur une betatest vivante. Le controle aurait
  -- echoue sans qu'une seule ligne de cette migration soit en cause.
  --
  -- LA PREUVE EST AILLEURS, ET ELLE EST PLUS FORTE : cette migration ne contient AUCUN ordre
  -- d'ecriture sur caisses_batiments -- ni INSERT, ni UPDATE, ni DELETE, ni appel a une
  -- primitive de mouvement. Les soldes sont releves avant et apres l'application, hors
  -- transaction, et compares.

  -- Et les cinq invariants tiennent.
  SELECT string_agg(probleme || ' (' || detail || ')', ' | ') INTO v_pbs FROM public.budget_coherence();
  IF v_pbs IS NOT NULL THEN
    RAISE EXCEPTION 'budget_coherence() signale : %', v_pbs;
  END IF;
END $$;

COMMIT;
