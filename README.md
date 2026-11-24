# Archiva Import

Plugin para 3ds Max 2024+ que importa um `.3ds` do SketchUp e roda o fluxo completo com um clique:

Import → Collapse → Weld (0.001, configuravel) → Attach (all in one, Editable Poly) → Detach by ID (nome do material) → UVW Map Box 100×100×100 Real-World.

## Estrutura

```
install/ArchivaImport_Loader.ms   carregador (instala 1x; baixa e atualiza o plugin)
src/main.ms                     codigo do plugin (etapas, pipeline, interface)
version.txt                     versao atual (o carregador compara com a instalada)
```

## Publicar no GitHub (uma vez)

1. Crie um repositorio **publico** (ex.: `matiz-import`) e envie estes arquivos na branch `main`.
2. Em `install/ArchivaImport_Loader.ms`, troque `coutocdouglas/Archiva-Import` pelo seu repositorio
   (ou crie o `.ini` descrito abaixo).

> O codigo baixado do repositorio e executado dentro do seu Max. Proteja a conta do GitHub com 2FA.

## Instalar no Max (uma vez por versao do Max)

1. No Max, no Listener, rode `getDir #startupScripts` e copie `ArchivaImport_Loader.ms` para essa pasta.
2. Reinicie o Max. O plugin e baixado para `getDir #userScripts` + `\MatizImport\current`.
3. Em *Customize User Interface → Toolbars/Quads*, categoria **Archiva**, arraste **Archiva Import** para onde quiser.

## Atualizar

- **Automatico:** a cada abertura do Max o carregador compara `version.txt` do GitHub com a instalada.
- **Manual:** botao *Verificar atualizacoes* na janela do plugin.
- Para lancar uma versao nova: altere o codigo, suba o `version.txt` (ex.: `0.1.1`) e envie para `main`.

## Configuracao

Salva em `getDir #plugcfg` + `\MatizImport.ini` (nao e sobrescrita pelas atualizacoes):

```ini
[Update]
Repo=usuario/repositorio
Auto=true

[Dev]
Path=C:\Users\Douglas\Documents\Dev\Archiva Plugin
```

`[Dev] Path` faz o carregador usar a pasta local (sem baixar do GitHub). Apague a linha para voltar ao normal.

## Roadmap

- Fase 2: trocar materiais do SketchUp pelos da sua biblioteca, por nome.
- Fase 3: substituir blocos selecionados por objetos da biblioteca.
