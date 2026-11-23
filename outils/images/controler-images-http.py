#!/usr/bin/env python3
"""HEAD des images inventoriées, sans authentification ni appel métier.

Les exports de base et le rapport HTTP complet restent privés : ils peuvent
contenir des URL de portraits ou d'images fournies par les joueurs.
"""
import argparse
import concurrent.futures
import datetime
import json
import pathlib
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]


def verifier(url):
    cible = url if url.startswith(('http://', 'https://')) else 'https://human-gambit.com/' + url.lstrip('/')
    cible = urllib.parse.quote(cible, safe=':/?=&%+@,')
    try:
        with urllib.request.urlopen(urllib.request.Request(cible, method='HEAD'), timeout=25) as r:
            mime = r.headers.get('Content-Type', '')
            return {'url': url, 'status': r.status, 'type': mime,
                    'image_200': r.status == 200 and mime.startswith('image/')}
    except urllib.error.HTTPError as e:
        return {'url': url, 'status': e.code, 'image_200': False, 'erreur': str(e)}
    except (OSError, ValueError) as e:
        return {'url': url, 'image_200': False, 'erreur': str(e)}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--code', type=pathlib.Path, required=True)
    p.add_argument('--parcours', type=pathlib.Path, required=True)
    p.add_argument('--base', type=pathlib.Path)
    p.add_argument('--rapport', type=pathlib.Path, required=True)
    a = p.parse_args()
    urls = {r['url'] for r in json.loads(a.code.read_text())['urls']}
    urls.update(r['url'] for r in json.loads(a.parcours.read_text())['references'])
    if a.base:
        urls.update(r['image_path'] for r in json.loads(a.base.read_text())
                    if r['image_path'].startswith(('images/', '/images/', 'https://', 'http://')))
    # Les anciens liens persistés doivent aussi fonctionner : la source d'un
    # alias n'est pas un fichier Git, sa destination doit en être un.
    config = json.loads((ROOT / 'vercel.json').read_text())
    urls.update(r['source'] for r in config.get('rewrites', []) if r['source'].startswith('/images/'))
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executer:
        resultats = list(executer.map(verifier, sorted(urls)))
    rapport = {'date_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'methode': 'HEAD, aucune identité ni RPC métier', 'urls': len(urls),
               'images_200': sum(r['image_200'] for r in resultats), 'references': resultats}
    a.rapport.write_text(json.dumps(rapport, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in rapport.items() if k != 'references'}, ensure_ascii=False))
