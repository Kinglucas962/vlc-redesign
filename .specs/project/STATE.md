# Estado

Atualizado em 12/10/2026, America/Recife. M0 em execução.

## Comprovado

- Fork [SrDouglax/JuxtopposedVLC](https://github.com/SrDouglax/JuxtopposedVLC) criado e confirmado pela API GitHub.
- Base `392bc1d0abdb7396b6c97fef206efa1d23868e19`, branch `chore/m0`, histórico upstream preservado.
- Bootstrap Autotools bem-sucedido; nenhum arquivo-fonte upstream alterado.
- Imagem Linux isolada criada: Ubuntu 24.04, Qt6 6.4.2; biblioteca de mídia 0.13.2 em compilação pelo contrib upstream.
- Imagem oficial Windows e contrib da base disponíveis, com digest/checksum verificados; workflow de build portátil e teste básico de carregamento nativo preparado.

## Em execução / pendente

- T02: matriz completa de telas e grupos de componentes; inspeção visual limitada pela quota do conector Figma, com estados de prova separados.
- T03: build Linux, reprodução/interações, captura e baseline de recursos.
- T04: push e execução CI, artefato Windows, teste básico de carregamento. Janela/vídeo/áudio Windows ainda exigem validação posterior.
- Nenhum redesign iniciado; M1 depende das provas da fundação.

## Organização

- Coordenador conduz base/build Linux, revisão e integração.
- Frente de design executa T02; frente Windows prepara e acompanha T04.
- Nenhum subagente usa Astra. Execução dos subagentes autorizada pelo pedido de fazer M0.
- Windows build depende de T01, em paralelo ao baseline Linux: mesma base original e runner remoto, sem disputa local de recursos.

## Próxima ação

Concluir T02/T03/T04, registrar provas e limitações em foundation.md e windows.md, publicar a branch e evidência. Não avançar para M1 antes de resolver impedimentos essenciais da fundação.
