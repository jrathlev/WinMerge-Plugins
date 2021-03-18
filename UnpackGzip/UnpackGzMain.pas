(* Winmerge Plugin
   ---------------
   Unpack and pack gz compressed files ( *.gz)

   © Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

   The contents of this file may be used under the terms of the
   Mozilla Public License ("MPL") or
   GNU Lesser General Public License Version 2 or later (the "LGPL")

   Software distributed under this License is distributed on an "AS IS" basis,
   WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
   the specific language governing rights and limitations under the License.

   created: 2011-09-20
   last modified: March 2021
   *)

unit UnpackGzMain;

interface

uses
  Winapi.Windows, System.Win.ComObj;

// *********************************************************************//
// GUIDS declared in the TypeLibrary. Following prefixes are used:      //
//   Type Libraries     : LIBID_xxxx                                    //
//   CoClasses          : CLASS_xxxx                                    //
//   DISPInterfaces     : DIID_xxxx                                     //
//   Non-DISP interfaces: IID_xxxx                                      //
// *********************************************************************//
const
  LIBID_UnpackGzLib: TGUID = '{E1EE0F86-298A-46DD-945D-517AFDD0718C}';
  IID_IWinMergeScript: TGUID = '{92668DE5-8BA0-4C04-97AA-16D360550BBB}';
  CLASS_WinMergeScript: TGUID = '{A0AA7EDF-D2FC-4237-8CBF-CD0EA03C9816}';
type

// *********************************************************************//
// Forward declaration of interfaces defined in Type Library            //
// *********************************************************************//
  IWinMergeScript = interface;
  IWinMergeScriptDisp = dispinterface;

// *********************************************************************//
// Declaration of CoClasses defined in Type Library                     //
// (NOTE: Here we map each CoClass to its Default Interface)            //
// *********************************************************************//
  WinMergeScript = IWinMergeScript;

// *********************************************************************//
// Interface: IWinMergeScript
// Flags:     (4416) Dual OleAutomation Dispatchable
// *********************************************************************//
  IWinMergeScript = interface(IDispatch)
    ['{92668DE5-8BA0-4C04-97AA-16D360550BBB}']
    function Get_PluginEvent: WideString; safecall;
    function Get_PluginDescription: WideString; safecall;
    function Get_PluginFileFilters: WideString; safecall;
    function Get_PluginIsAutomatic: WordBool; safecall;
    function UnpackFile(const fileSrc,fileDst: WideString;
                        var Changed: WordBool; var Subcode: Integer): WordBool; safecall;
    function PackFile(const fileSrc,fileDst: WideString; var Changed: WordBool;
                      SubCode: Integer): WordBool; safecall;
    property PluginEvent: WideString read Get_PluginEvent;
    property PluginDescription: WideString read Get_PluginDescription;
    property PluginFileFilters: WideString read Get_PluginFileFilters;
    property PluginIsAutomatic: WordBool read Get_PluginIsAutomatic;
  end;

// *********************************************************************//
// DispIntf:  IWinMergeScriptDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {DA4E2506-F060-11D7-9350-444553540000}
// *********************************************************************//
  IWinMergeScriptDisp = dispinterface
    ['{A0AA7EDF-D2FC-4237-8CBF-CD0EA03C9816}']
    property PluginEvent: WideString readonly dispid 1;
    property PluginDescription: WideString readonly dispid 2;
    property PluginFileFilters: WideString readonly dispid 3;
    property PluginIsAutomatic: WordBool readonly dispid 4;
    function UnpackFile(const fileSrc,fileDst: WideString;
                        var Changed: WordBool; var Subcode: Integer): WordBool; dispid 7;
    function PackFile(const fileSrc,fileDst: WideString; var Changed: WordBool;
                      SubCode: Integer): WordBool; dispid 8;
  end;

  CoWinMergeScript = class
    class function Create: IWinMergeScript;
    class function CreateRemote(const MachineName: string): IWinMergeScript;
  end;

  TWinMergeScript = class(TAutoObject, IWinMergeScript)
  protected
    function Get_PluginDescription : WideString; safecall;
    function Get_PluginEvent : WideString; safecall;
    function Get_PluginFileFilters : WideString; safecall;
    function Get_PluginIsAutomatic : WordBool; safecall;
    function UnpackFile(const fileSrc,fileDst: WideString;
                        var Changed: WordBool; var Subcode: Integer): WordBool; safecall;
    function PackFile(const fileSrc,fileDst: WideString; var Changed: WordBool;
                      SubCode: Integer): WordBool; safecall;
  end;

implementation

uses
  System.Win.ComServ, System.SysUtils, System.Classes, FileErrors, GzUtils;

var
  RefCnt : integer;
  FilenameList : TStringList;

{ ------------------------------------------------------------------- }
function TWinMergeScript.Get_PluginDescription : WideString;
begin
  result := 'Unpack gz file plugin';
end;

function TWinMergeScript.Get_PluginEvent : WideString;
begin
  result := 'FILE_PACK_UNPACK';
end;

function TWinMergeScript.Get_PluginFileFilters : WideString;
begin
  result := '\.gz$';
end;

function TWinMergeScript.Get_PluginIsAutomatic : WordBool;
begin
  result := true;
end;

{ ------------------------------------------------------------------- }
// unpack to file
function TWinMergeScript.UnpackFile(const fileSrc,fileDst: WideString;
                        var Changed: WordBool; var Subcode: Integer): WordBool; safecall;
var
  GzInfo : TGzFileInfo;
begin
  Changed:=false;
  Subcode:=0;
  if IsGzFile(fileSrc) and GzFileInfoXL(fileSrc,GzInfo) then begin
    FilenameList.Insert(RefCnt,GzInfo.Filename);
    inc(RefCnt);
    with TGUnZipThread.Create(fileSrc,fileDst) do begin
      Overwrite:=true;
      repeat
        Sleep(10);
        until Done;
      Result:=ErrorCode=errOK;
      Free;
      end;
    Changed:=Result;
    Subcode:=RefCnt;
    end
  else Result:=true;
  end;

{ ------------------------------------------------------------------- }
// pack to file
function TWinMergeScript.PackFile(const fileSrc,fileDst: WideString; var Changed: WordBool;
                      SubCode: Integer): WordBool; safecall;
begin
  Changed:=false;
  Result:=false;
  if SubCode>0 then begin
    with TGZipThread.Create(fileSrc,fileDst) do begin
      with FilenameList do if SubCode<=Count then Filename:=Strings[SubCode-1];
      Overwrite:=true;
      repeat
        Sleep(10);
        until Done;
      Result:=ErrorCode=errOK;
      Free;
      end;
    Changed:=Result;
    end
  else Result:=true;
  end;

class function CoWinMergeScript.Create: IWinMergeScript;
begin
  Result := CreateComObject(CLASS_WinMergeScript) as IWinMergeScript;
end;

class function CoWinMergeScript.CreateRemote(const MachineName: string): IWinMergeScript;
begin
  Result := CreateRemoteComObject(MachineName, CLASS_WinMergeScript) as IWinMergeScript;
end;


initialization
  RefCnt:=0;
  FilenameList:=TStringList.Create;
  TAutoObjectFactory.Create(ComServer, TWinMergeScript, Class_WinMergeScript,
    ciMultiInstance, tmApartment);
finalization
  FilenameList.Free;
end.

