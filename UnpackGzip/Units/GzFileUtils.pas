(* Delphi Unit (Unicode)
   procedures and functions for file processing in GzUtils
   =======================================================

   © Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

   The contents of this file may be used under the terms of the
   Mozilla Public License ("MPL") or
   GNU Lesser General Public License Version 2 or later (the "LGPL")

   Software distributed under this License is distributed on an "AS IS" basis,
   WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
   the specific language governing rights and limitations under the License.

   Version 1.0 : March 2021
   *)

unit GzFileUtils;

interface

uses WinApi.Windows;

type
  TInt64 = record
    case integer of
    0: (AsInt64 : int64);
    1: (Lo, Hi  : Cardinal);
    2: (Cardinals: array [0..1] of Cardinal);
    3: (Words: array [0..3] of Word);
    4: (Bytes: array [0..7] of Byte);
    5 :(FileTime : TFileTime);
    end;

  TFileTimestamps = record
    Valid          : boolean;
    CreationTime,
    LastAccessTime,
    LastWriteTime  : TFileTime;
    end;

  TFileData = record
    TimeStamps : TFileTimestamps;
    FileSize   : int64;
    FileAttr   : cardinal;
    end;

// convert Delphi time to Unix time and reverse
function DateTimeToUnixTime (dt : TDateTime) : cardinal;
function UnixTimeToDateTime (ut : cardinal) : TDateTime;

// convert Filetime to Unix time and reverse
function FileTimeToUnixTime (ft : TFileTime) : cardinal;
function UnixTimeToFileTime (ut : cardinal) : TFileTime;

// get file size, timestamps and attributes
function GetFileData (const FileName : string; var FileData : TFileData) : boolean;

// set file timestamps (UTC)
function SetFileTimestamps (const FileName: string; Timestamps : TFileTimestamps;
                            CheckTime,SetCreationTime : boolean) : integer;


implementation

uses System.SysUtils;

{ ------------------------------------------------------------------- }
// convert Delphi time to Unix time (= seconds since 00:00:00 UTC, 1.1.1970) and reverse
function DateTimeToUnixTime (dt : TDateTime) : cardinal;
begin
  Result:=round(SecsPerDay*(dt-25569));
  end;

function UnixTimeToDateTime (ut : cardinal) : TDateTime;
begin
  Result:=ut/SecsPerDay+25569;
  end;

// convert Filetime to Delphi time (TDateTime)
function FileTimeToDateTime (ft : TFileTime; var dt : TDateTime) : boolean;
var
  st : TSystemTime;
begin
  Result:=false;
  if not (FileTimeToSystemTime(ft,st) and TrySystemTimeToDateTime(st,dt)) then dt:=Now
  else Result:=true;
  end;

// convert Delphi time (TDateTime) to Filetime
function DateTimeToFileTime (dt : TDateTime) : TFileTime;
var
  st : TSystemTime;
begin
  with st do begin
    DecodeDate(dt,wYear,wMonth,wDay);
    DecodeTime(dt,wHour,wMinute,wSecond,wMilliseconds);
    end;
  SystemTimeToFileTime(st,Result);
  end;

// convert Filetime to Unix time and reverse
function FileTimeToUnixTime (ft : TFileTime) : cardinal;
var
  dt : TDateTime;
begin
  FileTimeToDateTime(ft,dt);
  Result:=DateTimeToUnixTime (dt);
  end;

function UnixTimeToFileTime (ut : cardinal) : TFileTime;
begin
  Result:=DateTimeToFileTime(UnixTimeTodateTime(ut));
  end;

{ ---------------------------------------------------------------- }
// get file or directory timestamps (UTC) from FindData
function GetTimestampsFromFindData(const FindData : TWin32FindData) : TFileTimestamps;
begin
  with Result do begin
    CreationTime:=FindData.ftCreationTime;
    LastAccessTime:=FindData.ftLastAccessTime;
    LastWriteTime:=FindData.ftLastWriteTime;
    Valid:=true;
    end;
  end;

// set file or directory timestamps (UTC)
// CheckTime = true: Change FileTime to actual time if out of range
// SetCreationTime = true: Copy timestamp ftCreationTime
function SetFileTimestamps (const FileName: string; Timestamps : TFileTimestamps;
                            CheckTime,SetCreationTime : boolean) : integer;
var
  Handle   : THandle;
  tm       : TFiletime;
  dt       : TDateTime;
  fn,tn    : string;
  ok       : boolean;
begin
  tm:=DateTimeToFileTime(Now);
  with Timestamps do if Valid then begin
    if CheckTime then begin
      if not FileTimeToDateTime(CreationTime,dt) or (dt>Now+1) then CreationTime:=tm;
      if not FileTimeToDateTime(LastAccessTime,dt) or (dt>Now+1) then LastAccessTime:=tm;
      if not FileTimeToDateTime(LastWriteTime,dt) or (dt>Now+1) then LastWriteTime:=tm;
      end;
    end
  else begin
    CreationTime:=tm;
    LastAccessTime:=tm;
    LastWriteTime:=tm;
    end;

  fn:=FileName;
  Handle:=CreateFile(PChar(fn),FILE_WRITE_ATTRIBUTES,0,nil,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,0);
  if Handle=THandle(-1) then Result:=GetLastError
  else with Timestamps do begin
    if SetCreationTime then ok:=SetFileTime(Handle,@CreationTime,@LastAccessTime,@LastWriteTime)
    else ok:=SetFileTime(Handle,nil,nil,@LastWriteTime);
    if ok then Result:=NO_ERROR else Result:=GetLastError;
    FileClose(Handle);
    end;
  end;

{ ------------------------------------------------------------------- }
// get file size, timestamps and attributes
function GetFileData (const FileName : string; var FileData : TFileData) : boolean;
var
  FindRec : TSearchRec;
  FindResult : integer;
begin
  Result:=false;            // does not exist
  with FileData do begin
    FillChar(TimeStamps,sizeof(TFileTimestamps),0);
    FileSize:=0; FileAttr:=INVALID_FILE_ATTRIBUTES;
    FindResult:=FindFirst(FileName,faAnyFile,FindRec);
    if (FindResult=0) then with FindRec do begin
      TimeStamps:=GetTimestampsFromFindData(FindData);
      FileSize:=Size;
      FileAttr:=FindData.dwFileAttributes;
      Result:=true;
      end;
    FindClose(FindRec);
    end;
  end;

end.
