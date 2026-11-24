"""Interface do Archiva Import (Qt): categorias recolhiveis + janela de configuracoes."""
from .qt import QtCore, QtGui, QtWidgets, Qt, run_dialog
from . import backend, theme
from .config import Config

QW = QtWidgets
QRectF, QPointF = QtCore.QRectF, QtCore.QPointF

_MARKS = (("^c", "ç"), ("^1", "Ç"), ("^a", "ã"), ("^2", "Ã"),
          ("^o", "õ"), ("^e", "é"), ("^i", "í"), ("^u", "ú"))


def tr(s):
    """Troca os marcadores do nucleo MaxScript (^c, ^a...) por letras acentuadas."""
    for a, b in _MARKS:
        s = s.replace(a, b)
    return s


# ------------------------------------------------------------------ pecas visuais
class Wordmark(QW.QWidget):
    """O nome 'Archiva' desenhado a partir do logotipo vetorial do proprio Archiva."""

    def __init__(self, height=30, parent=None):
        super().__init__(parent)
        self._path = theme.logo_path()
        br = self._path.boundingRect()
        self._br = br
        self._s = height / max(br.height(), 1.0)
        self.setFixedSize(int(br.width() * self._s) + 2, height + 2)

    def paintEvent(self, _e):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.Antialiasing)
        p.translate(1, 1)
        p.scale(self._s, self._s)
        p.translate(-self._br.x(), -self._br.y())
        p.fillPath(self._path, theme.LOGO)


class GlassFrame(QW.QFrame):
    def paintEvent(self, _e):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.Antialiasing)
        theme.paint_glass(p, QRectF(self.rect()), 12, 0.7)


class SectionHeader(QW.QAbstractButton):
    """Cabecalho de categoria: placa de vidro, titulo em latao e seta."""

    def __init__(self, text, parent=None):
        super().__init__(parent)
        self.setText(text)
        self.setCheckable(True)
        self.setCursor(Qt.PointingHandCursor)
        self.setFixedHeight(40)
        self._hover = False

    def enterEvent(self, e):
        self._hover = True
        self.update()

    def leaveEvent(self, e):
        self._hover = False
        self.update()

    def sizeHint(self):
        return QtCore.QSize(300, 40)

    def paintEvent(self, _e):
        p = QtGui.QPainter(self)
        p.setRenderHint(QtGui.QPainter.Antialiasing)
        r = QRectF(self.rect())
        theme.paint_glass(p, r, 11, 1.0, self._hover)
        p.setPen(theme.HILITE)
        p.setFont(theme.ui_font(10.5))
        p.drawText(QRectF(16, 0, r.width() - 56, r.height()), Qt.AlignVCenter | Qt.AlignLeft, self.text())
        cx, cy = r.right() - 22, r.center().y()
        p.setPen(QtGui.QPen(theme.MUTED, 2, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin))
        if self.isChecked():
            pts = [QPointF(cx - 5, cy - 2), QPointF(cx, cy + 3), QPointF(cx + 5, cy - 2)]
        else:
            pts = [QPointF(cx - 2, cy - 5), QPointF(cx + 3, cy), QPointF(cx - 2, cy + 5)]
        p.drawPolyline(QtGui.QPolygonF(pts))


class Section(QW.QWidget):
    toggled = QtCore.Signal(bool)

    def __init__(self, title, opened=False, parent=None):
        super().__init__(parent)
        lay = QW.QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(6)
        self.header = SectionHeader(title)
        self.body = GlassFrame()
        self.body_lay = QW.QVBoxLayout(self.body)
        self.body_lay.setContentsMargins(14, 14, 14, 14)
        self.body_lay.setSpacing(10)
        lay.addWidget(self.header)
        lay.addWidget(self.body)
        self.header.toggled.connect(self._on)
        self.header.setChecked(opened)
        self.body.setVisible(opened)

    def _on(self, on):
        self.body.setVisible(on)
        self.toggled.emit(on)


def _muted(text):
    lab = QW.QLabel(text)
    lab.setWordWrap(True)
    lab.setProperty("muted", True)
    return lab


