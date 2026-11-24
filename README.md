# Archiva Import

Plugin para 3ds Max 2024 ou mais novo. Importa um `.3ds` do SketchUp e roda o fluxo completo com um clique:

Import → Collapse → Weld (0.001, configuravel) → Attach (all in one, Editable Poly) → Detach by ID (nome do material) → UVW Map Box 100×100×100 Real-World.

## Instalar (uma vez)

1. Baixe o instalador: [ArchivaImport_Setup.exe](download/ArchivaImport_Setup.exe)
2. Feche o 3ds Max, de dois cliques no arquivo e siga os passos. Nao precisa de administrador.
3. Abra o Max (com internet). Ele baixa o plugin sozinho.
4. Em *Customize → Customize User Interface → Toolbars*, categoria **Archiva**, arraste **Archiva Import** para uma barra.

O instalador vale para todas as versoes do Max (2024 em diante). Se voce ja tinha copiado o `ArchivaImport_Loader.ms` (ou `MatizImport_Loader.ms`) para a pasta `scripts\startup` de alguma versao, apague essa copia para nao carregar duas vezes.

## Atualizar

- **Automatico:** a cada abertura do Max, o plugin compara a versao do GitHub com a instalada e atualiza.
- **Manual:** botao *Verificar atualizacoes* na janela.
- **Publicar versao nova (para mim/quem mantem):** alterar o codigo, subir o numero em `version.txt` e enviar para `main`.

## Estrutura

```
install/ArchivaImport_Loader.ms  carregador (vai dentro do instalador)
installer/                       arquivos para gerar o instalador (Inno Setup)
download/ArchivaImport_Setup.exe instalador pronto
src/main.ms                      codigo do plugin
version.txt                      versao atual
```

## Configuracao opcional

Arquivo `getDir #plugcfg` + `\MatizImport.ini` (as atualizacoes nao apagam):

```ini
[Update]
Repo=usuario/repositorio
Auto=true

[Dev]
Path=C:\caminho\do\projeto
```

## Roadmap

- Fase 2: trocar materiais do SketchUp pelos da sua biblioteca, por nome.
- Fase 3: substituir blocos selecionados por objetos da biblioteca.
