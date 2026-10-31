#!/usr/bin/env python3
"""Recette sur le catalogue entier installé : AUCUN corps serveur remplacé.

Appelée seulement par epreuve-postgresql.py après sa reconstruction locale et
le lot atomique. JWT SQL fictifs, rôle authenticated réel, transactions annulées.
Ce n'est pas une connexion à GoTrue ni une recette en jeu de production.
"""
import uuid


def recette(q):
    noms=['__hg219_alpha','__hg219_beta','__hg219_gamma']
    ids=['00000219-0000-4000-8000-00000000000'+str(i+1) for i in range(3)]
    q.execute('SAVEPOINT recette_catalogue')
    for nom,uid in zip(noms,ids):
        q.execute("SELECT set_config('request.jwt.claim.sub',%s,true),set_config('request.jwt.claims',%s,true)",(uid,'{"sub":"'+uid+'","role":"authenticated"}'))
        q.execute("INSERT INTO auth.users(id,email,is_anonymous,email_confirmed_at) VALUES(%s,%s,false,now())",(uid,nom+'@example.invalid'))
        q.execute("INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,pa,liquide,arg,hp) VALUES(%s,%s,'republic','capitale','mairie','accueil',100,1000,1000,100)",(nom,uid))
    resultats=[]
    def rpc(fn,args=(),qui=0):
        q.execute("SELECT set_config('request.jwt.claims',%s,true),set_config('request.jwt.claim.sub',%s,true),set_config('request.path',%s,true)",
                  ('{"sub":"'+ids[qui]+'","role":"authenticated"}',ids[qui],'/rpc/'+fn))
        q.execute("SELECT set_config('role','authenticated',true)")
        try:
            q.execute('SELECT public.'+fn+'('+','.join(['%s']*len(args))+')',args)
            return q.fetchone()[0]
        finally:q.execute('RESET ROLE')
    def solde():
        q.execute('SELECT name,pa,arg,liquide,current_city,current_building,current_room,current_street FROM personnages_donnees ORDER BY name')
        return q.fetchall()
    def cas(nom,fn):
        q.execute('SAVEPOINT scenario')
        try:fn();resultats.append({'cas':nom,'ok':True})
        except Exception as e:resultats.append({'cas':nom,'ok':False,'erreur':str(e).splitlines()[0]})
        finally:q.execute('ROLLBACK TO SAVEPOINT scenario')
    def exige(v,ok,raison=None):
        assert v.get('ok') is ok,v
        if raison:assert v.get('raison')==raison,v
        return v
    def identite():assert rpc('mon_personnage')==noms[0]
    cas('identite_SQL_sans_remplacement_mon_personnage',identite)
    cas('lecture_groupe_reelle',lambda:exige(rpc('groupe_pj_lire'),True))
    def adhesion():
        avant=solde();v=exige(rpc('groupe_pj_rejoindre',(noms[0],),1),True)
        assert set(v['membres'])==set(noms[:2]),v
        v=exige(rpc('groupe_pj_rejoindre',(noms[0],),1),True)
        assert len(v['membres'])==2,v
        assert solde()==avant
    cas('adhesion_volontaire_et_rejeu_sans_depense',adhesion)
    def cycle():
        exige(rpc('groupe_pj_rejoindre',(noms[0],),1),True)
        exige(rpc('groupe_pj_rejoindre',(noms[1],)),False,'chef_deja_membre')
    cas('cycle_PJ_refuse',cycle)
    cas('auto_adhesion_refusee',lambda:exige(rpc('groupe_pj_rejoindre',(noms[0],)),False,'chef_invalide'))
    def distant():
        q.execute('UPDATE personnages_donnees SET current_room=%s WHERE name=%s',('bureau',noms[1]))
        avant=solde();exige(rpc('groupe_pj_rejoindre',(noms[0],),1),False,'pas_co_presents');assert solde()==avant
    cas('adhesion_distante_refusee_sans_mutation',distant)
    def quitter():
        exige(rpc('groupe_pj_rejoindre',(noms[0],),1),True);avant=solde()
        exige(rpc('groupe_pj_quitter',qui=1),True)
        assert solde()==avant
        q.execute('SELECT count(*) FROM groupes_pj_adhesions WHERE membre=%s',(noms[1],));assert q.fetchone()[0]==0
    cas('depart_groupe_sans_mouvement_ni_debit',quitter)
    def paiement_protege(ordre):
        avant=solde();exige(rpc('payer_ordre',(noms[0],ordre,0,0)),False,'commande_versionnee_requise');assert solde()==avant
    for ordre in ['acheter_terrain','signer_compromis','acte_vente_terrain','emprunter','deposer_demande_permis','louer_lot_ici']:
        cas('protection_paiement_main_'+ordre,lambda ordre=ordre:paiement_protege(ordre))
    def sortie_invalide():
        avant=solde();exige(rpc('rue_position_enregistrer',('noeud-inexistant-219',)),False);assert solde()==avant
    cas('sortie_inconnue_aucune_mutation',sortie_invalide)
    def indisponible(champ,valeur):
        q.execute('UPDATE personnages_donnees SET '+champ+'=%s WHERE name=%s',(valeur,noms[0]))
        avant=solde();exige(rpc('rue_position_enregistrer',('luthecia-hotel-de-ville',)),False);assert solde()==avant
    cas('sortie_coma_refusee_sans_debit',lambda:indisponible('hp',0))
    cas('sortie_prison_refusee_sans_debit',lambda:indisponible('est_emprisonne','{"type":"prison"}'))
    def cible_inconnue():
        avant=solde();exige(rpc('combat_ouvrir',('pnj:__absent_219','mains',str(uuid.uuid4()))),False,'cible_non_referencee');assert solde()==avant
    cas('combat_cible_inconnue_refuse_sans_debit',cible_inconnue)
    cas('lecture_cibles_depuis_schema_complet',lambda:exige(rpc('combat_cibles_lire'),True))
    def ouvrir():
        return exige(rpc('combat_ouvrir',(noms[1],'mains',str(uuid.uuid4()))),True)
    def ouverture_et_rejeu():
        req=str(uuid.uuid4());avant=solde();v=exige(rpc('combat_ouvrir',(noms[1],'mains',req)),True)
        assert v['phase']=='choix',v
        apres=solde();assert apres!=avant
        assert rpc('combat_ouvrir',(noms[1],'mains',req))==v
        assert solde()==apres
        q.execute('SELECT count(*) FROM batailles_engagements WHERE bataille_id=%s',(v['bataille'],));assert q.fetchone()[0]==2
    cas('combat_PJ_reel_ouverture_paiement_unique_rejeu',ouverture_et_rejeu)
    def round_et_rejeu():
        v=ouvrir();b=v['bataille'];req=str(uuid.uuid4())
        r=exige(rpc('militaire_bataille_poursuivre',(b,0,req)),True)
        assert r['round']==1,r
        apres=solde();assert rpc('militaire_bataille_poursuivre',(b,0,req))==r
        assert solde()==apres
    cas('round_reel_et_reponse_perdue_sans_double_effet',round_et_rejeu)
    def non_engage():
        v=ouvrir();avant=solde()
        exige(rpc('militaire_bataille_poursuivre',(v['bataille'],0,str(uuid.uuid4())),2),False,'non_engage')
        assert solde()==avant
    cas('tiers_non_engage_refuse_sans_mutation',non_engage)
    def mixte():
        q.execute("INSERT INTO pnj_membres(id,famille,nom,pays,proprietaire_pj,ville,building_id,room_id,classe,car_int,car_cha,car_vol,car_per,car_dup,car_ent) VALUES('__hg219_agent','employe','Agent fictif 219','republic',%s,'capitale','mairie','accueil','beta',10,10,10,10,10,10)",(noms[0],))
        exige(rpc('pnj_prendre',(['__hg219_agent'],)),True)
        b=ouvrir()['bataille']
        q.execute('SELECT count(*),count(pnj_id) FROM batailles_engagements WHERE bataille_id=%s',(b,));assert q.fetchone()==(3,1)
        exige(rpc('militaire_bataille_poursuivre',(b,0,str(uuid.uuid4()))),True)
    cas('combat_mixte_PJ_PNJ_reel_sans_substitut',mixte)
    def radio_absente():
        avant=solde();exige(rpc('pnj_rappeler_radio',('__agent_absent_219',)),False,'radio_appelant_absente');assert solde()==avant
    cas('rappel_radio_sans_equipement_refuse_sans_mutation',radio_absente)
    def detection():
        avant=solde();v=exige(rpc('police_detection_verifier',('mairie','accueil',None)),False,'aucun_policier_present')
        assert not v.get('detecte'),v
        assert solde()==avant
    cas('detecteur_reel_sans_recherche_ni_fausse_interception',detection)
    def prison():
        exige(rpc('groupe_pj_rejoindre',(noms[0],),1),True)
        q.execute("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',true),set_config('request.jwt.claim.sub','',true),set_config('request.path','/rpc/police_action',true)")
        q.execute("SELECT detention_ouvrir_interne(%s,'Recette isolée',1,'capitale','republic','[]'::jsonb,'police','arrestation',NULL)",(noms[0],))
        exige(q.fetchone()[0],True)
        q.execute('SELECT current_building,current_room,est_emprisonne IS NOT NULL FROM personnages_donnees WHERE name=%s',(noms[0],))
        assert q.fetchone()==('commissariat','prison',True)
        q.execute('SELECT count(*) FROM groupes_pj_adhesions WHERE membre=%s OR chef=%s',(noms[0],noms[0]));assert q.fetchone()[0]==0
        q.execute("SELECT detention_ouvrir_interne(%s,'Recette isolée',1,'capitale','republic','[]'::jsonb,'police','arrestation',NULL)",(noms[0],))
        exige(q.fetchone()[0],False,'cible_deja_detenue')
        q.execute('SELECT count(*) FROM detentions WHERE nom=%s',(noms[0],));assert q.fetchone()[0]==1
    cas('ecrou_reel_position_separation_et_double_appel',prison)
    for signature in ['payer_ordre_interne(text,text,integer,integer,integer)',
                      'navigation_disponibilite_interne(text)',
                      'navigation_commander_personnage_interne(text,text,text,text)',
                      'terrain_squatteurs_issue_bataille_interne(text,text,text,uuid,bigint)']:
        def privee(signature=signature):
            q.execute("SELECT has_function_privilege('authenticated',%s,'EXECUTE')",(signature,));assert q.fetchone()[0] is False
        cas('porte_interne_fermee_'+signature,privee)
    q.execute('ROLLBACK TO SAVEPOINT recette_catalogue')
    return resultats
