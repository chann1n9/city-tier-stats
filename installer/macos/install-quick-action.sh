#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-Analyze with City Tier Stats}"
BUNDLE_ID="com.city-tier-stats.finder-quick-action"
SUPPORT_DIR="${HOME}/Library/Application Support/City Tier Stats"
BACKUP_ROOT="${SUPPORT_DIR}/Workflow Backups"
LOG_FILE="${HOME}/Library/Logs/City Tier Stats Quick Action.log"
SERVICES_DIR="${HOME}/Library/Services"
WORKFLOW_DIR="${SERVICES_DIR}/${SERVICE_NAME}.workflow"
CONTENTS_DIR="${WORKFLOW_DIR}/Contents"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
REPLACE_EXISTING=0
UNINSTALL=0
TOOL_PATH="/usr/local/bin/city-tier-stats"

usage() {
  cat <<USAGE
Usage:
  $0 [--replace-existing] [/path/to/city-tier-stats]
  $0 --uninstall

Installs a Finder Quick Action named "${SERVICE_NAME}" for the current user.

Examples:
  $0 /Applications/city-tier-stats/city-tier-stats
  SERVICE_NAME="Analyze with City Tier Stats" $0 /usr/local/bin/city-tier-stats
USAGE
}

validate_service_name() {
  if [[ -z "${SERVICE_NAME}" || "${SERVICE_NAME}" == *"/"* ]]; then
    echo "Error: SERVICE_NAME must be a non-empty name without slashes." >&2
    exit 1
  fi
}

workflow_bundle_id() {
  local workflow_dir="$1"
  /usr/bin/plutil -extract CFBundleIdentifier raw \
    "${workflow_dir}/Contents/Info.plist" 2>/dev/null || true
}

workflow_is_ours() {
  [[ "$(workflow_bundle_id "$1")" == "${BUNDLE_ID}" ]]
}

relocate_legacy_service_backups() {
  local backup_dir

  for backup_dir in "${WORKFLOW_DIR}.backup."*; do
    if [[ -e "${backup_dir}" ]]; then
      mkdir -p "${BACKUP_ROOT}"
      /bin/mv "${backup_dir}" "${BACKUP_ROOT}/$(/usr/bin/basename "${backup_dir}")"
      echo "Moved old backup out of Services: ${BACKUP_ROOT}/$(/usr/bin/basename "${backup_dir}")"
    fi
  done
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --replace-existing)
      REPLACE_EXISTING=1
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      TOOL_PATH="$1"
      shift
      ;;
  esac
done

if [[ "$#" -gt 0 ]]; then
  echo "Error: too many arguments." >&2
  usage >&2
  exit 1
fi

validate_service_name
relocate_legacy_service_backups

if [[ "${UNINSTALL}" -eq 1 ]]; then
  if [[ -e "${WORKFLOW_DIR}" ]]; then
    if ! workflow_is_ours "${WORKFLOW_DIR}"; then
      echo "Error: refusing to remove an existing Quick Action not created by this installer:" >&2
      echo "  ${WORKFLOW_DIR}" >&2
      echo "Remove it manually from Automator or Finder if you created it yourself." >&2
      exit 1
    fi

    rm -rf "${WORKFLOW_DIR}"
  fi

  rm -f "${SUPPORT_DIR}/finder-quick-action.sh" "${SUPPORT_DIR}/tool-path"
  rmdir "${SUPPORT_DIR}" 2>/dev/null || true
  /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
  echo "Removed Finder Quick Action: ${SERVICE_NAME}"
  exit 0
fi

if [[ ! -x "${TOOL_PATH}" ]]; then
  echo "Error: executable not found or not executable: ${TOOL_PATH}" >&2
  echo "Pass the installed city-tier-stats executable path as the first argument." >&2
  exit 1
fi

if [[ -e "${WORKFLOW_DIR}" ]]; then
  if ! workflow_is_ours "${WORKFLOW_DIR}"; then
    if [[ "${REPLACE_EXISTING}" -ne 1 ]]; then
      echo "Error: refusing to overwrite an existing Quick Action not created by this installer:" >&2
      echo "  ${WORKFLOW_DIR}" >&2
      echo "Run again with --replace-existing to move it aside and install this Quick Action." >&2
      exit 1
    fi

    mkdir -p "${BACKUP_ROOT}"
    BACKUP_DIR="${BACKUP_ROOT}/$(/usr/bin/basename "${WORKFLOW_DIR}").backup.$(/bin/date +%Y%m%d%H%M%S)"
    /bin/mv "${WORKFLOW_DIR}" "${BACKUP_DIR}"
    echo "Moved existing Quick Action to: ${BACKUP_DIR}"
  else
    rm -rf "${WORKFLOW_DIR}"
  fi
fi

mkdir -p "${CONTENTS_DIR}" "${RESOURCES_DIR}" "${SUPPORT_DIR}"
printf '%s\n' "${TOOL_PATH}" > "${SUPPORT_DIR}/tool-path"