# ------------------------------------------------------------------ janela de configuracoes
class SettingsDialog(QW.QDialog):
    def __init__(self, cfg, parent=None):
        super().__init__(parent)
        self.cfg = cfg
        self._refresh = []
        self.setWindowTitle(tr("Configura^c^oes de importa^c^ao"))
        self.resize(430, 640)

        outer = QW.QVBoxLayout(self)
        outer.setContentsMargins(16, 14, 16, 14)
        outer.setSpacing(10)
        scroll = QW.QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.viewport().setAutoFillBackground(False)
        host = QW.QWidget()
        host.setAutoFillBackground(False)
        scroll.setWidget(host)
        self.col = QW.QVBoxLayout(host)
        self.col.setContentsMargins(0, 0, 8, 0)
        self.col.setSpacing(8)
        outer.addWidget(scroll, 1)

        self._build()
        self.col.addStretch(1)

        row = QW.QHBoxLayout()
        reset = QW.QPushButton(tr("Restaurar padr^oes"))
        close = QW.QPushButton("Fechar")
        reset.clicked.connect(self._reset)
        close.clicked.connect(self.close)
        row.addWidget(reset)
        row.addStretch(1)
        row.addWidget(close)
        outer.addLayout(row)

    # -- construcao
    def _card(self, title, note=None):
        h = QW.QLabel(title.upper())
        h.setProperty("heading", True)
        self.col.addWidget(h)
        card = GlassFrame()
        form = QW.QFormLayout(card)
        form.setContentsMargins(14, 12, 14, 12)
        form.setVerticalSpacing(9)
        form.setFieldGrowthPolicy(QW.QFormLayout.AllNonFixedFieldsGrow)
        if note:
            form.addRow(_muted(note))
        self.col.addWidget(card)
        return form

    def _check(self, form, text, section, key):
        cb = QW.QCheckBox(text)
        cb.toggled.connect(lambda v: self.cfg.set(section, key, bool(v)))
        self._refresh.append(lambda: cb.setChecked(self.cfg.get_bool(section, key)))
        form.addRow(cb)

    def _number(self, form, label, section, key, lo, hi, integer=False):
        """Campo numerico (texto com validacao; aceita ponto ou virgula)."""
        le = QW.QLineEdit()
        le.setAlignment(Qt.AlignRight)

        def show_value():
            v = self.cfg.get_float(section, key)
            le.setText(str(int(round(v))) if integer else (("%.6f" % v).rstrip("0").rstrip(".") or "0"))

        def commit():
            try:
                v = float(le.text().strip().replace(",", "."))
            except ValueError:
                show_value()
                return
            v = min(max(v, lo), hi)
            self.cfg.set(section, key, int(round(v)) if integer else float(v))
            show_value()

        le.editingFinished.connect(commit)
        self._refresh.append(show_value)
        form.addRow(label, le)

    def _double(self, form, label, section, key, lo, hi, decimals=3, step=0.1):
        self._number(form, label, section, key, lo, hi, False)

    def _int(self, form, label, section, key, lo, hi):
        self._number(form, label, section, key, lo, hi, True)

    def _combo(self, form, label, section, key, items):
        cb = QW.QComboBox()
        cb.addItems([tr(i) for i in items])
        cb.currentIndexChanged.connect(lambda i: self.cfg.set(section, key, int(i) + 1))
        self._refresh.append(lambda: cb.setCurrentIndex(max(0, self.cfg.get_int(section, key) - 1)))
        form.addRow(label, cb)

    def _text(self, form, label, section, key):
        le = QW.QLineEdit()
        le.textEdited.connect(lambda t: self.cfg.set(section, key, t))
        self._refresh.append(lambda: le.setText(self.cfg.get(section, key)))
        form.addRow(label, le)

    def _build(self):
        f = self._card("Etapas ativas")
        self._check(f, "Collapse (Editable Poly)", "Steps", "Collapse")
        self._check(f, "Weld", "Steps", "Weld")
        self._check(f, "Attach (all in one mesh)", "Steps", "Attach")
        self._check(f, "Detach by ID", "Steps", "Detach")
        self._check(f, "UVW Map", "Steps", "Uvw")
        self._check(f, "Etapa final (Editable Poly + pivô)", "Steps", "Finish")

        f = self._card("Collapse", "Sem ajustes. Converte tudo para Editable Poly.")

        f = self._card("Weld")
        self._double(f, "Threshold", "Weld", "Threshold", 0.00001, 1000.0, 5, 0.001)

        f = self._card("Attach (all in one mesh)", "Se faltar mem^oria, diminua o n^umero de objetos por parte.".replace("^o", "ó").replace("^u", "ú"))
        self._int(f, "Objetos por parte", "Attach", "ChunkSize", 2, 100000)

        f = self._card("Detach by ID")
        self._combo(f, "Nome das peças", "Detach", "NamingMode",
                    ["Nome do material", "Nome do objeto", "Nome do bitmap", "Numerado"])
        self._text(f, "Prefixo", "Detach", "Prefix")
        self._check(f, "Aplicar o material em cada peça", "Detach", "PropagateMaterials")
        self._check(f, "Cor de wireframe aleat^oria".replace("^o", "ó"), "Detach", "RandomColor")

        f = self._card("UVW Map")
        self._combo(f, "Tipo", "Uvw", "TypeIdx", ["Box", "Planar", "Cylindrical", "Spherical", "Shrink Wrap", "Face"])
        self._double(f, "Length", "Uvw", "Length", 0.001, 1000000.0, 3, 1.0)
        self._double(f, "Width", "Uvw", "Width", 0.001, 1000000.0, 3, 1.0)
        self._double(f, "Height", "Uvw", "Height", 0.001, 1000000.0, 3, 1.0)
        self._int(f, "Canal", "Uvw", "Channel", 1, 99)
        self._check(f, "Real-World Map Size", "Uvw", "RealWorld")

        f = self._card("Etapa final")
        self._check(f, "Converter tudo para Editable Poly", "Finish", "ConvertToPoly")
        self._check(f, "Pivô centralizado na base", "Finish", "Pivot")
        self._combo(f, "Pivô", "Finish", "PivotMode", ["Mesmo ponto para todos (base do conjunto)", "Base de cada objeto"])

        self.load()

    def load(self):
        for fn in self._refresh:
            fn()

    def _reset(self):
        self.cfg.reset_params()
        self.load()

    def paintEvent(self, _e):
        p = QtGui.QPainter(self)
        theme.paint_background(p, QRectF(self.rect()))


