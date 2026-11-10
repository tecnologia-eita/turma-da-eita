#!/usr/bin/env python3
"""Baixa um artefato do GitHub Actions em pedaços, por várias conexões ao mesmo tempo.

O `gh run download` usa uma conexão só, e o armazenamento dos artefatos às vezes segura cada conexão
em ~100 KB/s (10/11/2026: 35 min para os 210 MB do Windows), enquanto outras passam de 1,5 MB/s. Com
16 conexões em pedaços de 2 MB, as lentas pesam pouco.

Uso: baixar-artefato.py <dono/repo> <id do artefato> <saida.zip>
"""
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

import requests

repo, artefato, saida = sys.argv[1:4]
token = subprocess.run(['gh', 'auth', 'token'], capture_output=True, text=True, check=True).stdout.strip()
api = f'https://api.github.com/repos/{repo}/actions/artifacts/{artefato}/zip'
trava = threading.Lock()
endereco = {'url': None}


def novo_endereco():
    # o endereço assinado do arquivo vale poucos minutos: pede outro quando expira
    r = requests.get(api, headers={'Authorization': f'Bearer {token}'}, allow_redirects=False, timeout=30)
    r.raise_for_status()
    endereco['url'] = r.headers['Location']


novo_endereco()
tamanho = int(requests.head(endereco['url'], timeout=30).headers['Content-Length'])
PEDACO = 2 * 1024 * 1024
pedacos = [(i, min(i + PEDACO, tamanho) - 1) for i in range(0, tamanho, PEDACO)]
feitos = [0]

with open(saida, 'wb') as f:
    f.truncate(tamanho)


def baixa(p):
    ini, fim = p
    for tentativa in range(8):
        try:
            r = requests.get(endereco['url'], headers={'Range': f'bytes={ini}-{fim}'}, timeout=60)
            if r.status_code in (401, 403):
                with trava:
                    novo_endereco()
                continue
            r.raise_for_status()
            if len(r.content) != fim - ini + 1:
                raise IOError('pedaço incompleto')
            with trava:
                with open(saida, 'r+b') as f:
                    f.seek(ini)
                    f.write(r.content)
                feitos[0] += 1
            return
        except (requests.RequestException, IOError):
            pass
    raise SystemExit(f'não consegui baixar o pedaço {ini}-{fim}')


with ThreadPoolExecutor(16) as ex:
    list(ex.map(baixa, pedacos))
print(f'{saida}: {tamanho // 1048576} MB em {len(pedacos)} pedaços')
