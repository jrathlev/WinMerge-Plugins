(* Winmerge Plugin
   ---------------
   Unpack: Remove HTML tags from file to compare pure text with WinMerge
     and keep the original HTML fiel as template with placeholders
   Pack: Replace the placeholders in the template with merged text

   Requires PreDiffer plugin "IgnoreHtmlMarker"

   © Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

   The contents of this file may be used under the terms of the
   Mozilla Public License ("MPL") or
   GNU Lesser General Public License Version 2 or later (the "LGPL")

   Software distributed under this License is distributed on an "AS IS" basis,
   WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
   the specific language governing rights and limitations under the License.

   created: 2011-08-01
   *)

unit IgnoreHtmlTagsUnit;

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
  LIBID_IgnoreHtmlTags: TGUID = '{5E7787FD-4A98-4113-B48E-04D7C8D6C035}';
  IID_IWinMergeScript: TGUID = '{7D1D732C-423A-4FFE-AA6B-60222691FA9E}';
  CLASS_WinMergeScript: TGUID = '{0D7B39BF-2540-422F-9BB2-A8DFBA7C15EE}';
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
    ['{7D1D732C-423A-4FFE-AA6B-60222691FA9E}']
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
    ['{7D1D732C-423A-4FFE-AA6B-60222691FA9E}']
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

type
  TStringValue = class(TObject)
    FString : string;
    constructor Create (const AString : string);
    end;

implementation

uses
  System.Win.ComServ, System.SysUtils, System.Classes, System.StrUtils;

const
  TempExt = '.htmp';

var
  RefCnt : integer;
  FilenameList : TStringList;

{ ------------------------------------------------------------------- }
constructor TStringValue.Create (const AString : string);
begin
  inherited Create;
  FString:=AString;
  end;

{ ------------------------------------------------------------------- }
function ReadNxtStr (var s   : String;
                     Del     : char) : string;
var
  i : integer;
begin
  if length(s)>0 then begin
    i:=pos (Del,s);
    if i=0 then i:=succ(length(s));
    ReadNxtStr:=copy(s,1,pred(i));
    delete(s,1,i);
    end
  else ReadNxtStr:='';
  end;

function WriteTextFile (const FName,AText : string; AEncoding : TEncoding) : boolean;
var
  sl : TStringList;
begin
  Result:=false;
  sl:= TStringList.Create;
  with sl do begin
    try
      Text:=AText;
      SaveToFile(FName,AEncoding);
      Result:=true;
    finally
      Free;
      end;
    end;
  end;

{ ------------------------------------------------------------------- }
function TWinMergeScript.Get_PluginDescription : WideString;
begin
  result := 'Ignore Html Tags plugin';
end;

function TWinMergeScript.Get_PluginEvent : WideString;
begin
  result := 'FILE_PACK_UNPACK';
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
// unpack to file
function TWinMergeScript.UnpackFile(const fileSrc,fileDst: WideString;
                        var Changed: WordBool; var Subcode: Integer): WordBool; safecall;
