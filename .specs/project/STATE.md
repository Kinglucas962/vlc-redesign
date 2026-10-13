# Estado

Atualizado em 13/10/2026, America/Recife. M0 em execução; T01/T02/T03 concluídos, T04 em CI.

## Comprovado

- Fork [SrDouglax/JuxtopposedVLC](https://github.com/SrDouglax/JuxtopposedVLC) criado e confirmado pela API GitHub.
- Base `392bc1d0abdb7396b6c97fef206efa1d23868e19`, branch `chore/m0`, histórico upstream preservado.
- Bootstrap Autotools bem-sucedido; nenhum arquivo-fonte upstream alterado.
- Linux compilado em ambiente isolado: Ubuntu 24.04, GCC 13.3.0, Qt6 6.4.2 e medialibrary contrib tag 0.13.2.
- Smoke X11 PASS: janela Qt/vídeo/legenda, PCM de áudio, pausa/retomada, seek, volume, fullscreen e saída. Captura e snapshot de recursos persistidos em `features/redesign/evidence`.
- Compositor Wayland habilitado com scanner 1.23.1 isolado. Lançador `extras/juxtopposed/open.sh` abre no desktop do host com perfil separado; reprodução `wl_shm`, pausa/retomada e fullscreen via MPRIS comprovados.
- T02: inventário de 103 frames (57 telas/variantes + 46 grupos), IDs e candidatos reais Qt/QML; 11 inspeções visuais, 92 entradas estruturais.
- Windows: primeiro cross-build compilou/empacotou, mas falhou antes de criar o ZIP por metadado Qt ausente. Correção publicada; nova execução [38341757506](https://github.com/SrDouglax/JuxtopposedVLC/actions/runs/38341757506) em andamento.

## Em execução / pendente

- T04: concluir CI, publicar artefato/checksum e testar carregamento nativo básico. Janela/vídeo/áudio Windows continuam para validação posterior.
- Figma: quota do conector limitou inspeção visual. IDs estruturais precisam de contexto visual antes de sua implementação.
- Linux: Qt Quick em software e decodificação por CPU; aceleração GPU/hardware ainda sem prova. Áudio capturado em sink de teste, sem comprovação nos alto-falantes.
- Nenhum redesign iniciado; M1 depende das provas da fundação.

## Organização

- Coordenador conduz base/build Linux, revisão e integração.
- Frente de design executa T02; frente Windows prepara e acompanha T04.
- Nenhum subagente usa Astra. Execução dos subagentes autorizada pelo pedido de fazer M0.
- Windows build depende de T01, em paralelo ao baseline Linux: mesma base original e runner remoto, sem disputa local de recursos.

## Próxima ação

Concluir T04 e registrar artefato/resultado nativo em windows.md. Não iniciar M1 neste pedido.
