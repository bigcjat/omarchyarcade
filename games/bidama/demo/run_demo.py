#!/usr/bin/env python3
import sys
import os
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl, QTimer

def main():
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    qml_file = os.path.join(script_dir, "main_demo.qml")

    engine.load(QUrl.fromLocalFile(qml_file))
    if not engine.rootObjects():
        print("ERROR: Failed to load QML visual demo", file=sys.stderr)
        sys.exit(1)

    root_obj = engine.rootObjects()[0]

    if "--screenshot" in sys.argv:
        out_idx = sys.argv.index("--screenshot") + 1
        out_file = sys.argv[out_idx] if out_idx < len(sys.argv) and not sys.argv[out_idx].startswith("--") else "demo_preview.png"
        out_path = Path(out_file).resolve()
        def do_capture():
            root_obj.captureScreenshot(str(out_path))
            QTimer.singleShot(400, app.quit)
        QTimer.singleShot(500, do_capture)

    print("Visual 3D Marble & Tatami Demo running. Press Ctrl+C or close window to exit.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
