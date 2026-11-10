# GBA Wrap (iOS)

App iOS simples que embute o núcleo [mGBA](https://mgba.io) (interface libretro) e abre **uma ROM que fica dentro do próprio app**, com controles na tela, som, save automático e modo acelerado.

Este repositório **não contém nenhuma ROM** nem arquivo de jogo. Ele só tem o código do app. A ROM é colocada no `.ipa` depois de compilado, no computador de quem vai usar, e o app resultante serve só para uso pessoal.

## Como funciona

1. O GitHub Actions (macOS) compila o núcleo mGBA para iOS e o app, e gera `GBAWrap.ipa` sem assinatura e sem ROM.
2. Você baixa o `.ipa`, coloca o arquivo da sua ROM como `Game.gba` dentro de `Payload/GBAWrap.app/` (veja `scripts/inject_rom.py`).
3. Você instala no iPhone com uma ferramenta que assina o app com o seu Apple ID, como o AltStore ou o Sideloadly. Com Apple ID gratuito a assinatura vale 7 dias e precisa ser renovada.

O save do jogo fica em `Documents/Jogo.sav` dentro do app e é gravado a cada poucos segundos e ao sair do app.

## Controles

- Direcional, A, B, L, R, Start e Select na tela.
- Botão "ACELERAR" liga o modo turbo (4x, sem som).

## Licenças

- O código deste repositório: MIT (veja `LICENSE`).
- mGBA: MPL 2.0, baixado e compilado durante o build ([código-fonte](https://github.com/mgba-emu/mgba)). Quem redistribuir o `.ipa` compilado precisa seguir os termos da MPL 2.0.
- Os jogos são propriedade dos seus donos. Use só ROMs que você tem o direito de usar.
