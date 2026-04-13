#define ProjectRoot GetEnv("PROJECT_ROOT")
#define OutputDirRoot GetEnv("OUTPUT_DIR")

[Setup]
AppName=City Tier Stats
AppVersion=1.0
DefaultDirName={autopf}\city-tier-stats
OutputDir={#OutputDirRoot}
OutputBaseFilename=city-tier-stats-setup

[Files]
Source: "{#ProjectRoot}\dist-nuitka\city_tier_stats.dist\*"; DestDir: "{app}"; Flags: recursesubdirs

[Registry]
; ✅ PATH
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Flags: preservestringtype uninsdeletevalue

; ✅ 右键菜单
Root: HKCR; Subkey: "*\shell\CityTierStats"; ValueType: string; ValueData: "Analyze with City Tier Stats"; Flags: uninsdeletekey
Root: HKCR; Subkey: "*\shell\CityTierStats\command"; ValueType: string; ValueData: """{app}\city-tier-stats.exe"" ""%1"""
