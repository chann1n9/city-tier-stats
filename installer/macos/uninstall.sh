#!/bin/sh
set -eu

: "${APP_NAME:=city-tier-stats}"
: "${IDENTIFIER:=com.local.city-tier-stats}"

INSTALL_DIR="/usr/local/$APP_NAME"
WRAPPER="/usr/local/bin/$APP_NAME"
QUICK_ACTION_INSTALLER="$INSTALL_DIR/install-quick-action.sh"

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 sudo 运行: sudo $0" >&2
  exit 1
fi

CONSOLE_USER="$(/usr/bin/stat -f %Su /dev/console)"
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
  USER_HOME="$(/usr/bin/dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')"
  if [ -n "$USER_HOME" ] && [ -x "$QUICK_ACTION_INSTALLER" ]; then
    /usr/bin/sudo -u "$CONSOLE_USER" HOME="$USER_HOME" "$QUICK_ACTION_INSTALLER" --uninstall
  fi
fi

rm -rf "$INSTALL_DIR"
rm -f "$WRAPPER"

if pkgutil --pkg-info "$IDENTIFIER" >/dev/null 2>&1; then
  pkgutil --forget "$IDENTIFIER" >/dev/null
fi

echo "已卸载: $INSTALL_DIR"
echo "已删除命令入口: $WRAPPER"
echo "已尝试删除当前用户的 Finder 服务"
echo "已清理安装记录: $IDENTIFIER"
