"""Identidade visual (mesma linha do Archiva: grafite quente + pergaminho).

Cores, fontes e acabamento adaptados do tema do Archiva (app/theme.py).
"""
import json
from pathlib import Path

from .qt import QtCore, QtGui, Qt

QPointF, QRectF = QtCore.QPointF, QtCore.QRectF
QColor, QFont, QFontDatabase = QtGui.QColor, QtGui.QFont, QtGui.QFontDatabase
QLinearGradient, QRadialGradient = QtGui.QLinearGradient, QtGui.QRadialGradient
QPainterPath, QPen = QtGui.QPainterPath, QtGui.QPen

ROOT = Path(__file__).resolve().parents[2]   # pasta do plugin (contem src, assets, version.txt)
ASSETS = ROOT / "assets"

TEXT = QColor("#f1e9dc")
MUTED = QColor("#a89c8c")
FAINT = QColor("#75695c")
LOGO = QColor("#efe2c9")
LINK = QColor("#d8c29c")
HILITE = QColor("#e3cfa9")
BTN_TOP = QColor("#f0e6d4")
BTN_BOTTOM = QColor("#ddcdb2")
BTN_TEXT = QColor("#26150c")
FIELD = QColor("#1d1814")
DIALOG = QColor("#1a1512")
OK = QColor("#7fb48a")
BAD = QColor("#d27a6a")

BG_STOPS = [(0.0, "#15110e"), (0.30, "#1b1612"), (0.55, "#141210"), (0.80, "#1a1612"), (1.0, "#14110f")]

UI_FAMILY = "Segoe UI"
_fonts_loaded = False


def rgba(c, a):
    c = QColor(c)
    c.setAlphaF(a)
    return c


def load_fonts():
    """Carrega a ZT Nature (a fonte do Archiva); se nao der, usa Segoe UI."""
    global UI_FAMILY, _fonts_loaded
    if _fonts_loaded:
        return
    _fonts_loaded = True
    for f in sorted((ASSETS / "fonts").glob("*.ttf")):
        i = QFontDatabase.addApplicationFont(str(f))
        if i >= 0:
            fams = QFontDatabase.applicationFontFamilies(i)
            if fams:
                UI_FAMILY = fams[0]


def ui_font(pt=10, bold=True):
    f = QFont(UI_FAMILY)
    f.setPointSizeF(pt)
    f.setBold(bool(bold))
    return f


def logo_path():
    """Desenho vetorial do nome 'Archiva' (mesmo logo.json do Archiva)."""
    path = QPainterPath()
    try:
        d = json.loads((ASSETS / "brand" / "logo.json").read_text(encoding="utf-8"))
        e = d["e"]
        i = 0
        while i < len(e):
            t, x, y = e[i]
            if t == 0:
                path.moveTo(x, y)
            elif t == 1:
                path.lineTo(x, y)
            elif t == 2 and i + 2 < len(e):
                path.cubicTo(x, y, e[i + 1][1], e[i + 1][2], e[i + 2][1], e[i + 2][2])
                i += 2
            i += 1
        path.setFillRule(Qt.OddEvenFill if d.get("fill") == "oddeven" else Qt.WindingFill)
    except (OSError, ValueError, KeyError, IndexError):
        path = QPainterPath()
        path.addText(0, 0, ui_font(26), "Archiva")
    return path


def paint_background(p, r):
    g = QLinearGradient(r.topLeft(), QPointF(r.left() + r.width(), r.top() + r.width() * 0.40))
    for pos, col in BG_STOPS:
        g.setColorAt(pos, QColor(col))
    p.fillRect(r, g)
    rg = QRadialGradient(QPointF(r.left(), r.top()), max(r.width(), r.height()) * 0.55)
    rg.setColorAt(0.0, rgba(QColor("#603428"), 0.16))
    rg.setColorAt(1.0, rgba(QColor("#603428"), 0.0))
    p.fillRect(r, rg)
    rg2 = QRadialGradient(QPointF(r.right(), r.bottom()), max(r.width(), r.height()) * 0.60)
    rg2.setColorAt(0.0, rgba(QColor("#604832"), 0.12))
    rg2.setColorAt(1.0, rgba(QColor("#604832"), 0.0))
    p.fillRect(r, rg2)


def paint_glass(p, r, radius=12, strength=1.0, hover=False):
    """Placa de 'vidro quente': creme translucido, borda fina e brilho de 1 px no topo."""
    path = QPainterPath()
    path.addRoundedRect(r, radius, radius)
    g = QLinearGradient(r.topLeft(), r.bottomLeft())
    k = 1.35 if hover else 1.0
    g.setColorAt(0.0, QColor(255, 236, 210, int(17 * strength * k)))
    g.setColorAt(1.0, QColor(255, 236, 210, int(8 * strength * k)))
    p.fillPath(path, g)
    p.setPen(QPen(QColor(255, 230, 200, int(22 * strength * (1.3 if hover else 1))), 1))
    p.setBrush(Qt.NoBrush)
    p.drawRoundedRect(r.adjusted(0.5, 0.5, -0.5, -0.5), radius, radius)
    p.setPen(QPen(QColor(255, 240, 220, int(24 * strength)), 1))
    p.drawLine(QPointF(r.left() + radius, r.top() + 1), QPointF(r.right() - radius, r.top() + 1))


