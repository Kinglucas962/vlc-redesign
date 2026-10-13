# M0 — Fundação

Execução iniciada em 12/10/2026, America/Recife. Atualizar resultados após cada prova.

## Base e repositório

- Fork: [SrDouglax/JuxtopposedVLC](https://github.com/SrDouglax/JuxtopposedVLC), confirmado como filho de `videolan/vlc` pela API GitHub.
- Base upstream fixa: `392bc1d0abdb7396b6c97fef206efa1d23868e19`.
- Linha: VLC 4.0 em desenvolvimento, interface Qt6/QML. Essa escolha reaproveita os componentes modernos; não é uma promessa de estabilidade de release.
- Branch de execução: `chore/m0`. Histórico upstream preservado; `origin` aponta para o fork e `upstream` para VideoLAN.
- Plano anterior preservado em `.specs/` antes do checkout. Nenhuma alteração na interface ou no motor integra M0.

## Linux

Host Zorin 18.1, base Ubuntu 24.04, x86_64, sessão Wayland com XWayland disponível. Qt6Core local 6.4.2, mas faltavam ferramentas/dependências Quick. Evitar alterar o Qt instalado.

Build isolado em Docker Ubuntu 24.04, imagem base fixada por digest; dependências de distribuição e Qt6 6.4.2. O configure upstream exige Qt >= 6.2. A biblioteca de mídia exige >= 0.13.0, mas a distribuição oferece 0.12.3: usar contrib upstream 0.13.2, isolado no diretório de build.

Autotools escolhido conforme documentação upstream; Meson continua experimental para o build do VLC. O uso de Meson no contrib medialibrary segue seu build próprio.

Comandos reproduzíveis:

```sh
docker build -t juxtopposed-vlc-m0-linux -f extras/juxtopposed/linux.Dockerfile .
docker run -d --name juxtopposed-vlc-m0-linux --cpus=2 --memory=4g --memory-swap=6g \
  -v "$PWD:/work" juxtopposed-vlc-m0-linux sleep infinity
docker exec juxtopposed-vlc-m0-linux sh extras/juxtopposed/linux.sh
```

`M0_JOBS` controla paralelismo; padrão 1 nesta máquina. Diretórios `build-m0/` são ignorados pelo Git. Não instalar sobre o VLC do usuário.

Flags iniciais: GUI Qt e medialibrary habilitadas; skins2, NLS e módulos Rust desabilitados; C/C++ `-O0 -g0` para baseline de desenvolvimento com baixo custo de compilação. Isso não é configuração final de distribuição nem benchmark de release. Comparações futuras devem usar a mesma configuração.

Logs completos permanecem no build; publicar resultados e recortes necessários ao diagnóstico, sem arquivos privados.

## Windows

Preparação independente da prova Linux: usa a mesma base upstream inalterada e runner remoto, portanto T04 passa a depender de T01. A alteração na ordem evita disputa de recursos sem remover nenhum critério de aceite.

Rota: imagem oficial VideoLAN pinada + contrib upstream validado por checksum + cross-build MinGW/Autotools + pacote portátil e evidência. Detalhes e resultados em [windows.md](windows.md).

## Critérios ainda a preencher

| Prova | Estado inicial |
| --- | --- |
| Fork remoto e checkout | Comprovados |
| Bootstrap Autotools | Executado com sucesso |
| Ambiente Linux isolado | Imagem construída |
| Build Linux Qt + medialibrary | Em execução |
| Reprodução e interações Linux | Pendente |
| Captura nativa e recursos | Pendente |
| Matriz Figma → código | Em execução |
| Build e artefato Windows | Workflow em preparação |
| Carregamento nativo Windows | Pendente |

M0 somente concluído quando seus critérios estiverem atendidos. Prova gráfica X11 em servidor virtual e prova Wayland no desktop serão descritas separadamente; áudio em sink de teste não equivale a escuta nos alto-falantes.
