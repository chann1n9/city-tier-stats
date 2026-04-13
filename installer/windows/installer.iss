[Setup]
AppName=City Tier Stats
AppVersion=1.0
DefaultDirName={pf}\CityTierStats
DefaultGroupName=CityTierStats
OutputDir=Output
OutputBaseFilename=CityTierStatsSetup

[Files]
Source: "..\..\dist-nuitka\city_tier_stats.dist\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\City Tier Stats"; Filename: "{app}\city-tier-stats.exe"

[Registry]
; ✅ PATH
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Flags: preservestringtype uninsdeletevalue

; ✅ 右键菜单
Root: HKCR; Subkey: "*\shell\CityTierStats"; ValueType: string; ValueData: "Analyze with CityTierStats"; Flags: uninsdeletekey
Root: HKCR; Subkey: "*\shell\CityTierStats\command"; ValueType: string; ValueData: """{app}\city-tier-stats.exe"" ""%1"""
