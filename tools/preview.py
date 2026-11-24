"""Gera imagens da interface fora do 3ds Max (para conferir o visual).

Uso:  python tools/preview.py <pasta de saida>
Precisa de PySide6 (ou PySide2) instalado.
"""
import os
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ["TEMP"] = tempfile.mkdtemp()          # nao mexe nas suas configuracoes reais
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from archiva_import import ui, theme   # noqa: E402
from archiva_import.qt import QtWidgets  # noqa: E402

out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
out.mkdir(parents=True, exist_ok=True)
app = QtWidgets.QApplication([])
theme.load_fonts()
print("fonte:", theme.UI_FAMILY)

win = ui.MainWindow()
win.setStyleSheet(theme.stylesheet())
win.show()
app.processEvents()
win.grab().save(str(out / "1_principal.png"))

for b in win.chips.values():
    b.setChecked(True)
win.name_edits["Group"].setText("Casa_Cliente")
win.name_edits["Layer"].setText("Modelo SketchUp")
app.processEvents()
win.grab().save(str(out / "1b_opcoes_ligadas.png"))

win.log.setPlainText(ui.tr("Importados: 128 objetos\nCollapse: 128 objetos\nWeld: threshold 0.001\nAttach: 1 objeto (48210 faces)\nDetach by ID: 14 objetos\nUVW aplicado\nFinal: Editable Poly e pivo na base\nConclu^ido em 3.4 s"))
for s in win.sections:
    s.header.setChecked(True)
app.processEvents()
win.grab().save(str(out / "2_tudo_aberto.png"))

for s in win.sections[1:]:
    s.header.setChecked(False)
app.processEvents()
win.open_settings()
app.processEvents()
win._settings.resize(430, 1350)
app.processEvents()
win._settings.grab().save(str(out / "3_config.png"))
print("ok")
