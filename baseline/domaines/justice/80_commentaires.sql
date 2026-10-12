-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.detentions.provenance IS 'NULL = detention d''un PJ (comportement historique). Sinon, systeme PNJ proprietaire de l''etat de la cible, ex. agent_renseignement.';
COMMENT ON COLUMN public.infractions.libelle IS 'Le libelle que rend getPeineParActe. VINGT-TROIS des 39 infractions n''ont PAS de nom propre : elles heritent celui de leur categorie (« Delit mineur », « Crime »), parce que le canon n''en declare pas d''autre. Aucun nom n''a ete invente ici -- l''ecran du juge affiche donc l''identifiant a cote du libelle, et nommer ces 23 infractions est un arbitrage de game design ouvert.';
COMMENT ON FUNCTION public.affaire_transmettre(text,text,text,jsonb) IS 'La police transmet au PARQUET un acte illegal decouvert. Le statut est `au_parquet` et plus `deposee` : elle ne saisit pas le tribunal elle-meme et ne decide pas des poursuites. L''identifiant reste derive de l''acte, donc une meme affaire transmise deux fois le meme jour est la MEME ligne.';
COMMENT ON FUNCTION public.detention_clore_evasion() IS 'Clot SA PROPRE detention par evasion : mode_fin = evasion, est_emprisonne vide, drapeau QHS
abaisse et ligne du registre du QHS liberee -- en une transaction. jour_fin n''est JAMAIS reecrit :
une evasion n''est pas une liberation. Rend les motifs d''origine, le pays et le reliquat, pour que
l''appelant construise l''avis de recherche. Verdicts : acteur_non_authentifie, non_detenu, puis ok.';
COMMENT ON FUNCTION public.detention_clore_interne(text,text,integer) IS 'MOTEUR de fin de detention : clot la ligne du registre avec son mode de fin, vide est_emprisonne,
abaisse le drapeau QHS en OBJET s''il etait leve et passe la ligne du registre du QHS a libere --
les quatre ecritures, en une transaction. AUCUNE precondition, AUCUN controle d''autorite : c''est
le role de ses cinq portes (detention_clore_purgee, detention_clore_evasion,
detention_reduire_peine, detention_clore_motif_eteint, presidence_gracier). Non appelable depuis
le reseau.';
COMMENT ON FUNCTION public.detention_clore_motif_eteint(text) IS 'Clot SA PROPRE detention quand son motif est administrativement eteint : « poursuites_eteintes »
(demobilisation) ou « incorporation » (transfert a la caserne). Ne libere que si la detention ne
tenait qu''a la desertion -- regle de jeu existante, qui n''etait verifiee que par le navigateur.
Verdicts : acteur_non_authentifie, non_detenu, peine_pas_seulement_desertion, puis ok avec mode.';
COMMENT ON FUNCTION public.detention_clore_purgee() IS 'Clot SA PROPRE peine quand elle est purgee : mode_fin = purgee, est_emprisonne vide, drapeau QHS
abaisse en OBJET et ligne du registre du QHS passee a libere -- en une transaction. Le jour de
reference vient de la fiche, jamais de l''appelant. Idempotente : rejouee, elle rend non_detenu.
Verdicts : acteur_non_authentifie, non_detenu, peine_non_purgee, puis ok.';
COMMENT ON FUNCTION public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb) IS 'PRIMITIVE d''incarceration : ouvre la ligne detentions et pose est_emprisonne dans la meme
transaction, refuse une cible deja detenue, et sait arreter un PNJ comme un PJ. AUCUN controle
d''autorite -- c''est le role de ses portes (justice_executer_condamnation, arrestation_urgence,
enquete_garde_a_vue, fraude_electorale_sanctionner, plainte_instruire_interne,
militaire_bataille_appliquer, detention_ouvrir_soi). p_extras porte les metadonnees judiciaires
optionnelles : ville_condamnation, jour_affaire, detention_precedente_id, reliquat_jours,
retour_ville. Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) IS 'S''incarcerer SOI-MEME : flagrant delit sur soi, placement au QHS, rebellion matee, sentence,
tracts calomnieux. L''identite, le pays et le jour viennent du serveur, jamais de l''appelant.
Verdicts : acteur_non_authentifie, duree_invalide, cible_deja_detenue, puis ok avec detention_id,
jour_debut et jour_fin.';
COMMENT ON FUNCTION public.detention_prolonger_interne(text,jsonb,boolean) IS 'MOTEUR de prolongation de peine : concatene les motifs sous verrou, repousse jour_fin, aligne
est_emprisonne, et pose le drapeau QHS si demande. N''a AUCUN controle d''autorite -- c''est le
role de ses portes : justice_prolonger_peine (un juge, sur un tiers) et detention_prolonger_soi
(le detenu, sur lui-meme). Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.detention_prolonger_soi(jsonb,boolean) IS 'Prolonge SA PROPRE peine : rebellion en cellule, placement au QHS. L''identite vient de
mon_personnage(), jamais d''un parametre. Verdicts : acteur_non_authentifie, motifs_absents,
cible_non_detenue, puis ok avec jours_ajoutes et jour_fin.';
COMMENT ON FUNCTION public.detention_qhs_poser_interne(text,text,text) IS 'SEUL ECRIVAIN du caractere QHS au moment de l''acte : pose detentions.qhs, est_emprisonne.qhs et
detention_qhs -- ce dernier en OBJET et non en chaine, forme que pa_repos_nocturne exige pour
appliquer le plafond de PA -- puis inscrit au registre du QHS une seule fois. Non appelable
depuis le reseau.';
COMMENT ON FUNCTION public.detention_reduire_peine(boolean) IS 'Applique la requete de l''avocat sur SA PROPRE peine, en une transaction : consomme l''avocat
(dans les deux cas, requete acceptee ou refusee), et si elle est acceptee reduit la peine de la
moitie du reliquat arrondie au superieur, en cloturant par anticipee_avocat si le terme est
atteint. Le MONTANT de la reduction est calcule ici, pas recu ; seul le resultat de la plaidoirie
vient de l''appelant, parce qu''il depend de valeurs qui vivent dans l''etat client. Verdicts :
acteur_non_authentifie, non_detenu, avocat_deja_utilise, peine_sans_terme, puis ok.';
COMMENT ON FUNCTION public.detention_transferer_qhs(text,integer,text,jsonb) IS 'Bascule SA PROPRE detention en cours vers le quartier de haute securite : clot l''ancienne ligne
par transfert_qhs, en ouvre une nouvelle qui la cite via detention_precedente_id, et pose le
drapeau QHS -- en une transaction. N''est PAS idempotente a dessein : un second appel est une
seconde rebellion, que le jeu permet. L''invariant tenu est qu''exactement une peine reste en
cours. Verdicts : acteur_non_authentifie, duree_invalide, non_detenu, puis ok.';
COMMENT ON FUNCTION public.dossier_acte_consigner(text,text,text,text,text,text,text,text,jsonb) IS 'Ajoute un acte a la chronologie d''un dossier. INTERNE : aucun client ne l''appelle, sinon un navigateur pourrait fabriquer un fait procedural. ELLE LEVE au lieu de refuser -- ses onze appelants l''invoquent par PERFORM, qui jette la valeur rendue, donc un refus propre serait un trou silencieux dans la chronologie. En levant, elle annule la transaction entiere : l''acte judiciaire et sa trace sont le meme fait, ou ils ne valent rien.';
COMMENT ON FUNCTION public.infraction_canonique(text) IS 'Resout un identifiant d''infraction vers sa forme canonique, ou NULL. FAIL CLOSED : un identifiant inconnu rend NULL, et un nom de CATEGORIE rend NULL aussi -- on ne condamne pas pour « crime » en general. Les alias sont resolus d''abord.';
COMMENT ON FUNCTION public.infraction_peine_bornes(text) IS 'La peine de reference d''une infraction canonique et sa plage de modulation judiciaire : -50 % a +50 %, calcules au SERVEUR. `plancher_technique` vaut true quand la borne basse EGALE la reference -- cas des huit infractions a 1 jour, ou l''attenuation est inexprimable en jours entiers et ou le juge ne peut donc qu''aggraver. C''est un fait signale, pas un arbitrage rendu.';
COMMENT ON FUNCTION public.infractions_empreinte_reelle() IS 'L''empreinte du contenu COURANT du miroir des infractions, sur la meme chaine et le meme tri COLLATE "C" que outils/generateurs/generer_infractions.py. COLLATE "C" n''est pas decoratif : les identifiants portent des soulignes, que la collation par defaut ignore au poids primaire alors que Python trie par point de code.';
COMMENT ON FUNCTION public.juge_de_la_ville(text) IS 'Rend le JUGE de la ville donnee s''il s''agit de l''appelant. A ne pas confondre avec affaire_autorite_de, qui accepte aussi le commissaire : celle-la sert la lecture des dossiers, celle-ci le jugement.';
COMMENT ON FUNCTION public.juge_dossiers() IS 'Les dossiers REGULIEREMENT SAISIS du tribunal du juge, avec leur chronologie complete -- donc la qualification du parquet et tout ce qui a precede. Un dossier au parquet n''y figure pas : le juge ne voit que ce dont il est saisi.';
COMMENT ON FUNCTION public.juge_suite_apres_abandon(text,text) IS 'Apres un abandon du parquet sur une affaire DEJA SAISIE, le juge accepte l''arret ou poursuit la procedure. Deux faits serveur distincts (juge_arret_accepte / juge_poursuite_maintenue), consignes a cote de l''abandon et jamais fusionnes avec lui. Reserve au juge de la ville de l''affaire, transition revendiquee par compare-and-swap.';
COMMENT ON FUNCTION public.justice_peine_calcul(text,text,text,text) IS 'LA formule de peine du serveur, unique : la plage autorisee pour une infraction canonique et un genre de sanction. Les deux portes du jugement -- celle qui propose au juge et celle qui enregistre -- l''appellent toutes les deux, donc elles ne peuvent pas diverger. Les genres qhs et torture rendent une plage reduite a un POINT : leur valeur est IMPOSEE par le serveur (30 jours, et 3 x (n+1) pour la torture), recopiee des regles validees et non derivee du catalogue.';
COMMENT ON FUNCTION public.justice_peine_proposer(text,text,text) IS 'Ce que le juge PEUT prononcer sur une affaire, pour son ecran : la plage reelle calculee par justice_peine_calcul, apres verification de la competence et de l''etat de l''affaire. Lecture seule. Elle rend aussi le motif ALLEGUE de la plainte, que la qualification du juge peut contredire sans l''effacer.';
COMMENT ON FUNCTION public.justice_relaxer(text,text) IS 'La relaxe : un VERDICT structure, pas une peine de zero ni une suppression de dossier. Elle a sa ligne au registre des jugements avec `peine` NULL et `data.verdict = relaxe`. Elle porte une qualification -- on relaxe DE quelque chose -- par defaut celle du parquet, que le juge peut requalifier avant, auquel cas la requalification est un acte distinct de la chronologie.';
COMMENT ON FUNCTION public.justice_rendre_sentence(text,text,text,integer,integer) IS 'La condamnation. Exige une SAISINE reguliere du parquet et le JUGE DE LA VILLE -- l''ancienne garde acceptait aussi le commissaire. La peine reste calculee et bornee par justice_peine_calcul (reference +/- 50 %). Une requalification est consignee comme un FAIT DISTINCT et n''efface pas la qualification du parquet : les trois niveaux -- categorie alleguee, parquet, juge -- coexistent sur le jugement.';
COMMENT ON FUNCTION public.parquet_abandonner(text,text) IS 'Le parquet abandonne les poursuites. AVANT la saisine du juge, la procedure s''arrete (statut abandonnee). APRES, l''abandon n''y met pas fin : il ouvre une question (statut abandon_demande) que le juge tranchera par juge_suite_apres_abandon. Les deux actes restent DISTINCTS dans la chronologie, et le dossier n''est jamais supprime. Transition revendiquee par compare-and-swap.';
COMMENT ON FUNCTION public.parquet_dossiers() IS 'Les dossiers du pays qui relevent encore du parquet, avec leur chronologie et un drapeau de PRESENCE par dossier -- l''ecran sait donc avant le clic sur quelle affaire le Procureur peut agir d''ou il se tient. Lecture seule, reservee au Procureur en exercice.';
COMMENT ON FUNCTION public.parquet_garde(text,text[]) IS 'TOUTES les conditions d''un acte du parquet sur un dossier, en une seule fonction : etre le Procureur en exercice, le pays, le statut procedural attendu, et la PRESENCE PHYSIQUE dans le tribunal de la ville competente. Les cinq portes du parquet l''appellent, donc aucune ne peut oublier une condition.';
COMMENT ON FUNCTION public.parquet_moi() IS 'Rend le Procureur en exercice s''il s''agit de l''appelant, rien sinon. Le poste est national : aucune ville n''entre dans la question. Le `poste` de la fiche est atteste par trg_personnages_attester_poste, donc il ne peut pas etre auto-declare.';
COMMENT ON FUNCTION public.parquet_non_lieu(text,text) IS 'Le parquet decide de ne pas poursuivre. Possible SANS enquete prealable. Le serveur enregistre la DECISION, jamais une conclusion sur les faits : un non-lieu ne dit ni que la plainte etait mensongere, ni que la personne visee est innocente. Le motif eventuel est le texte du Procureur, conserve comme declaration. Transition revendiquee par compare-and-swap.';
COMMENT ON FUNCTION public.parquet_poursuivre(text,text) IS 'Le parquet engage les poursuites sous une infraction CANONIQUE, qu''il choisit et qui peut differer de la categorie alleguee par le plaignant. La qualification est validee contre le catalogue : un identifiant invente, ou un nom de categorie generique, est refuse. Fait serveur date, consigne a la chronologie, transition revendiquee par compare-and-swap.';
COMMENT ON FUNCTION public.parquet_site_competent(text,text) IS 'Le batiment ou siege la justice d''une ville : `tribunal` dans la capitale, `tribunal-local` ailleurs. Lu depuis le referentiel villes, jamais recopie -- une ville inconnue rend NULL, donc fail closed.';
COMMENT ON FUNCTION public.plainte_defendre(text,text) IS 'La defense de l''accuse, et de lui seul. Le dossier doit etre AU PARQUET : c''est la traduction exacte de l''ancienne garde sur `deposee` -- on se defend tant qu''aucune autorite n''a agi -- et non la reunion des cinq statuts vivants du parquet, qui donnerait un pouvoir que l''ancienne regle ne donnait pas. La reussite critique clot le dossier, comme avant.';
COMMENT ON FUNCTION public.plainte_deposer(text,text,text) IS 'Depot d''une plainte : une DECLARATION de joueur, payee dans la meme transaction, qui arrive AU PARQUET et n''y declenche rien automatiquement. Elle n''instruit plus au depot -- c''etait le defaut le plus silencieux de l''ancienne chaine : avec un commissaire PNJ, deposer une plainte ouvrait immediatement une enquete et pouvait mettre la personne visee en garde a vue deux jours, sans qu''aucune autorite n''ait rien decide. La categorie alleguee est le premier des trois niveaux de qualification et n''engage rien.';
COMMENT ON FUNCTION public.plainte_traiter(text,text) IS 'L''ACTE D''ENQUETE de la police, et plus rien d''autre. La decision `classer` a disparu : l''opportunite des poursuites appartient au parquet, et un appel qui l''emploie encore est refuse explicitement (classement_reserve_au_parquet). L''enquete n''est possible que sur un dossier ou le Procureur l''a DILIGENTEE, une seule fois, et elle ne change pas le statut : la police rapporte, le parquet decide.';
COMMENT ON FUNCTION public.plaintes_epingler_verdict() IS 'Protege les champs d''issue judiciaire d''un dossier contre les ecritures des PARTIES. Trois autorites passent : le serveur, l''autorite judiciaire de la ville (juge ou commissaire) et, depuis le 12 octobre 2026, LE PARQUET de son pays -- le Procureur est national, donc affaire_autorite_de le refusait et ce declencheur restaurait le statut qu''il venait d''ecrire. Le laissez-passer rp.verdict_interne reste employe par la defense de l''accuse, qui n''est pas une autorite.';
COMMENT ON TABLE public.dossiers_judiciaires_actes IS 'La chronologie procedurale d''un dossier judiciaire : des FAITS dates par le serveur, APPEND-ONLY. Trois verrous : aucun GRANT client, aucune policy, et un declencheur qui refuse tout UPDATE et tout DELETE. Elle n''enregistre jamais d''opinion, de credibilite, d''intention supposee ni de resume -- la presse et les joueurs interpreteront. `rang` donne l''ordre reel des actes, parce que deux actes de la meme transaction partagent now().';
COMMENT ON TABLE public.dossiers_judiciaires_actes_types IS 'Liste blanche des actes qu''une chronologie judiciaire peut porter. Table et non contrainte CHECK : une couche future -- temoignages, audience, appel, execution de peine -- s''y ajoute par une ligne au lieu d''une migration de contrainte. Douze types au 12 octobre 2026, ceux de la chaine parquet.';
COMMENT ON TABLE public.infractions IS 'Catalogue canonique des infractions, MIROIR de PEINES/PEINES_ACTES/ACTES_ILLEGAUX de plateau-core.js. La peine de reference de chaque ligne est exactement ce que getPeineParActe(id, false) rend cote navigateur : aucune valeur n''est decidee ici. Surveille par infractions_empreinte / infractions_empreinte_reelle().';
COMMENT ON TABLE public.infractions_alias IS 'Resolution des nomenclatures historiques vers un identifiant canonique. VIDE au 12 octobre 2026, et ce n''est pas un oubli : les trois paires de doublons relevees par l''inventaire portent des durees de reference DIFFERENTES de part et d''autre, donc les resoudre changerait une peine. Le mecanisme existe pour accueillir l''arbitrage ; il ne le prejuge pas.';
COMMENT ON TABLE public.infractions_categories IS 'Les quatre categories generiques de PEINES (plateau-core.js) : la peine HERITEE par les actes sans bareme propre. Une categorie est une CLASSE, jamais une charge -- infraction_canonique() refuse un nom de categorie comme qualification.';
COMMENT ON TABLE public.infractions_empreinte IS 'La sentinelle du miroir des infractions, meme patron que villes_empreinte : une seule ligne, l''empreinte POSEE a la derniere generation. infractions_empreinte_reelle() rend celle du contenu courant ; verifier-referentiels.py confronte les deux a celle que le generateur calcule depuis plateau-core.js.';
