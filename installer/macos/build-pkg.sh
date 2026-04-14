#!/bin/sh
set -eu

: "${APP_NAME:=city-tier-stats}"
: "${VERSION:=0.1.0}"
: "${IDENTIFIER:=com.local.city-tier-stats}"

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
: "${DIST_DIR:=$ROOT_DIR/dist-nuitka/city_tier_stats.dist}"
: "${BUILD_DIR:=$ROOT_DIR/build/macos-pkg}"
PKG_ROOT="$BUILD_DIR/root"
SCRIPTS_DIR="$BUILD_DIR/scripts"
PKG_OUTPUT="$BUILD_DIR/${APP_NAME}-${VERSION}.pkg"

if [ ! -d "$DIST_DIR" ]; then
  echo "找不到 Nuitka 目录版产物: $DIST_DIR" >&2
  exit 1
fi

rm -rf "$PKG_ROOT"
rm -rf "$SCRIPTS_DIR"
rm -f "$PKG_OUTPUT"

mkdir -p "$PKG_ROOT/usr/local/$APP_NAME"
mkdir -p "$PKG_ROOT/usr/local/bin"
mkdir -p "$SCRIPTS_DIR"

COPYFILE_DISABLE=1 ditto "$DIST_DIR" "$PKG_ROOT/usr/local/$APP_NAME"
find "$PKG_ROOT" -name "._*" -type f -delete
xattr -rc "$PKG_ROOT" 2>/dev/null || true

install -m 755 "$ROOT_DIR/installer/macos/install-quick-action.sh" "$PKG_ROOT/usr/local/$APP_NAME/install-quick-action.sh"
install -m 755 "$ROOT_DIR/installer/macos/uninstall.sh" "$PKG_ROOT/usr/local/$APP_NAME/uninstall.sh"

cat > "$PKG_ROOT/usr/local/bin/$APP_NAME" <<'WRAPPER'
#!/bin/sh
exec /usr/local/city-tier-stats/city-tier-stats "$@"
WRAPPER

chmod +x "$PKG_ROOT/usr/local/bin/$APP_NAME"
chmod +x "$PKG_ROOT/usr/local/$APP_NAME/city-tier-stats"

cat > "$SCRIPTS_DIR/postinstall" <<'POSTINSTALL'
#!/bin/sh
set -eu

APP_NAME="city-tier-stats"
TOOL="/usr/local/bin/$APP_NAME"
QUICK_ACTION_INSTALLER="/usr/local/$APP_NAME/install-quick-action.sh"

CONSOLE_USER="$(/usr/bin/stat -f %Su /dev/console)"
if [ -z "$CONSOLE_USER" ] || [ "$CONSOLE_USER" = "root" ]; then
  echo "No console user found; skipping Finder service install."
  exit 0
fi

USER_HOME="$(/usr/bin/dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')"
if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
  echo "Home directory not found for $CONSOLE_USER; skipping Finder service install."
  exit 0
fi

if [ ! -x "$QUICK_ACTION_INSTALLER" ]; then
  echo "Quick Action installer not found: $QUICK_ACTION_INSTALLER; skipping Finder service install."
  exit 0
fi

/usr/bin/sudo -u "$CONSOLE_USER" HOME="$USER_HOME" "$QUICK_ACTION_INSTALLER" "$TOOL" || true
POSTINSTALL
chmod +x "$SCRIPTS_DIR/postinstall"

pkgbuild \
  --root "$PKG_ROOT" \
  --scripts "$SCRIPTS_DIR" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location / \
  "$PKG_OUTPUT"

echo "pkg 已生成: $PKG_OUTPUT"
echo "安装后程序目录: /usr/local/$APP_NAME"
echo "安装后命令入口: /usr/local/bin/$APP_NAME"
