# Maintainer: Chris Thompson
pkgname=omarchy-arcade
pkgver=1.0.0
pkgrel=1
pkgdesc="Curated native desktop retro arcade suite and launcher for Omarchy Linux"
arch=('any')
url="https://github.com/bigcjat/omarchyarcade"
license=('custom')
depends=('python' 'python-pyside6' 'qt6-declarative' 'qt6-svg' 'qt6-multimedia')
makedepends=()
source=("$pkgname-$pkgver.tar.gz::https://github.com/bigcjat/omarchyarcade/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    local src="$srcdir/omarchyarcade-$pkgver"
    if [ ! -d "$src" ]; then
        src="$srcdir"
    fi
    local dest="$pkgdir/usr/share/omarchy-arcade"

    install -dm755 "$dest"
    cp -r "$src/assets" "$src/catalog.json" "$src/launcher" "$dest/"

    # System binary /usr/bin/arcade
    install -dm755 "$pkgdir/usr/bin"
    cat << 'EOF' > "$pkgdir/usr/bin/arcade"
#!/usr/bin/env bash
exec python3 /usr/share/omarchy-arcade/launcher/main.py "$@"
EOF
    chmod 755 "$pkgdir/usr/bin/arcade"

    # Desktop Application Entry
    install -Dm644 "$src/assets/omarchy-arcade.desktop" "$pkgdir/usr/share/applications/omarchy-arcade.desktop"

    # Application Icon
    install -Dm644 "$src/assets/omarchy_arcade_logo.svg" "$pkgdir/usr/share/icons/hicolor/scalable/apps/omarchy-arcade.svg"

    # Hyprland Window Rule & Keybind Drop-in
    install -dm755 "$pkgdir/usr/share/hypr/rules"
    cat << 'EOF' > "$pkgdir/usr/share/hypr/rules/omarchy-arcade.conf"
windowrulev2 = float, title:^(Omarchy Arcade)$
windowrulev2 = size 1080 740, title:^(Omarchy Arcade)$
windowrulev2 = center, title:^(Omarchy Arcade)$
bind = $mainMod, G, exec, arcade
EOF
}
