#!/usr/bin/env python3
import sys
from pathlib import Path
from PySide6.QtCore import QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

# We will run the game, force speed to 9.0, spawn a pterodactyl, trigger night mode, and screenshot!
from games.runner.main import SoundManager, SettingsManager, load_all_omarchy_themes, generate_themed_sprites

app = QGuiApplication(sys.argv)
base_dir = Path("games/runner").resolve()
assets_dir = base_dir / "assets"
sounds_dir = base_dir / "sounds"

sound_manager = SoundManager(sounds_dir)
settings_manager = SettingsManager()

engine = QQmlApplicationEngine()
engine.rootContext().setContextProperty("soundManager", sound_manager)
engine.rootContext().setContextProperty("audioController", sound_manager)
engine.rootContext().setContextProperty("settingsManager", settings_manager)

qml_file = base_dir / "main.qml"
engine.load(str(qml_file))

root = engine.rootObjects()[0]
all_themes = load_all_omarchy_themes()
active_theme = all_themes.get("catppuccin") or {
    "bg": "#1e1e2e", "fg": "#cdd6f4", "accent": "#89b4fa",
    "boardBg": "#181825", "cardBg": "#313244", "border": "#45475a",
    "subtext": "#a6adc8", "red": "#f38ba8", "peach": "#fab387", "yellow": "#f9e2af"
}
generate_themed_sprites(active_theme, assets_dir)
root.applyTheme(active_theme, "Catppuccin")
root.splashEnabled = False
root.startNewGame()

shot_path = "/Users/christhompson/.gemini/antigravity-ide/brain/ccb4e9bb-b02b-4f28-9fb5-a62ea177113b/cyberdash_features_proof.png"

def trigger_and_shot():
    # In QML, let's call Engine to force a pterodactyl and nightMode
    engine_cmd = """
    (function() {
        Engine.nightMode.active = true;
        Engine.nightMode.opacity = 1.0;
        Engine.nightMode.timer = 3000;
        Engine.nightMode.moonPhase = 2;
        Engine.nightMode.moonX = 520;
        Engine.nightMode.moonY = 30;
        Engine.nightMode.stars = [
            { x: 480, y: 25 },
            { x: 340, y: 45 },
            { x: 200, y: 35 },
            { x: 120, y: 55 }
        ];
        // Add a pterodactyl flying towards dino
        Engine.obstacles = [];
        Engine.addObstacle(9.5); // at speed 9.5, pterodactyl is available!
        // Ensure first obstacle is pterodactyl
        for (var i = 0; i < Engine.obstacles.length; i++) {
            Engine.obstacles[i].type = "PTERODACTYL";
            Engine.obstacles[i].typeConfig = Engine.OBSTACLE_TYPES[2];
            Engine.obstacles[i].xPos = 240;
            Engine.obstacles[i].yPos = Engine.groundYPos - 18;
            Engine.obstacles[i].width = 46;
            Engine.obstacles[i].height = 40;
        }
    })()
    """
    root.evaluateJavaScript = False # Just check if we can run code via QTimer in QML
    print("Triggered setup")

QTimer.singleShot(600, lambda: app.quit())
app.exec()
