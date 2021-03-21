(* Winmerge Plugin
   ---------------
   Ignore leading HTML markers created from IgnoreHtmlTags on comparison

   © Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

   The contents of this file may be used under the terms of the
   Mozilla Public License ("MPL") or
   GNU Lesser General Public License Version 2 or later (the "LGPL")

   Software distributed under this License is distributed on an "AS IS" basis,
   WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
   the specific language governing rights and limitations under the License.

   created: 2011-08-01
   *)

unit IgnoreHtmlMarkerUnit;

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
  LIBID_IgnoreHtmlMarker: TGUID = '{326A4463-B757-4B72-933C-D475FE336397}';
  IID_IWinMergeScript: TGUID = '{5A2BFD42-E1C6-4F67-AD0C-B2AA82594FDA}';
  CLASS_WinMergeScript: TGUID = '{A25C2DAF-39A6-465B-A206-4920344F283F}';
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
    ['{5A2BFD42-E1C6-4F67-AD0C-B2AA82594FDA}']
    function Get_PluginEvent: WideString; safecall;
    function Get_PluginDescription: WideString; safecall;
    function Get_PluginFileFilters: WideString; safecall;
    function Get_PluginIsAutomatic: WordBool; safecall;
    function PrediffBufferW(var Text : WideString; var Size : Integer;
                        var Changed: WordBool): WordBool; safecall;
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
    ['{5A2BFD42-E1C6-4F67-AD0C-B2AA82594FDA}']
    property PluginEvent: WideString readonly dispid 1;
    property PluginDescription: WideString readonly dispid 2;
    property PluginFileFilters: WideString readonly dispid 3;
    property PluginIsAutomatic: WordBool readonly dispid 4;
    function PrediffBufferW(var Text : WideString; var Size : Integer;
                        var Changed: WordBool): WordBool; dispid 5;
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
    function PrediffBufferW(var Text : WideString; var Size : Integer;
                        var Changed: WordBool): WordBool; safecall;
  end;

implementation

uses
  System.Win.ComServ, System.SysUtils, System.Classes, System.StrUtils;

{ ------------------------------------------------------------------- }
function TWinMergeScript.Get_PluginDescription : WideString;
begin
  result := 'Ignore Html Tags marker';
end;

function TWinMergeScript.Get_PluginEvent : WideString;
begin
  result := 'BUFFER_PREDIFF';
end;

function TWinMergeScript.Get_PluginFileFilters : WideString;
begin
  result := '\.html$;\.htm$';
end;

function TWinMergeScript.Get_PluginIsAutomatic : WordBool;
begin
  result := true;
end;

{ ------------------------------------------------------------------- }
// remove leading line numbers
function TWinMergeScript.PrediffBufferW(var Text : WideString; var Size : Integer;
                        var Changed: WordBool): WordBool; safecall;
var
  s,t : string;
  n1,n2 : integer;

  function ReplaceMarker (s : string) : string;
  var
    n1,n2 : integer;
    sp : boolean;
  begin
    n1:=1; Result:='';
    repeat
      n2:=PosEx('|',s,n1);
      if n2>0 then begin
        if ((n2>1) and ((s[n2-1]=#32) or (s[n2-1]='-')))
            or ((n2<length(s)) and ((s[n2+1]=#32) or (s[n2+1]='-'))) then
          Result:=Result+copy(s,n1,n2-n1)
        else Result:=Result+copy(s,n1,n2-n1)+#32;
      n1:=n2+1;
      end;
    until n2=0;
    Result:=Result+copy(s,n1,length(s)-n1+1);
    sp:=false; n1:=1;  // remove multiple spaces
    repeat
      if sp and (Result[n1]=#32) then delete(Result,n1,1)
      else begin
        sp:=Result[n1]=#32; inc(n1);
        end;
      until n1>length(Result);
    if (length(Result)>0) then begin //remove leading and trailing space
      if (Result[1]=#32) then delete(Result,1,1);
      n1:=length(Result);
      if (Result[n1]=#32) then delete(Result,n1,1);
      end;
    end;

begin
  if Size>0 then begin
    t:=Text; s:=''; n1:=1;
    repeat
      n2:=PosEx(#13,t,n1);
      if n2>0 then begin
        if t[n1]='#' then n1:=PosEx(':',t,n1)+1;
        s:=s+ReplaceMarker(copy(t,n1,n2-n1+1));  // ignore linebreak markers
//        s:=s+copy(t,n1,n2-n1+1);
        if (n2<length(t)) then begin
          n1:=n2+1;
          if (t[n1]=#10) then inc(n1);
          end
        else n2:=0;
        end;
      until n2=0;
    Size:=length(s);
    Text:=s;
    Changed:=true;
    end
  else Changed:=false;
  Result:=true;
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
  TAutoObjectFactory.Create(ComServer, TWinMergeScript, Class_WinMergeScript,
    ciMultiInstance, tmApartment);
end.