cat > "${SUPPORT_DIR}/finder-quick-action.sh" <<'HELPER'
#!/usr/bin/env bash
set -u

SUPPORT_DIR="${HOME}/Library/Application Support/City Tier Stats"
LOG_FILE="${HOME}/Library/Logs/City Tier Stats Quick Action.log"
TOOL_PATH="$(/bin/cat "${SUPPORT_DIR}/tool-path" 2>/dev/null || true)"

log_event() {
  {
    /bin/date '+%Y-%m-%d %H:%M:%S %z'
    printf 'helper=%s\n' "$0"
    printf 'argc=%s\n' "$#"
    printf 'args:\n'
    for arg in "$@"; do
      printf '  %s\n' "${arg}"
    done
    printf 'tool_path=%s\n' "${TOOL_PATH}"
    printf '\n'
  } >> "${LOG_FILE}" 2>&1
}

log_event "$@"

show_error() {
  /usr/bin/osascript -e 'display alert "City Tier Stats" message "'"$1"'" as critical'
}

if [[ -z "${TOOL_PATH}" || ! -x "${TOOL_PATH}" ]]; then
  show_error "city-tier-stats executable was not found. Reinstall the Quick Action with the correct executable path."
  exit 1
fi

if [[ "$#" -eq 0 ]]; then
  show_error "No Finder item was passed to the Quick Action."
  exit 1
fi

RUN_SCRIPT="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/city-tier-stats-quick-action.XXXXXX")"
/bin/chmod 700 "${RUN_SCRIPT}"

/bin/cat > "${RUN_SCRIPT}" <<RUNNER
#!/usr/bin/env bash
set -u

tool_path=$(printf '%q' "${TOOL_PATH}")
input_files=(
RUNNER

/usr/bin/touch "${RUN_SCRIPT}"
for input_file in "$@"; do
  printf '  %q\n' "${input_file}" >> "${RUN_SCRIPT}"
done

/bin/cat >> "${RUN_SCRIPT}" <<'RUNNER'
)

for input_file in "${input_files[@]}"; do
  input_dir="$(/usr/bin/dirname "${input_file}")"
  cd "${input_dir}" || exit 1

  printf 'Analyzing: %s\n\n' "${input_file}"
  "${tool_path}" "${input_file}"
  status=$?
  printf '\nExit code: %s\n' "${status}"

  if [[ "$#" -gt 1 ]]; then
    printf '\n---\n\n'
  fi
done

printf '\nPress any key to close...'
IFS= read -r -s -n 1 _
/bin/rm -f "$0"
RUNNER

/usr/bin/osascript <<APPLESCRIPT
tell application "Terminal"
  activate
  do script "/bin/bash " & quoted form of POSIX path of "${RUN_SCRIPT}"
end tell
APPLESCRIPT
HELPER
chmod 755 "${SUPPORT_DIR}/finder-quick-action.sh"

cat > "${CONTENTS_DIR}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.city-tier-stats.finder-quick-action</string>
  <key>CFBundleName</key>
  <string>Analyze with City Tier Stats</string>
  <key>CFBundlePackageType</key>
  <string>BNDL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>Analyze with City Tier Stats</string>
      </dict>
      <key>NSMessage</key>
      <string>runWorkflowAsService</string>
      <key>NSRequiredContext</key>
      <dict>
        <key>NSApplicationIdentifier</key>
        <string>com.apple.finder</string>
      </dict>
      <key>NSSendFileTypes</key>
      <array>
        <string>public.data</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

