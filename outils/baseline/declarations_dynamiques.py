"""En-têtes dérivés par DO : inventaire statique, jamais preuve de déploiement.

Sous-ensemble volontairement strict : copie pg_get_functiondef d'une signature
constante, renommage par replace avec une ancre constante, puis EXECUTE de cette
même variable. Les commentaires et textes non exécutés ne déclarent rien.
"""
import re
from pglast import parse_sql, scan


def derives(stmt):
    if type(stmt).__name__ != 'DoStmt':
        return []
    langue = next((x.arg.sval for x in stmt.args if x.defname == 'language'), 'plpgsql')
    if langue.lower() != 'plpgsql':
        return []
    corps = next(x.arg.sval for x in stmt.args if x.defname == 'as')
    tokens = list(scan(corps))
    morceaux = list(corps)
    for t in tokens:
        if t.name in ('SQL_COMMENT', 'C_COMMENT'):
            morceaux[t.start:t.end + 1] = ' ' * (t.end - t.start + 1)
    texte = ''.join(morceaux)
    chaines = [(t.start, t.end) for t in tokens if t.name == 'SCONST']
    def niveau(position):
        profondeur = 0
        precedent = None
        for t in tokens:
            if t.start >= position:
                break
            if t.name in ('SQL_COMMENT', 'C_COMMENT', 'SCONST'):
                continue
            mot = corps[t.start:t.end + 1].upper()
            if mot in ('IF', 'LOOP'):
                profondeur += -1 if precedent == 'END' else 1
            precedent = mot
        return profondeur

    def hors_chaine(position):
        return not any(a <= position <= b for a, b in chaines)
    def valeur(litteral):
        return parse_sql('SELECT ' + litteral)[0].stmt.targetList[0].val.val.sval
    lit = r"('(?:[^']|'')*')"
    resultat = []
    source_re = r'(?mi)^\s*(\w+)\s*:=\s*pg_get_functiondef\(\s*' + lit + r'::regprocedure\s*\)\s*;'
    for source in re.finditer(source_re, texte):
        debut = source.start() + len(source[0]) - len(source[0].lstrip())
        if not hors_chaine(debut) or niveau(debut) != 0:
            continue
        variable = source[1]
        identite = valeur(source[2])
        if not re.fullmatch(r'public\.[a-z_0-9]+\([^;]*\)', identite, re.I):
            continue
        ren_re = r'(?mi)^\s*' + re.escape(variable) + r'\s*:=\s*replace\(\s*' + re.escape(variable) + r'\s*,\s*(\w+)\s*,\s*' + lit + r'\s*\)\s*;'
        for ren in re.finditer(ren_re, texte[source.end():]):
            position = source.end() + ren.start()
            if not hors_chaine(position + len(ren[0]) - len(ren[0].lstrip())) or niveau(position + len(ren[0]) - len(ren[0].lstrip())) != 0:
                continue
            if re.search(r'(?mi)^\s*' + re.escape(variable) + r'\s*:=', texte[source.end():position]):
                continue
            ancre = ren[1]
            declarations = list(re.finditer(r'(?mi)^\s*' + re.escape(ancre) + r'\s+text\s*:=\s*' + lit + r'\s*;', texte[:source.start()]))
            if len(declarations) != 1:
                continue
            ancien = valeur(declarations[0][1])
            nouveau = valeur(ren[2])
            if not re.fullmatch(r'public\.[a-z_0-9]+\([^;]*\)', nouveau, re.I):
                continue
            try:
                prefixe = 'CREATE FUNCTION '
                suffixe = " RETURNS jsonb LANGUAGE sql AS '';"
                src = parse_sql(prefixe + identite + suffixe)[0].stmt
                anc = parse_sql(prefixe + ancien + suffixe)[0].stmt
                cible = parse_sql(prefixe + nouveau + suffixe)[0].stmt
            except Exception:
                continue
            # L'ancre doit décrire précisément la fonction copiée, pas une autre.
            def signature(st):
                return ([x.sval for x in st.funcname], [([x.sval for x in p.argType.names],len(p.argType.arrayBounds or ())) for p in st.parameters or []])
            if signature(src) != signature(anc):
                continue
            fin_ren = source.end() + ren.end()
            suite = texte[fin_ren:]
            executions = list(re.finditer(r'(?mi)^\s*EXECUTE\s+' + re.escape(variable) + r'\s*;', suite))
            if not executions:
                continue
            execution = executions[0]
            if not hors_chaine(fin_ren + execution.start() + len(execution[0]) - len(execution[0].lstrip())):
                continue
            position_execution = fin_ren + execution.start() + len(execution[0]) - len(execution[0].lstrip())
            if niveau(position_execution) != 0:
                continue
            if any(t.name not in ('SCONST', 'SQL_COMMENT', 'C_COMMENT')
                   and corps[t.start:t.end + 1].upper() == 'RETURN'
                   and source.end() <= t.start < position_execution for t in tokens):
                continue
            # Pas de réaffectation opaque entre la copie et son exécution.
            segment = texte[source.end():fin_ren + execution.start()]
            affectations = list(re.finditer(r'(?mi)^\s*' + re.escape(variable) + r'\s*:=\s*([^;]*);', segment))
            if any(not re.match(r'replace\(\s*' + re.escape(variable) + r'\s*,', a[1], re.I) for a in affectations):
                continue
            if re.search(r'(?mi)^\s*' + re.escape(ancre) + r'\s*:=', texte):
                continue
            opaque = False
            for affectation in re.finditer(r'(?mi)^\s*' + re.escape(variable) + r'\s*:=\s*replace\(\s*' + re.escape(variable) + r'\s*,\s*(\w+)\s*,', suite[:execution.start()]):
                nom_ancre = affectation[1]
                constantes = list(re.finditer(r'(?mi)^\s*' + re.escape(nom_ancre) + r'\s+text\s*:=\s*' + lit + r'\s*;', texte[:source.start()]))
                if (nom_ancre == ancre or len(constantes) != 1
                    or valeur(constantes[0][1]).lstrip().lower().startswith(('public.', 'create '))
                    or re.search(r'(?mi)^\s*' + re.escape(nom_ancre) + r'\s*:=', texte)):
                    opaque = True
            # Un renommage ultérieur avec un littéral/une expression sort aussi du sous-ensemble.
            suivantes = list(re.finditer(r'(?mi)^\s*' + re.escape(variable) + r'\s*:=', suite[:execution.start()]))
            reconnues = list(re.finditer(r'(?mi)^\s*' + re.escape(variable) + r'\s*:=\s*replace\(\s*' + re.escape(variable) + r'\s*,\s*\w+\s*,', suite[:execution.start()]))
            if opaque or len(suivantes) != len(reconnues):
                continue
            resultat.append((src, cible))
    return resultat


