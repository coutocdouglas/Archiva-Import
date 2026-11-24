"""Configuracoes salvas em MatizImport.ini (o mesmo arquivo que o nucleo MaxScript le)."""
import configparser
import io
import os

from . import backend

DEFAULTS = {
    ("Steps", "Collapse"): "true",
    ("Steps", "Weld"): "true",
    ("Steps", "Attach"): "true",
    ("Steps", "Detach"): "true",
    ("Steps", "Uvw"): "true",
    ("Steps", "Finish"): "true",
    ("Weld", "Threshold"): "0.001",
    ("Attach", "ChunkSize"): "300",
    ("Detach", "NamingMode"): "1",
    ("Detach", "Prefix"): "",
    ("Detach", "PropagateMaterials"): "true",
    ("Detach", "RandomColor"): "true",
    ("Uvw", "TypeIdx"): "1",
    ("Uvw", "Length"): "100",
    ("Uvw", "Width"): "100",
    ("Uvw", "Height"): "100",
    ("Uvw", "RealWorld"): "true",
    ("Uvw", "Channel"): "1",
    ("Finish", "ConvertToPoly"): "true",
    ("Finish", "Pivot"): "true",
    ("Finish", "PivotMode"): "1",
    ("Options", "Group"): "false",
    ("Options", "GroupName"): "Importado",
    ("Options", "Layer"): "false",
    ("Options", "LayerName"): "Importado",
    ("Options", "Lock"): "false",
    ("Ui", "SecOpen"): "100",
}
_ENC = "cp1252"


def _fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return ("%.6f" % v).rstrip("0").rstrip(".") or "0"
    return str(v)


class Config:
    def __init__(self, path=None):
        self.path = path or backend.cfg_path()
        self._cp = None
        self.reload()

    def reload(self):
        cp = configparser.ConfigParser(interpolation=None)
        cp.optionxform = str
        try:
            with open(self.path, encoding=_ENC, errors="replace") as f:
                cp.read_file(f)
        except (OSError, configparser.Error):
            cp = configparser.ConfigParser(interpolation=None)
            cp.optionxform = str
        self._cp = cp

    def get(self, section, key):
        try:
            v = self._cp.get(section, key)
        except (configparser.Error, KeyError):
            v = None
        if v is None or (v == "" and DEFAULTS.get((section, key)) not in ("", None)):
            return DEFAULTS.get((section, key), "")
        return v

    def get_bool(self, section, key):
        return self.get(section, key).strip().lower() == "true"

    def get_float(self, section, key):
        try:
            return float(self.get(section, key))
        except ValueError:
            return float(DEFAULTS.get((section, key), "0"))

    def get_int(self, section, key):
        return int(round(self.get_float(section, key)))

    def set(self, section, key, value):
        if not self._cp.has_section(section):
            self._cp.add_section(section)
        self._cp.set(section, key, _fmt(value))
        self.save()

    def save(self):
        buf = io.StringIO()
        self._cp.write(buf, space_around_delimiters=False)
        try:
            os.makedirs(os.path.dirname(self.path), exist_ok=True)
            with open(self.path, "w", encoding=_ENC, errors="replace", newline="\r\n") as f:
                f.write(buf.getvalue())
        except OSError:
            pass

    def reset_params(self):
        """Volta os ajustes de cada etapa ao padrao (mantem quais etapas estao ligadas)."""
        for (s, k), v in DEFAULTS.items():
            if s not in ("Steps", "Ui", "Options"):
                self.set(s, k, v)