cat > "${RESOURCES_DIR}/document.wflow" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>AMApplicationBuild</key>
  <string>521</string>
  <key>AMApplicationVersion</key>
  <string>2.10</string>
  <key>AMDocumentVersion</key>
  <string>2</string>
  <key>actions</key>
  <array>
    <dict>
      <key>action</key>
      <dict>
        <key>AMActionVersion</key>
        <string>2.0.3</string>
        <key>AMApplication</key>
        <array>
          <string>Automator</string>
        </array>
        <key>AMParameterProperties</key>
        <dict>
          <key>COMMAND_STRING</key>
          <dict/>
          <key>CheckedForUserDefaultShell</key>
          <dict/>
          <key>inputMethod</key>
          <dict/>
          <key>shell</key>
          <dict/>
          <key>source</key>
          <dict/>
        </dict>
        <key>ActionBundlePath</key>
        <string>/System/Library/Automator/Run Shell Script.action</string>
        <key>ActionName</key>
        <string>Run Shell Script</string>
        <key>ActionParameters</key>
        <dict>
          <key>COMMAND_STRING</key>
          <string>{
  date '+%Y-%m-%d %H:%M:%S %z'
  printf 'automator-entry=%s\n' "$0"
  printf 'argc=%s\n' "$#"
  printf 'args:\n'
  for arg in "$@"; do
    printf '  %s\n' "$arg"
  done
  printf '\n'
} &gt;&gt; "$HOME/Library/Logs/City Tier Stats Quick Action.log" 2&gt;&amp;1
"$HOME/Library/Application Support/City Tier Stats/finder-quick-action.sh" "$@"</string>
          <key>CheckedForUserDefaultShell</key>
          <true/>
          <key>inputMethod</key>
          <integer>1</integer>
          <key>shell</key>
          <string>/bin/bash</string>
          <key>source</key>
          <string></string>
        </dict>
        <key>AMAccepts</key>
        <dict>
          <key>Container</key>
          <string>List</string>
          <key>Optional</key>
          <false/>
          <key>Types</key>
          <array>
            <string>com.apple.cocoa.path</string>
          </array>
        </dict>
        <key>BundleIdentifier</key>
        <string>com.apple.RunShellScript</string>
        <key>AMProvides</key>
        <dict>
          <key>Container</key>
          <string>List</string>
          <key>Types</key>
          <array>
            <string>com.apple.cocoa.string</string>
          </array>
        </dict>
        <key>arguments</key>
        <dict>
          <key>0</key>
          <dict>
            <key>default value</key>
            <integer>1</integer>
            <key>name</key>
            <string>inputMethod</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>0</string>
          </dict>
          <key>1</key>
          <dict>
            <key>default value</key>
            <string></string>
            <key>name</key>
            <string>source</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>1</string>
          </dict>
          <key>2</key>
          <dict>
            <key>default value</key>
            <integer>1</integer>
            <key>name</key>
            <string>CheckedForUserDefaultShell</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>2</string>
          </dict>
          <key>3</key>
          <dict>
            <key>default value</key>
            <string></string>
            <key>name</key>
            <string>COMMAND_STRING</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>3</string>
          </dict>
          <key>4</key>
          <dict>
            <key>default value</key>
            <string>/bin/sh</string>
            <key>name</key>
            <string>shell</string>
            <key>required</key>
            <string>0</string>
            <key>type</key>
            <string>0</string>
            <key>uuid</key>
            <string>4</string>
          </dict>
        </dict>
        <key>CFBundleVersion</key>
        <string>2.0.3</string>
        <key>CanShowSelectedItemsWhenRun</key>
        <false/>
        <key>CanShowWhenRun</key>
        <true/>
        <key>Category</key>
        <array>
          <string>AMCategoryUtilities</string>
        </array>
        <key>Class Name</key>
        <string>RunShellScriptAction</string>
        <key>InputUUID</key>
        <string>3A8A315B-3E10-49B8-9A7E-A87756E61C12</string>
        <key>Keywords</key>
        <array>
          <string>Shell</string>
          <string>Script</string>
          <string>Command</string>
          <string>Run</string>
          <string>Unix</string>
        </array>
        <key>OutputUUID</key>
        <string>9D584327-6FDD-4C21-85CB-B54B97163E1B</string>
        <key>UUID</key>
        <string>A4727836-DF40-43F6-A9F4-D8225E1EC62C</string>
      </dict>
      <key>isViewVisible</key>
      <true/>
    </dict>
  </array>
  <key>connectors</key>
  <dict/>
  <key>workflowMetaData</key>
  <dict>
    <key>applicationBundleIDsByPath</key>
    <dict/>
    <key>applicationPaths</key>
    <array/>
    <key>inputTypeIdentifier</key>
    <string>com.apple.Automator.fileSystemObject</string>
    <key>outputTypeIdentifier</key>
    <string>com.apple.Automator.nothing</string>
    <key>presentationMode</key>
    <integer>15</integer>
    <key>processesInput</key>
    <integer>0</integer>
    <key>serviceApplicationBundleID</key>
    <string>com.apple.finder</string>
    <key>serviceApplicationPath</key>
    <string>/System/Library/CoreServices/Finder.app</string>
    <key>serviceInputTypeIdentifier</key>
    <string>com.apple.Automator.fileSystemObject</string>
    <key>serviceOutputTypeIdentifier</key>
    <string>com.apple.Automator.nothing</string>
    <key>serviceProcessesInput</key>
    <integer>0</integer>
    <key>workflowTypeIdentifier</key>
    <string>com.apple.Automator.servicesMenu</string>
  </dict>
</dict>
</plist>
PLIST

/bin/cp "${RESOURCES_DIR}/document.wflow" "${CONTENTS_DIR}/document.wflow"
/usr/bin/plutil -lint "${CONTENTS_DIR}/Info.plist" "${RESOURCES_DIR}/document.wflow" "${CONTENTS_DIR}/document.wflow" >/dev/null
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true

echo "Installed Finder Quick Action: ${SERVICE_NAME}"
echo "Executable: ${TOOL_PATH}"
echo "Location: ${WORKFLOW_DIR}"
echo "Use it from Finder: right-click a .xlsx or .csv file -> Quick Actions -> ${SERVICE_NAME}"
