# Omarchy Arcade Packaging & Distribution

This directory contains the build specifications and metadata for distributing Omarchy Arcade across all major Linux formats:

| Format | Standard Target | Build Manifest |
| :--- | :--- | :--- |
| **Native Arch / Omarchy** | `pacman` / AUR (`makepkg -si`) | [`PKGBUILD`](../PKGBUILD) |
| **Flatpak** | Flathub / Sandboxed desktop | [`flatpak/org.omarchy.Arcade.yml`](flatpak/org.omarchy.Arcade.yml) |
| **AppImage** | Universal portable executable | [`appimage/build_appimage.sh`](appimage/build_appimage.sh) |
| **macOS Bundle & DMG** | Apple Silicon & Intel macOS | [`macos/build_macos_app.sh`](macos/build_macos_app.sh) |
| **Windows 10 / 11** | PowerShell One-Command / Portable | [`windows/install.ps1`](windows/README.md) |

---

## 1. Native Arch / Omarchy Linux (`PKGBUILD`)

Native package integration directly through `pacman`:

```bash
# Build and install locally:
makepkg -si

# Remove anytime cleanly:
sudo pacman -R omarchy-arcade
```

---

## 2. Flatpak (KDE Qt6 Runtime)

Flatpak provides sandboxed isolation while retaining native Wayland and PipeWire performance:

```bash
# Install Flatpak builder if needed:
sudo pacman -S flatpak flatpak-builder

# Install the KDE Qt6 Platform runtime:
flatpak install flathub org.kde.Platform//6.7 org.kde.Sdk//6.7

# Build and install locally into user scope:
cd packaging/flatpak
flatpak-builder --user --install --force-clean build-dir org.omarchy.Arcade.yml

# Run the Flatpak:
flatpak run org.omarchy.Arcade
```

---

## 3. AppImage (Zero-Install Portable Executable)

Generates a standalone `Omarchy_Arcade-x86_64.AppImage` that runs anywhere on Linux with a double-click or CLI call:

```bash
# Run the AppImage build script:
./packaging/appimage/build_appimage.sh

# Run the generated AppImage:
./Omarchy_Arcade-x86_64.AppImage
```

---

## 4. macOS Standalone Application Bundle & DMG

Generates a standalone `Omarchy Arcade.app` and drag-and-drop `Omarchy_Arcade-macOS.dmg` with zero Homebrew or terminal prerequisites:

```bash
# Run the macOS build script:
./packaging/macos/build_macos_app.sh

# The output DMG is saved at:
# Omarchy_Arcade-macOS.dmg
```

For one-command terminal installs on macOS:
```bash
curl -sSL https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/install.sh | bash
```

