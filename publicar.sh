#!/bin/bash
# Publica uma versão nova do jogo nesta página de download.
# Pega os executáveis de uma rodada verde do "Executáveis" no repositório do jogo (a mais recente, se
# não disser qual), cria aqui o lançamento v<versão> com os nomes fixos que a página usa e grava o
# versao.json, que diz à página a versão, o endereço e o tamanho de cada arquivo.
# Uso: ./publicar.sh [id da rodada] [pasta com os artefatos dessa rodada já baixados]
set -euo pipefail
cd "$(dirname "$0")"
JOGO=tecnologia-eita/jogo-eita
AQUI=tecnologia-eita/turma-da-eita
RODADA=${1:-$(gh run list -R "$JOGO" --workflow executaveis.yml --status success --limit 1 --json databaseId -q '.[0].databaseId')}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

R=${2:-$T/rodada}
if [ -z "${2:-}" ]; then
  # o download dos artefatos às vezes devolve 503 ("Egress is over the account limit"): tenta de novo.
  # Só os que a rodada tem (o Mac pode ter sido cancelado na fila do GitHub)
  TEM=$(gh api "repos/$JOGO/actions/runs/$RODADA/artifacts" -q '.artifacts[] | select(.expired | not) | .name')
  for n in Windows Mac Linux Android; do
    grep -qx "turma-da-eita-$n" <<<"$TEM" || { echo "(a rodada não tem $n)"; continue; }
    for t in 1 2 3 4 5; do
      rm -rf "${R:?}/$n"
      gh run download "$RODADA" -R "$JOGO" -n "turma-da-eita-$n" -D "$R/$n" && [ -n "$(ls "$R/$n")" ] && break
      [ "$t" = 5 ] && { echo "não consegui baixar $n"; exit 1; }
      sleep 20
    done
  done
fi

mkdir "$T/pub"
pega() { # pega <padrão do arquivo na rodada> <nome fixo>
  local f
  f=$(find "$R" -name "$1" | head -1)
  if [ -n "$f" ]; then cp "$f" "$T/pub/$2"; else echo "(esta rodada não tem $2)"; fi
}
pega '*-windows-instalador.exe' TurmaDaEita-Windows-instalador.exe
pega '*-windows.exe' TurmaDaEita-Windows.exe
pega '*-mac.dmg' TurmaDaEita-Mac.dmg
pega '*-linux.AppImage' TurmaDaEita-Linux.AppImage
pega '*-linux.tar.gz' TurmaDaEita-Linux.tar.gz
pega 'TurmaDaEita-android.apk' TurmaDaEita-Android.apk

VERSAO=$(find "$R" -name 'TurmaDaEita-[0-9]*' | sed -nE 's/.*TurmaDaEita-([0-9][0-9.]*[0-9])-.*/\1/p' | head -1)
DATA=$(gh run view "$RODADA" -R "$JOGO" --json createdAt -q '.createdAt[:10]')
[ -n "$VERSAO" ] || { echo "não achei a versão nos nomes dos arquivos"; exit 1; }
echo "versão $VERSAO, de $DATA"

NOTAS="O jogo da Turma da Eita, versão $VERSAO. Para baixar e ver como instalar: https://tecnologia-eita.github.io/turma-da-eita/"
if gh release view "v$VERSAO" -R "$AQUI" >/dev/null 2>&1; then
  # o lançamento já existe: sobe só o que falta ou mudou de tamanho
  JA=$(gh release view "v$VERSAO" -R "$AQUI" --json assets -q '.assets[] | "\(.name) \(.size)"')
  for f in "$T"/pub/*; do
    grep -qxF "$(basename "$f") $(stat -c %s "$f")" <<<"$JA" || gh release upload "v$VERSAO" -R "$AQUI" --clobber "$f"
  done
else
  gh release create "v$VERSAO" -R "$AQUI" --title "Turma da Eita $VERSAO" --notes "$NOTAS" "$T"/pub/*
fi

# o aparelho que faltou nesta rodada (o Mac fica na fila do GitHub e às vezes é cancelado) continua
# com o arquivo da versão anterior, pelo endereço dela, até uma rodada nova trazer o dele
python3 - "$T/pub" "$VERSAO" "$DATA" versao.json > "$T/versao.json" <<'PY'
import json, os, sys
pasta, versao, data, antigo = sys.argv[1:5]
novo = {
    "versao": versao,
    "data": data,
    "base": f"https://github.com/tecnologia-eita/turma-da-eita/releases/download/v{versao}/",
    "arquivos": {f: os.path.getsize(os.path.join(pasta, f)) for f in sorted(os.listdir(pasta))},
}
enderecos = {}
if os.path.exists(antigo):
    v = json.load(open(antigo, encoding="utf-8"))
    for f, tam in v.get("arquivos", {}).items():
        if f not in novo["arquivos"] and v["versao"] != versao:
            novo["arquivos"][f] = tam
            enderecos[f] = v.get("enderecos", {}).get(f, v["base"] + f)
            print(f"({f} continua o da versão {v['versao']})", file=sys.stderr)
if enderecos:
    novo["enderecos"] = enderecos
print(json.dumps(novo, indent=2, ensure_ascii=False))
PY
mv "$T/versao.json" versao.json
git add versao.json
git commit -m "versão $VERSAO"
git push
echo "pronto: https://tecnologia-eita.github.io/turma-da-eita/ (o GitHub Pages leva um minuto para atualizar)"
