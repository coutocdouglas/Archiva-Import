"""Compatibilidade Qt: 3ds Max 2024 usa PySide2; Max 2025 em diante usa PySide6."""
try:
    from PySide6 import QtCore, QtGui, QtWidgets  # noqa: F401
    QT6 = True
except ImportError:  # 3ds Max 2024
    from PySide2 import QtCore, QtGui, QtWidgets  # noqa: F401
    QT6 = False

Qt = QtCore.Qt


def run_dialog(dlg):
    """exec() no Qt6, exec_() no Qt5."""
    fn = getattr(dlg, "exec", None) or dlg.exec_
    return fn()