# ------------------------------------------------------------------ janela principal
class MainWindow(QW.QWidget):
    def __init__(self, parent=None):
        super().__init__(parent, Qt.Tool)
        self.cfg = Config()
        self._settings = None
        self.setWindowTitle("Archiva Import")
        ico = theme.ASSETS / "brand" / "icone.png"
        if ico.exists():
            self.setWindowIcon(QtGui.QIcon(str(ico)))

        root = QW.QVBoxLayout(self)
        root.setContentsMargins(16, 14, 16, 12)
        root.setSpacing(10)
        root.setSizeConstraint(QW.QLayout.SetFixedSize)

        # cabecalho
        head = QW.QHBoxLayout()
        head.addWidget(Wordmark(28))
        head.addSpacing(8)
        sub = QW.QLabel("Import")
        sub.setProperty("muted", True)
        sub.setFont(theme.ui_font(11))
        head.addWidget(sub, 0, Qt.AlignBottom)
        head.addStretch(1)
        ver = QW.QLabel("v" + backend.version())
        ver.setProperty("muted", True)
        head.addWidget(ver, 0, Qt.AlignBottom)
        root.addLayout(head)
        root.addSpacing(4)

        opened = (self.cfg.get("Ui", "SecOpen") + "000")[:3]
        self.sections = []

        # categoria: importacao
        sec = Section(tr("Importa^c^ao").replace("^c", "ç"), opened[0] == "1")
        self.btn_import = QW.QPushButton(tr("Importar .3DS..."))
        self.btn_import.setProperty("primary", True)
        self.btn_import.setCursor(Qt.PointingHandCursor)
        self.btn_cfg = QW.QPushButton(tr("Configura^c^oes de importa^c^ao..."))
        self.btn_cfg.setCursor(Qt.PointingHandCursor)
        self.log = QW.QPlainTextEdit()
        self.log.setReadOnly(True)
        self.log.setFixedHeight(140)
        self.log.setPlaceholderText(tr("O resumo da importa^c^ao aparece aqui."))
        sec.body_lay.addWidget(self.btn_import)
        sec.body_lay.addWidget(self.btn_cfg)
        sec.body_lay.addWidget(self.log)
        self._add(root, sec)

        # categoria: texturas
        sec = Section("Texturas", opened[1] == "1")
        sec.body_lay.addWidget(_muted("Em breve: trocar os materiais do SketchUp pelos da sua biblioteca, pelo nome."))
        self._add(root, sec)

        # categoria: luzes
        sec = Section("Luzes", opened[2] == "1")
        sec.body_lay.addWidget(_muted("Em breve."))
        self._add(root, sec)

        # rodape
        foot = QW.QHBoxLayout()
        self.btn_update = QW.QPushButton(tr("Verificar atualiza^c^oes"))
        self.btn_update.setProperty("flat", True)
        self.btn_update.setCursor(Qt.PointingHandCursor)
        foot.addWidget(self.btn_update)
        foot.addStretch(1)
        root.addLayout(foot)

        self.btn_import.clicked.connect(self.do_import)
        self.btn_cfg.clicked.connect(self.open_settings)
        self.btn_update.clicked.connect(self.do_update)
        self.setMinimumWidth(360)

    def _add(self, root, sec):
        root.addWidget(sec)
        self.sections.append(sec)
        sec.toggled.connect(self._save_open)

    def _save_open(self, _on):
        self.cfg.set("Ui", "SecOpen", "".join("1" if s.header.isChecked() else "0" for s in self.sections))

    def open_settings(self):
        if self._settings is None or not self._settings.isVisible():
            self._settings = SettingsDialog(self.cfg, self)
            self._settings.setWindowFlag(Qt.Tool, True)
        self._settings.load()
        self._settings.show()
        self._settings.raise_()

    def _say(self, text):
        self.log.setPlainText(text)
        QW.QApplication.processEvents()

    def do_import(self):
        path, _ = QW.QFileDialog.getOpenFileName(self, "Importar arquivo 3DS", "", "3DS (*.3ds);;Todos (*.*)")
        if not path:
            return
        self._say("Importando...")
        QW.QApplication.setOverrideCursor(Qt.WaitCursor)
        try:
            rep = backend.run_import(path)
        except Exception as ex:  # mostra o erro em vez de travar a janela
            rep = "Erro: %s" % ex
        finally:
            QW.QApplication.restoreOverrideCursor()
        self._say(tr(rep))

    def do_update(self):
        self._say("Verificando...")
        try:
            msg, updated = backend.check_update()
        except Exception as ex:
            msg, updated = "Erro: %s" % ex, False
        if updated:
            msg += " Feche e abra o Archiva Import para usar a nova vers^ao."
        self._say(tr(msg))

    def paintEvent(self, _e):
        p = QtGui.QPainter(self)
        theme.paint_background(p, QRectF(self.rect()))


def show(parent=None):
    """Abre (ou reabre) o Archiva Import. Chamado pelo botao do 3ds Max."""
    import __main__
    old = getattr(__main__, "_archiva_win", None)
    if old is not None:
        try:
            old.close()
            old.deleteLater()
        except Exception:
            pass
    app = QW.QApplication.instance() or QW.QApplication([])
    theme.load_fonts()
    win = MainWindow(parent or backend.max_main_window())
    win.setStyleSheet(theme.stylesheet())
    __main__._archiva_win = win
    win.show()
    return win
