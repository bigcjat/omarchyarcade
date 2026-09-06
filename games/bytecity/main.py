#!/usr/bin/env python3
import os
import sys
from pathlib import Path

# Add project root to sys.path so imports work
ROOT_DIR = Path(__file__).resolve().parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType

from games.bytecity.engine import ByteCityEngine
from games.bytecity.viewport import CityViewport

def main():
    # Performance hint for smooth rendering
    os.environ["QSG_RENDER_LOOP"] = "basic"

    app = QGuiApplication(sys.argv)
    app.setApplicationName("ByteCity")
    app.setOrganizationName("Omarchy")

    # Register custom 2.5D isometric viewport
    qmlRegisterType(CityViewport, "ByteCity", 1, 0, "CityViewport")

    # Instantiate native simulation engine
    engine_obj = ByteCityEngine()

    qml_engine = QQmlApplicationEngine()
    qml_path = Path(__file__).parent / "qml" / "main.qml"

    # Context property for QML
    qml_engine.rootContext().setContextProperty("globalEngine", engine_obj)

    qml_engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not qml_engine.rootObjects():
        print("Failed to load QML interface", file=sys.stderr)
        sys.exit(1)

    # Set cityEngine property on root window
    root_window = qml_engine.rootObjects()[0]
    root_window.setProperty("cityEngine", engine_obj)

    def cleanup():
        engine_obj.close()

    app.aboutToQuit.connect(cleanup)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
