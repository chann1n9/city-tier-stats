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
Source: "{#ProjectRoot}\installer\windows\cts-wrapper.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Registry]
; ✅ 右键菜单
Root: HKCU; Subkey: "Software\City Tier Stats"; Flags: uninsdeletekeyifempty
Root: HKCR; Subkey: "*\shell\CityTierStats"; ValueType: string; ValueData: "Analyze with City Tier Stats"; Flags: uninsdeletekey
Root: HKCR; Subkey: "*\shell\CityTierStats\command"; ValueType: string; ValueData: """{sys}\WindowsPowerShell\v1.0\powershell.exe"" -NoProfile -ExecutionPolicy Bypass -NoExit -File ""{app}\cts-wrapper.ps1"" ""%1"""; Flags: uninsdeletekey

[Icons]
Name: "{usersendto}\City Tier Stats (Mutiple)"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\cts-wrapper.ps1""";

[Code]
const
  EnvironmentKey = 'Environment';
  AppRegistryKey = 'Software\City Tier Stats';
  UninstallSubkey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\City Tier Stats_is1';
  Wow64UninstallSubkey = 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\City Tier Stats_is1';
  QuietUninstallStringValueName = 'QuietUninstallString';
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

function UninstallFromRegistryKey(RootKey: Integer; Subkey: String): String;
var
  QuietUninstallString: String;
  ResultCode: Integer;
begin
  Result := '';

  if not RegQueryStringValue(RootKey, Subkey, QuietUninstallStringValueName, QuietUninstallString) then
  begin
    Exit;
  end;

  QuietUninstallString := Trim(QuietUninstallString);
  if QuietUninstallString = '' then
  begin
    Exit;
  end;

  Log(Format('Detected previous installation at %d\\%s, running QuietUninstallString: %s',
    [RootKey, Subkey, QuietUninstallString]));

  if not Exec(ExpandConstant('{cmd}'), '/C "' + QuietUninstallString + '"', '',
    SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := Format('Failed to run QuietUninstallString from %s.', [Subkey]);
    Exit;
  end;

  if ResultCode <> 0 then
  begin
    Result := Format('QuietUninstallString from %s exited with code %d.', [Subkey, ResultCode]);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := UninstallFromRegistryKey(HKEY_LOCAL_MACHINE, UninstallSubkey);
  if Result <> '' then
  begin
    Exit;
  end;

  Result := UninstallFromRegistryKey(HKEY_LOCAL_MACHINE, Wow64UninstallSubkey);
  if Result <> '' then
  begin
    Exit;
  end;

  Result := UninstallFromRegistryKey(HKEY_CURRENT_USER, UninstallSubkey);
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
