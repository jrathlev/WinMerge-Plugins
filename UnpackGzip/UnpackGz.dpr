library UnpackGz;

uses
  System.Win.ComServ,
  UnpackGzMain in 'UnpackGzMain.pas' {WinMergeScript: CoClass},
  GzFileUtils in 'Units\GzFileUtils.pas'
  GzUtils in 'Units\GzUtils.pas';

exports
  DllGetClassObject,
  DllCanUnloadNow,
  DllRegisterServer,
  DllUnregisterServer;

{$R *.TLB}

{$R *.RES}

begin
end.