def extensions_parametres(texte, signatures_connues, noms_connus=None):
    """Inventorie l'ajout constant de paramètres à une définition connue, exécuté par DO.

    Aucun PL/pgSQL exécuté : on exige copie constante, replace à littéraux, même
    variable EXECUTE au premier niveau et aucun retour/réaffectation opaque.
    Ne reconnaît pas un corps, un commentaire ou un GRANT comme une création.
    """
    from pglast import ast
    resultat = set()
    def canon(st):
        noms=[]
        for p in st.parameters or ():
            t='.'.join(x.sval for x in p.argType.names).removeprefix('pg_catalog.')
            noms.append({'int4':'integer','int8':'bigint','bool':'boolean'}.get(t,t)+('[]' if p.argType.arrayBounds else ''))
        return st.funcname[-1].sval+'('+','.join(noms)+')'
    def constante(x):
        return x.val.sval if isinstance(x,ast.A_Const) and isinstance(x.val,ast.String) else None
    def colonne(x):
        return x.fields[0].sval if isinstance(x,ast.ColumnRef) and len(x.fields)==1 else None
    def entete(nom,args):
        return parse_sql('CREATE FUNCTION '+nom+'('+args+") RETURNS jsonb LANGUAGE sql AS ''; ")[0].stmt
    for raw in parse_sql(texte):
        st=raw.stmt
        if type(st).__name__!='DoStmt':continue
        if any(a.defname=='language' and a.arg.sval.lower()!='plpgsql' for a in st.args):continue
        corps=next(a.arg.sval for a in st.args if a.defname=='as')
        ts=[t for t in scan(corps) if t.name not in ('SQL_COMMENT','C_COMMENT')]
        sans_chaines=list(corps)
        for tok in ts:
            if tok.name=='SCONST':sans_chaines[tok.start:tok.end+1]=' '*(tok.end-tok.start+1)
        code=''.join(sans_chaines)
        variables={};profondeur=0;precedent='';invalide=False;retour=False
        for i,t in enumerate(ts):
            mot=corps[t.start:t.end+1];maj=mot.upper()
            if t.name=='SCONST':continue
            if maj in ('IF','LOOP','CASE'):
                profondeur+=-1 if precedent=='END' else 1
            if maj=='RETURN':retour=True
            if i+1<len(ts) and corps[ts[i+1].start:ts[i+1].end+1]==':=':
                # Les affectations conditionnelles ne peuvent attester une déclaration.
                fin=next((z for z in ts[i+2:] if z.name!='SCONST' and corps[z.start:z.end+1]==';'),None)
                if fin is None:invalide=True;break
                try:e=parse_sql('SELECT '+corps[ts[i+2].start:fin.start])[0].stmt.targetList[0].val
                except Exception:invalide=True;break
                if profondeur or not isinstance(e,ast.FuncCall):variables.pop(mot,None);precedent=maj;continue
                fn=e.funcname[-1].sval;args=e.args or ()
                if fn=='pg_get_functiondef' and len(args)==1 and isinstance(args[0],ast.TypeCast):
                    identite=constante(args[0].arg)
                    if identite and re.fullmatch(r'public\.[a-z_0-9]+\([^;]*\)',identite,re.I):
                        nom,params=identite[:-1].split('(',1);source=entete(nom,params)
                        if canon(source) in signatures_connues:variables[mot]=(source,None,())
                elif fn=='replace' and len(args)==3 and colonne(args[0]) in variables:
                    source,cible,noms=variables[colonne(args[0])];ancien=constante(args[1]);nouveau=constante(args[2])
                    if ancien is None or nouveau is None:variables.pop(mot,None);precedent=maj;continue
                    if cible is None:
                        if not ancien.endswith(')') or not nouveau.endswith(')'):variables.pop(mot,None);precedent=maj;continue
                        try:
                            a=entete('public.x',ancien[:-1]);b=entete('public.x',nouveau[:-1])
                            assert len(a.parameters)==1 and len(b.parameters)>1
                            assert canon(a)==canon(entete('public.x',','.join('.'.join(z.sval for z in p.argType.names) for p in source.parameters[-1:])))
                            assert b.parameters[0].name==a.parameters[0].name
                            assert noms_connus and noms_connus.get(canon(source))
                            assert a.parameters[0].name==noms_connus[canon(source)][-1]
                            assert canon(entete('public.x',ancien[:-1]))==canon(entete('public.x',nouveau[:-1].split(',',1)[0]))
                            rest=','.join('.'.join(z.sval for z in p.argType.names) for p in source.parameters[:-1])
                            cible=entete('public.'+source.funcname[-1].sval,(rest+',' if rest else '')+nouveau[:-1]);noms=tuple(p.name for p in b.parameters)
                        except Exception:variables.pop(mot,None);precedent=maj;continue
                    elif re.search(r'\b(?:CREATE|FUNCTION|'+source.funcname[-1].sval+r')\s*\(',ancien,re.I) or any(re.search(r'\b'+re.escape(n)+r'\s+(?:text|integer|numeric|jsonb)\b',ancien) for n in noms if n):
                        variables.pop(mot,None);precedent=maj;continue
                    variables[mot]=(source,cible,noms)
                else:variables.pop(mot,None)
            if maj=='EXECUTE' and i+2<len(ts):
                v=corps[ts[i+1].start:ts[i+1].end+1]
                if profondeur==0 and not retour and not invalide and corps[ts[i+2].start:ts[i+2].end+1]==';' and v in variables and variables[v][1] is not None and not re.search(r'\bINTO\s+'+re.escape(v)+r'\b|(?m:^\s*'+re.escape(v)+r'\s*=)',code,re.I):
                    resultat.add(canon(variables[v][1]))
            precedent=maj
    return resultat
