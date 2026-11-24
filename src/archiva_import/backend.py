"""Ponte com o 3ds Max (pymxs). Fora do Max (testes/visualizacao) tudo vira um simulador simples."""
import os
from pathlib import Path

try:
    from pymxs import runtime as rt
except Exception:  # fora do 3ds Max
    rt = None

ROOT = Path(__file__).resolve().parents[2]


def in_max():
    return rt is not None


def cfg_path():
    if rt is not None:
        return os.path.join(str(rt.getDir(rt.Name("plugcfg"))), "MatizImport.ini")
    return os.path.join(os.environ.get("TEMP", "."), "MatizImport_preview.ini")


def version():
    try:
        return (ROOT / "version.txt").read_text(encoding="utf-8").strip().splitlines()[0]
    except (OSError, IndexError):
        return "?"


def max_main_window():
    try:
        from qtmax import GetQMaxMainWindow
        return GetQMaxMainWindow()
    except Exception:
        return None


def run_import(path):
    """Roda o fluxo de importacao (nucleo em MaxScript: src/main.ms). Devolve o resumo em texto."""
    if rt is None:
        return "Simulacao (fora do 3ds Max):\nImportados: 42 objetos\nConclu^ido em 1.2 s"
    if not bool(rt.execute("MatizImport != undefined")):
        return "O nucleo do plugin nao carregou. Reinicie o 3ds Max."
    p = str(path).replace("/", "\\")
    return str(rt.execute('MatizImport.loadConfig(); MatizImport.run @"%s"' % p))


def check_update():
    """Devolve (mensagem, atualizou)."""
    if rt is None:
        return "Simulacao: voce ja esta na versao %s." % version(), False
    if not bool(rt.execute("MatizLoader != undefined")):
        return "Carregador nao encontrado. Reinstale o Archiva Import.", False
    msg = str(rt.execute("MatizLoader.checkAndUpdate()"))
    updated = bool(rt.execute("MatizLoader.updated"))
    if updated:
        rt.execute("MatizLoader.loadMain()")
    return msg, updated
