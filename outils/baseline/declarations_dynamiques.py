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
    corps = next(x.arg.sval for x in stmt.args if x.defname == 'as')
    tokens = list(scan(corps))
    morceaux = list(corps)
    for t in tokens:
        if t.name in ('SQL_COMMENT', 'C_COMMENT'):
            morceaux[t.start:t.end + 1] = ' ' * (t.end - t.start + 1)
    texte = ''.join(morceaux)
    chaines = [(t.start, t.end) for t in tokens if t.name == 'SCONST']
    def hors_chaine(position):
        return not any(a <= position <= b for a, b in chaines)
    def valeur(litteral):
        return parse_sql('SELECT ' + litteral)[0].stmt.targetList[0].val.val.sval
    lit = r"('(?:[^']|'')*')"
    resultat = []
    source_re = r'(?mi)^\s*(\w+)\s*:=\s*pg_get_functiondef\(\s*' + lit + r'::regprocedure\s*\)\s*;'
    for source in re.finditer(source_re, texte):
        debut = source.start() + len(source[0]) - len(source[0].lstrip())
        if not hors_chaine(debut):
            continue
        variable = source[1]
        identite = valeur(source[2])
        if not re.fullmatch(r'public\.[a-z_0-9]+\([^;]*\)', identite, re.I):
            continue
        ren_re = r'(?mi)^\s*' + re.escape(variable) + r'\s*:=\s*replace\(\s*' + re.escape(variable) + r'\s*,\s*(\w+)\s*,\s*' + lit + r'\s*\)\s*;'
        for ren in re.finditer(ren_re, texte[source.end():]):
            position = source.end() + ren.start()
            if not hors_chaine(position + len(ren[0]) - len(ren[0].lstrip())):
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