def stylesheet():
    t, m, f, l = TEXT.name(), MUTED.name(), FAINT.name(), LINK.name()
    seta = (ASSETS / "ui" / "seta.png").as_posix()
    check = (ASSETS / "ui" / "check.png").as_posix()
    return f"""
* {{ font-family: "{UI_FAMILY}"; font-weight: 600; }}
QWidget {{ color: {t}; }}
QToolTip {{ background: #2a211b; color: {t}; border: 1px solid #4a3a2e; padding: 6px 8px; border-radius: 6px; }}
QDialog {{ background: {DIALOG.name()}; }}
QLabel {{ background: transparent; }}
QLabel[muted="true"] {{ color: {m}; }}
QLabel[heading="true"] {{ color: {HILITE.name()}; font-size: 12px; padding-top: 6px; }}
QLineEdit, QPlainTextEdit, QTextEdit, QSpinBox, QDoubleSpinBox {{
    background: rgba(255,236,210,0.045); border: 1px solid rgba(255,230,200,0.10); border-radius: 9px;
    padding: 4px 11px; min-height: 26px; color: {t}; selection-background-color: #6a4c38; }}
QLineEdit:focus, QPlainTextEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus {{ border-color: rgba(227,207,169,0.55); }}
QPlainTextEdit {{ background: {FIELD.name()}; padding: 8px 10px; font-size: 12px; }}
QComboBox {{ background: rgba(255,236,210,0.05); border: 1px solid rgba(255,230,200,0.10); border-radius: 9px;
    padding: 4px 30px 4px 11px; min-height: 26px; color: {t}; }}
QComboBox:hover {{ border-color: rgba(255,230,200,0.22); }}
QComboBox::drop-down {{ border: none; width: 30px; subcontrol-origin: padding; subcontrol-position: center right; }}
QComboBox::down-arrow {{ image: url({seta}); width: 12px; height: 12px; margin-right: 10px; }}
QComboBox QAbstractItemView {{ background: #221b16; border: 1px solid #3d3027; selection-background-color: #4a3628;
    color: {t}; outline: none; padding: 4px; }}
QPushButton {{ background: rgba(255,236,210,0.06); border: 1px solid rgba(255,230,200,0.12); border-radius: 9px;
    padding: 8px 14px; color: {t}; }}
QPushButton:hover {{ background: rgba(255,236,210,0.11); }}
QPushButton:pressed {{ background: rgba(255,236,210,0.04); }}
QPushButton:disabled {{ color: {f}; }}
QPushButton[primary="true"] {{ background: qlineargradient(x1:0,y1:0,x2:0,y2:1, stop:0 {BTN_TOP.name()}, stop:1 {BTN_BOTTOM.name()});
    color: {BTN_TEXT.name()}; border: none; padding: 11px 18px; font-size: 13px; }}
QPushButton[primary="true"]:hover {{ background: qlineargradient(x1:0,y1:0,x2:0,y2:1, stop:0 #f6eddd, stop:1 #e5d6bd); }}
QPushButton[primary="true"]:pressed {{ background: {BTN_BOTTOM.name()}; }}
QPushButton[flat="true"] {{ background: transparent; border: none; color: {l}; padding: 4px 6px; }}
QPushButton[flat="true"]:hover {{ color: #f1dcb8; }}
QScrollArea {{ background: transparent; border: none; }}
QScrollArea > QWidget > QWidget {{ background: transparent; }}
QSpinBox::up-button, QSpinBox::down-button, QDoubleSpinBox::up-button, QDoubleSpinBox::down-button {{ width: 0; height: 0; border: none; }}
QSpinBox QLineEdit, QDoubleSpinBox QLineEdit {{ background: transparent; border: none; padding: 0; min-height: 0; }}
QScrollBar:horizontal {{ background: transparent; height: 10px; margin: 2px 4px; }}
QScrollBar::handle:horizontal {{ background: rgba(255,230,200,0.14); border-radius: 3px; min-width: 40px; }}
QScrollBar:vertical {{ background: transparent; width: 10px; margin: 4px 2px; }}
QScrollBar::handle:vertical {{ background: rgba(255,230,200,0.14); border-radius: 3px; min-height: 40px; }}
QScrollBar::handle:vertical:hover {{ background: rgba(255,230,200,0.26); }}
QScrollBar::add-line, QScrollBar::sub-line {{ width: 0; height: 0; }}
QScrollBar::add-page, QScrollBar::sub-page {{ background: none; }}
QCheckBox {{ spacing: 8px; }}
QCheckBox::indicator {{ width: 16px; height: 16px; border-radius: 4px;
    border: 1px solid rgba(255,230,200,0.3); background: rgba(255,236,210,0.05); }}
QCheckBox::indicator:checked {{ background: {HILITE.name()}; border-color: {HILITE.name()}; image: url({check}); }}
"""
