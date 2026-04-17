#define ProjectRoot GetEnv("PROJECT_ROOT")
#define OutputDirRoot GetEnv("OUTPUT_DIR")
#define AppVersionValue GetEnv("APP_VERSION")
#if AppVersionValue == ""
  #define AppVersionValue "0.0.0"
#endif

[Setup]
AppName=City Tier Stats
AppVersion={#AppVersionValue}
DefaultDirName={autopf}\city-tier-stats
OutputDir={#OutputDirRoot}
OutputBaseFilename=city-tier-stats-{#AppVersionValue}-setup

[Files]
Source: "{#ProjectRoot}\dist-nuitka\city_tier_stats.dist\*"; DestDir: "{app}"; Flags: recursesubdirs

[Registry]
; ✅ 右键菜单
Root: HKCU; Subkey: "Software\City Tier Stats"; Flags: uninsdeletekeyifempty
Root: HKCR; Subkey: "*\shell\CityTierStats"; ValueType: string; ValueData: "Analyze with City Tier Stats"; Flags: uninsdeletekey
Root: HKCR; Subkey: "*\shell\CityTierStats\command"; ValueType: string; ValueData: "cmd /v:on /k ""echo. & echo Selected file: %1 & echo. & start """""" """"{app}\city-tier-stats.exe"""" """"%1"""""""; Flags: uninsdeletekey

[Code]
const
  EnvironmentKey = 'Environment';
  AppRegistryKey = 'Software\City Tier Stats';
  PathValueName = 'Path';
  AddedUserPathValueName = 'AddedUserPath';
  CtsHwndBroadcast = $FFFF;
  CtsWmSettingChange = $001A;
  CtsSmtoAbortIfHung = $0002;

function SendMessageTimeout(hWnd: Longint; Msg: Longint; wParam: Longint;
  lParam: String; fuFlags: Longint; uTimeout: Longint;
  var lpdwResult: Longint): Longint;
  external 'SendMessageTimeoutW@user32.dll stdcall';

function NormalizePathEntry(Value: String): String;
begin
  Result := Trim(Value);

  if (Length(Result) >= 2) and (Result[1] = '"') and
    (Result[Length(Result)] = '"') then
  begin
    Result := Copy(Result, 2, Length(Result) - 2);
  end;

  while (Length(Result) > 0) and (Result[Length(Result)] = '\') do
  begin
    Delete(Result, Length(Result), 1);
  end;

  Result := Lowercase(Result);
end;

function PathContainsEntry(Paths: String; Entry: String): Boolean;
var
  Remaining: String;
  Part: String;
  SemiPos: Integer;
  Target: String;
begin
  Result := False;
  Target := NormalizePathEntry(Entry);
  Remaining := Paths;

  while Remaining <> '' do
  begin
    SemiPos := Pos(';', Remaining);
    if SemiPos > 0 then
    begin
      Part := Copy(Remaining, 1, SemiPos - 1);
      Delete(Remaining, 1, SemiPos);
    end
      else
    begin
      Part := Remaining;
      Remaining := '';
    end;

    if NormalizePathEntry(Part) = Target then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function AppendPathEntry(Paths: String; Entry: String): String;
begin
  Result := Trim(Paths);

  while (Length(Result) > 0) and (Result[Length(Result)] = ';') do
  begin
    Delete(Result, Length(Result), 1);
  end;

  if Result = '' then
  begin
    Result := Entry;
  end
    else
  begin
    Result := Result + ';' + Entry;
  end;
end;

function RemovePathEntry(Paths: String; Entry: String): String;
var
  Remaining: String;
  Part: String;
  SemiPos: Integer;
  Target: String;
begin
  Result := '';
  Target := NormalizePathEntry(Entry);
  Remaining := Paths;

  while Remaining <> '' do
  begin
    SemiPos := Pos(';', Remaining);
    if SemiPos > 0 then
    begin
      Part := Copy(Remaining, 1, SemiPos - 1);
      Delete(Remaining, 1, SemiPos);
    end
      else
    begin
      Part := Remaining;
      Remaining := '';
    end;

    Part := Trim(Part);
    if (Part <> '') and (NormalizePathEntry(Part) <> Target) then
    begin
      if Result = '' then
      begin
        Result := Part;
      end
        else
      begin
        Result := Result + ';' + Part;
      end;
    end;
  end;
end;

procedure BroadcastEnvironmentChanged;
var
  ResultCode: Longint;
begin
  SendMessageTimeout(CtsHwndBroadcast, CtsWmSettingChange, 0, 'Environment',
    CtsSmtoAbortIfHung, 5000, ResultCode);
end;

procedure AddInstallDirToUserPath;
var
  Paths: String;
  InstallDir: String;
begin
  InstallDir := ExpandConstant('{app}');
  if not RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey, PathValueName, Paths) then
  begin
    Paths := '';
  end;

  if not PathContainsEntry(Paths, InstallDir) then
  begin
    RegWriteExpandStringValue(HKEY_CURRENT_USER, EnvironmentKey, PathValueName,
      AppendPathEntry(Paths, InstallDir));
    RegWriteStringValue(HKEY_CURRENT_USER, AppRegistryKey, AddedUserPathValueName, '1');
    BroadcastEnvironmentChanged;
  end;
end;

procedure RemoveInstallDirFromUserPath;
var
  Paths: String;
  NewPaths: String;
  InstallDir: String;
  AddedUserPath: String;
begin
  InstallDir := ExpandConstant('{app}');
  if RegQueryStringValue(HKEY_CURRENT_USER, AppRegistryKey, AddedUserPathValueName,
    AddedUserPath) and (AddedUserPath = '1') and
    RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey, PathValueName, Paths) and
    PathContainsEntry(Paths, InstallDir) then
  begin
    NewPaths := RemovePathEntry(Paths, InstallDir);
    if NewPaths <> Paths then
    begin
      RegWriteExpandStringValue(HKEY_CURRENT_USER, EnvironmentKey, PathValueName, NewPaths);
      BroadcastEnvironmentChanged;
    end;
  end;

  RegDeleteValue(HKEY_CURRENT_USER, AppRegistryKey, AddedUserPathValueName);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    AddInstallDirToUserPath;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RemoveInstallDirFromUserPath;
  end;
end;
