# Turma da Eita: página para baixar o jogo

https://tecnologia-eita.github.io/turma-da-eita/

A página (`index.html`) mostra o botão do aparelho de quem abre e explica a primeira instalação em cada
um. Os arquivos ficam nos lançamentos deste repositório, com nomes fixos:

| Aparelho | Arquivo |
| --- | --- |
| Windows | `TurmaDaEita-Windows-instalador.exe` e `TurmaDaEita-Windows.exe` (abre sem instalar) |
| Mac | `TurmaDaEita-Mac.dmg` |
| Linux | `TurmaDaEita-Linux.AppImage` e `TurmaDaEita-Linux.tar.gz` |
| Android | `TurmaDaEita-Android.apk` |

No iPhone e no iPad, o jogo abre no Safari e se instala pela tela de início.

Para publicar uma versão nova, gere os executáveis no repositório do jogo (Actions > Executáveis) e
rode aqui `./publicar.sh`. Ele cria o lançamento e atualiza o `versao.json`, que diz à página a versão e
o tamanho de cada arquivo.