var
  slist          : TStringList;
  sp             : boolean;
  s,tt,ht        : string;
  cp             : cardinal;
  TagStart,TagNr,
  TextStart,
  i,n            : integer;

  (* Integer-Zahl in String mit führenden Nullen umsetzen *)
  function ZStrInt (x : int64;
                    n : integer) : string;
  var
    i : integer;
  begin
    Result:=IntToStr(abs(x));
    for i:=succ(length(Result)) to n do Result:='0'+Result;
    if x<0 then Result:='-'+Result
    else Result:='0'+Result;
    end;

  function TrimCtrl(const S: string): string;
  var
    I, L: Integer;
  begin
    L := Length(S);
    I := 1;
    while (I <= L) and (S[I] < #32) do Inc(I);
    if I > L then Result := '' else begin
      while S[L] < #32 do Dec(L);
      Result := Copy(S, I, L - I + 1);
      end;
   end;

  function RemCtrl (const s : string) : string;
  var
    i : integer;
    sp : boolean;
  begin
    Result:='';
    for i:=1 to length(s) do if s[i]<#32 then begin
      if s[i]=#13 then Result:=Result+'|'; //#32;
      end
    else Result:=Result+s[i];
    sp:=false; i:=1;  // Mehrfachzwischenräume entfernen
    repeat
      if sp and (Result[i]=#32) then delete(Result,i,1)
      else begin
        sp:=Result[i]=#32; inc(i);
        end;
      until i>length(Result);
    Result:=Trim(Result);
    end;

begin
//  MessageDlg(filesrc+' / '+filedst,mtInformation,[mbOK],0);
  Changed:=false; SubCode:=0; Result:=false; s:='';
  slist:=TStringList.Create;
  try
    with slist do begin
      LoadFromFile(filesrc);
      cp:=Encoding.CodePage;
      s:=Text;
      end;
  finally
    slist.Free;
    end;
  if length(s)>0 then begin
    s:=AnsiReplaceText(s,#13#10,#13);
    s:=AnsiReplaceText(s,#10,#13);
    s:=AnsiReplaceStr(s,#9,#32);
    i:=1; tt:=''; ht:=''; TagNr:=0; TagStart:=1; TextStart:=1;
    repeat
      if (s[i]='<') then begin
        TagStart:=i;
        n:=i-TextStart;
        if (n>1) or ((n=1) and (s[i]<>#13)) then begin
          tt:=tt+RemCtrl(copy(s,TextStart,n))+#13;      // remove leading and trailing CRs
          end;
        inc(i);
        end
      else if (s[i]='>') and (TagStart<i) then begin
        TextStart:=i+1;
        ht:=ht+copy(s,TagStart,i-TagStart+1);
        inc(i); n:=i;
        while (n<=length(s)) and ((s[n]=#13) or (s[n]=#32)) do inc(n);  // next no CR char
        if (n<=length(s)) then begin
          if (s[n]='<') then begin   // no text before next tag
            ht:=ht+copy(s,i,n-i);
            TextStart:=n;
            i:=n;
            end
          else begin      // has text
            inc(TagNr); TextStart:=i;
            ht:=ht+'#'+ZStrint(TagNr,5);
            tt:=tt+'#'+ZStrint(TagNr,5)+':';
            end;
          end
        else begin
          ht:=ht+copy(s,i,n-i-1); i:=n;  // end of text
          end;
        end
      else inc(i);
      until i>length(s);
    sp:=false; i:=1;  // Mehrfachzwischenräume entfernen
    repeat
      if sp and (tt[i]=#32) then delete(tt,i,1)
      else begin
        sp:=tt[i]=#32; inc(i);
        end;
      until i>length(tt);
    tt:=Trim(tt);
    end
  else tt:='';
  s:=ChangeFileExt(fileDst,TempExt);
  FilenameList.Insert(RefCnt,ExtractFilename(s)+','+IntToStr(cp));
  inc(RefCnt);
  SubCode:=RefCnt;
  WriteTextFile(s,ht,TEncoding.UTF8);                  // as Utf8
  Changed:=WriteTextFile(fileDst,tt,TEncoding.UTF8);   // as Utf8
  Result:=Changed;
  end;

{ ------------------------------------------------------------------- }
// no packing supported
function TWinMergeScript.PackFile(const fileSrc,fileDst: WideString; var Changed: WordBool;
                      Subcode: Integer): WordBool; safecall;
var
  slist          : TStringList;
  s,ht,t1,t2,sn  : string;
  sl             : TStringList;
  n1,n2,n3,n,i,cp : integer;
begin
//  MessageDlg(filesrc+' / '+filedst,mtInformation,[mbOK],0);
  Changed := false; Result := false; s:='';
  if (SubCode>0) and (SubCode<=FilenameList.Count) then begin
    slist:=TStringList.Create;
    s:=IncludeTrailingPathDelimiter(ExtractFilePath(fileSrc))+FilenameList[SubCode-1];
    sn:=ReadNxtStr(s,',');
    if not TryStrToInt(s,cp) then cp:=CP_UTF8;
    if FileExists(sn) then begin
      try
        with slist do begin
          LoadFromFile(filesrc,TEncoding.UTF8);   // as Utf8
          end;
      except
        end;
      end;
    if slist.Count>0 then begin
      sl:=TStringList.Create;
      sl.Sorted:=true;
      for i:=0 to slist.Count-1 do begin
        s:=slist[i];
        t1:=ReadNxtStr(s,#13); t2:=ReadNxtStr(t1,':');
        sl.AddObject(t2,TStringValue.Create(t1));
        end;
      try
        with slist do begin
          LoadFromFile(sn,TEncoding.UTF8);  // as Utf8
          ht:=Text;
          end;
      except
        end;
      n1:=1; s:='';
      repeat
        n2:=PosEx('>#',ht,n1);
        n3:=PosEx('<',ht,n2);
        if n3>0 then begin
          n:=sl.IndexOf(copy(ht,n2+1,n3-n2-1));
          s:=s+copy(ht,n1,n2-n1+1);
          if n>=0 then begin
            t1:=ReplaceStr((sl.Objects[n] as TStringValue).FString,'|',#13); // linebreak marker
//            t1:=WrapText((sl.Objects[n] as TStringValue).FString,80);
            s:=s+t1;
            end;
          end;
        n1:=n3;
        until n1=0;
      Changed:=WriteTextFile(fileDst,s,TEncoding.GetEncoding(cp));
      with sl do begin
        for n:=0 to Count-1 do Objects[n].Free;
        Free;
        end;
      Result:=Changed;
      end;
    slist.Free;
    end;
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

