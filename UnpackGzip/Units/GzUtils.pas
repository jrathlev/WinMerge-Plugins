(* Delphi-Unit
   Copy and compare files, pack and unpack files to/from gzip format

   © Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

   The contents of this file may be used under the terms of the
   Mozilla Public License ("MPL") or
   GNU Lesser General Public License Version 2 or later (the "LGPL")

   Software distributed under this License is distributed on an "AS IS" basis,
   WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
   the specific language governing rights and limitations under the License.

   Based on ExtFileUtils.pas (version 8.6) but without encryption and zip support

   Version 1.0 : March 2021
   *)

unit GzUtils;

interface

uses Winapi.Windows, System.Classes, System.SysUtils, ZLibEx, GzFileUtils;

const
  GzExt = '.gz';      // default extension for GZip

  defBufferSize = 512*1024;     // default buffer size for copy operations

  InvalidAttributes = $FFFF;

  // ZLib parameters
  defWindowBits = -15;  // for GZip format
  defMemLevel = 8;

  // gz signature
  GzSignatur = $8b1f;
  Z_DEFLATE = 8;
  Z_LZMA = 14;   // LZMA

  // gzip operating system
  OsDos  = 0;
  OsUnix = 3;
  OsNTFS = 11;

  // gzip flag byte
  gfASCII      = $01; { bit 0 set: file probably ascii text }
  gfHeaderCrc  = $02; { bit 1 set: header CRC present }
  gfExtraField = $04; { bit 2 set: extra field present }
  gfFileName   = $08; { bit 3 set: original file name present }
  gfComment    = $10; { bit 4 set: file comment present }
  gfEncrypted  = $20; { bit 5 set: AE-2 encryption used for data after compressing }
  gfReserved   = $C0; { bits 6..7: reserved }

  ExtraGz64IDA = 1;         // Extra field tag for 64 size info (alternative value)
  ExtraGz64ID  = $464C;     // Extra field tag for 64 size info ('LF')
  ExtraGzCrypt = $524A;     // Extra field tag for encryption key mode ('JR')

  tmpGzipName = 'gzip.tmp';
  tmpUzipName = 'unzip.tmp';

  UMaxMemSize = 50*1024*1024;  // max. size of temp. memory stream (uncompressed)
  CMaxMemSize = 1024*1024;  // max. size of temp. memory stream (compressed)
  MaxCardinal = $FFFFFFFF;    // max. value for cardinals (4 bytes)

type
  TFileAction = (acNone,acCopy,acCompress,acUnCompress,acCompare);
  TFileProgressEvent = procedure(AAction : TFileAction; ACount: int64) of object;

  TByteBuffer = array of byte;

  TGzHeader = packed record
    Signature : word;
    Methode,
    Flags     : byte;
    TimeStamp : cardinal;
    XFlags,
    OpSys     : byte;
    end;

  TGzExtra64 = packed record
    SubfieldID,
    Size        : word;
    CSize,USize : int64;
    end;

  TGzExtraCrypt = packed record
    SubfieldID,
    Size,
    KeyMode     : word;
    end;

  TGzFileInfo = record
    Filename  : string;          // original filename
    UnixTime  : cardinal;        // original timestamp as Unix time
    Attr      : word;            // original file attributes
    Count,
    CSize,
    USize     : int64;           // original size
    Encrypted : boolean;         // file is encrypted
    EncMode   : integer;         // encryption depth
    end;

  // base class for all copy functions (compressed and crypted)
  TCopyThread = class (TThread)
  private
    FOnProgress      : TFileProgressEvent;
    FCheckTime       : boolean;           // check for illegal filetime
    FCompress        : boolean;
    FSysError        : cardinal;
    function CheckSysError (ASysError : cardinal) : boolean;
    function GetDone : boolean;
    procedure SetProgress (ACallBack : TFileProgressEvent);
    procedure SetTempDirectory (const ATempDir : string);
  protected
    FError,FErrFlag  : integer;
    FSysErrMsg,
    SourceName,
    DestName,
    SourceNameXL,
    DestNameXL,
    fTmpDir          : string;
    SourceFileData   : TFileData;
    FBuffer          : array of byte;
    sSource,sDest    : TStream;
    FBufSize         : cardinal;
    FUserBreak,
    FCopyTimeStamp,
    FCopyAttr,
    FOverwrite       : boolean;
    FCompLevel       : TZCompressionLevel;
    FCrc             : cardinal;
    UTotal,CTotal    : int64;
    FRatio           : integer;
    FAction          : TFileAction;
    FCount           : int64;
    function CopyStream (fSource,fDest : TStream; SLength : int64) : integer;
    function CompareStreams (fSource,fDest : TStream) : integer;
    function GzCompress (fSource,fDest : TStream) : integer;
    function GzUnCompress (fSource,fDest : TStream) : integer; overload;
    function GzUnCompress (fSource,fDest : TStream; SLength : int64) : integer; overload;
    procedure EndThread (Error : integer); virtual;
    procedure UpdateProgress;
    procedure DoProgress (AAction : TFileAction; ACount : int64); virtual;
    function OpenFiles : integer;
    function CloseFiles (FTime : TFileTimestamps; Attr : word) : integer; overload;
    function CloseFiles : integer; overload;
    function CopyFile : integer;
    procedure Execute; override;
  public
  // ASourceName  = source file,  ADestName = dest. file
    constructor Create (const ASourceName,ADestName : string;
                        ASuspend : Boolean = false; ABufSize : integer = defBufferSize;
                        APriority : TThreadPriority = tpNormal);
    destructor Destroy; override;
    procedure CancelThread; virtual;
    procedure ReleaseStreams;
    property CheckTime : boolean read FCheckTime write FCheckTime;
    property CopyAttr: boolean read FCopyAttr write FCopyAttr;
    property CopyTimeStamp : boolean read FCopyTimeStamp write FCopyTimeStamp;
    property Done  : boolean read GetDone;
    property ErrorType : integer read FErrFlag;
    property ErrorCode : integer read FError;
    property OnProgress : TFileProgressEvent read FOnProgress write SetProgress;
    property Overwrite : boolean read FOverwrite write FOverwrite;
//    property SysError : cardinal read FSysError;
    property Ratio : integer read FRatio;  // compression ratio
    property SysErrorMsg : string read FSysErrMsg;
    property TempDir : string read fTmpDir write SetTempDirectory;
    end;

  // compare two files
  TCompareThread = class (TCopyThread)
  protected
    function CompareFiles : integer;
    procedure Execute; override;
  public
    constructor Create (const ASourceName,ADestName : string;
                        ASuspend : Boolean = false; ABufSize : integer = defBufferSize;
                        APriority : TThreadPriority = tpNormal);
    end;

  // gzip compatible compression
  TGZipThread = class (TCopyThread)
  protected
    FName : string;
    function GzWriteHeader (fDest : TStream; fName : string; fTime : cardinal) : integer;
    function GzWriteTrailer (fDest : TStream; ACrc : cardinal) : integer;
    function CompressFile : integer;
    procedure Execute; override;
  public
  // ASourceName  = source file,  ADestName = gz-file,
    constructor Create (const ASourceName,ADestName : string;
                        ASuspend : Boolean = false; ABufSize : integer = defBufferSize;
                        APriority : TThreadPriority = tpNormal);
    property CompressionLevel : TZCompressionLevel read FCompLevel write FCompLevel;
    property Crc : cardinal read FCrc;
    property Filename : string read FName write FName;
    end;

  // gzip compatible uncompression
  TGUnZipThread = class (TCopyThread)
  protected
    function GzReadHeader (fSource : TStream; var fName : string;
                           var fTime : cardinal; var CSize,USize : int64) : integer;
    function GzSkipHeader (fSource : TStream) : integer;
    function GzReadSizes (fSource : TStream; var CSize,USize : int64) : integer;
    function GzReadTrailer (fSource : TStream; USize : int64) : integer;
    function UnCompressFile : integer;
    procedure Execute; override;
  public
  // ASourceName = gz-file,  ADestName = uncompressed file
    constructor Create (const ASourceName,ADestName : string;
                        ASuspend : Boolean = false; ABufSize : integer = defBufferSize;
                        APriority : TThreadPriority = tpNormal);
    property Crc : cardinal read FCrc;
    end;

  // compare gzip file to reference file
  TGZipCompareThread = class (TGUnzipThread)
  protected
    function CompareToFile : integer;
    procedure Execute; override;
  public
  // ASourceName  = gz-file, ADestName = reference file
    constructor Create (const ASourceName,ADestName : string;
                        ASuspend : Boolean = false; ABufSize : integer = defBufferSize;
                        APriority : TThreadPriority = tpNormal);
    end;

// retrieve gz file info
function GetGzInfo (sGz : TStream; var FileInfo : TGzFileInfo) : boolean;
function GzFileInfoXL (const Filename: string; var FileInfo : TGzFileInfo) : boolean;
function GzTrailer (const Filename: string; var CRC,USize : cardinal) : boolean;

function IsGzFile (const Filename : string) : boolean;

implementation

uses
  FileErrors, FileConsts;

type
  TLongWord = record
    case integer of
    0 : (LongWord : cardinal);
    1 : (Lo,Hi : word);
    end;

{ ------------------------------------------------------------------- }
// check if string has characteres >#255
function IsAnsiStr (const ws : string) : boolean;
var
  i : integer;
begin
  Result:=false;
  for i:=1 to length(ws) do if WordRec(ws[i]).Hi<>0 then exit;
  Result:=true;
  end;

// cardinal from H- und Lo word
function WordsToCardinal (HiWord,LoWord : word) : cardinal;
begin
  with TLongWord(Result) do begin
    Hi:=HiWord; Lo:=LoWord;
    end;
  end;

function SystemErrorMessage (ASysError : integer) : string;
begin
  Result:=SysErrorMessage(ASysError)+Format(' (0x%.8x)',[ASysError]);
  end;

function GetLastErrMsg : string;
begin
  Result:=Format(rsErrSystem,[SystemErrorMessage(GetLastError)]);
  end;

{ ------------------------------------------------------------------- }
function TempDirectory : string;
var
  p : pchar;
begin
  p:=StrAlloc(MAX_PATH+1);
  GetTempPath(MAX_PATH+1,p);
  Result:=p;
  Strdispose(p);
  end;

{ ------------------------------------------------------------------- }
function FilenameToXL(const FileName : string) : string;
const
  MaxPathLength = 248;  // limit from CreateDirectory (see Windsows SDK)
begin
  if (copy(FileName,1,2)='\\') then begin
    if (copy(FileName,3,2)='?\') then Result:=FileName               // has already prefix
    else Result:='\\?\UNC\'+Copy(Filename,3,length(Filename)-2);     // network
    end
  else if ((length(FileName)>1) and (FileName[2]<>':')) then Result:=Filename // relative path                                                // relative path
  else if length(FileName)>=MaxPathLength then Result:='\\?\'+FileName  // add prefix
  else Result:=FileName;                                           // let unchanged
  end;

{ ------------------------------------------------------------------- }
function GetGzHeader (fSource   : TStream;
                      var fName : string;
                      var fTime : cardinal;
                      var CSize,USize : int64) : integer;
var
  Header : TGzHeader;
  n,k,m  : word;
  b      : byte;
  s      : RawByteString;
  fp     : int64;
  Buffer : array of byte;
begin
  Result:=errOK;       // o.k.
  fName:=''; fTime:=0;
  try
    fSource.Read(Header,sizeof(TGzHeader));
    with Header do begin
      if Signature<>GzSignatur then begin
        Result:=errFileGZip; exit;
        end;
      fTime:=TimeStamp;
      with fSource do begin
        CSize:=0; USize:=0; m:=0;
        if Flags and gfExtraField <> 0 then begin   // read extra field
          Read(n,2);              // length of extra field
          while n>sizeof(word) do begin
            Read(k,sizeof(word));     // ID
            dec(n,2);
            if k=ExtraGz64IDA then begin
              Read(k,sizeof(word));  // Data size (= 16)
              Read(CSize,sizeof(int64));
              Read(USize,sizeof(int64));
              dec(n,2+2*sizeof(int64));
              end
            else if k=ExtraGzCrypt then begin
              Read(k,sizeof(word));  // Data size (= 2)
              Read(m,sizeof(word));
              dec(n,2+sizeof(word));
              end
            else begin    // overread
              Read(k,sizeof(word));  // Data size
              SetLength(Buffer,k);
              Read(Buffer[0],k);
              dec(n,2+k);
              end;
            end;
          Position:=Position+n;   // adjust stream position
          end;
        if Flags and gfFileName <> 0 then begin   // read filename
          repeat
            Read(b,1);
            if b<>0 then s:=s+AnsiChar(b);
            until b=0;
          end;
        if Flags and gfComment <> 0 then begin   // skip comment
          repeat
            Read(b,1);
            until b=0;
          end;
        if Flags and gfHeaderCrc <> 0 then Read(n,2); // skip crc16
        if OpSys=OsDos then fName:=s
        else fName:=Utf8ToString(s);
        if CSize=0 then CSize:=Size-Position-8;
        if USize=0 then begin
          fp:=Position;
          Seek (-4,soFromEnd);
          Read(USize,4);
          Position:=fp;
          end;
        end;
      end;
  except
    Result:=errFileRead; // error
    end;
  end;

{ ------------------------------------------------------------------- }
(* retrieve file info from stream *)
function GetGzInfo (sGz : TStream; var FileInfo : TGzFileInfo) : boolean;
begin
  with FileInfo do begin
    Count:=1; Attr:=InvalidAttributes;
    UnixTime:=DateTimeToUnixTime(Now);
    if GetGzHeader (sGz,Filename,UnixTime,CSize,USize)=errOK then begin
      Encrypted:=EncMode>=0;
      Result:=true
      end
    else Result:=false;
    end;
  end;

{ ------------------------------------------------------------------- }
(* retrieve file info from gz-file *)
function GzFileInfoXL (const Filename: string; var FileInfo : TGzFileInfo) : boolean;
var
  sFile : TFileStream;
begin
  Result:=false;
  try
    sFile:= TFileStream.Create(FilenameToXL(Filename),fmOpenRead+fmShareDenyNone);
    Result:=GetGzInfo(sFile,FileInfo);
    if Result then FileInfo.Attr:=FileGetAttr(FilenameToXL(Filename),false);
  finally
    sFile.Free;
    end;
  end;

function GzTrailer (const Filename: string; var CRC,USize : cardinal) : boolean;
var
  sFile  : TFileStream;
begin
  Result:=false;
  try
    sFile:= TFileStream.Create(FilenameToXL(Filename),fmOpenRead+fmShareDenyNone);
    with sFile do begin
      Seek(-8,soEnd);
      Read(Crc,4);
      Read(USize,4);
      end;
    Result:=true;
  finally
    sFile.Free;
    end;
  end;

{ ------------------------------------------------------------------- }
// check file types
function IsGzFile (const Filename : string) : boolean;
begin
  Result:=AnsiLowercase(ExtractFileExt(Filename))=GzExt;
  end;

{ ------------------------------------------------------------------- }
function ZipCrc32(Crc : cardinal; const buf; len: Integer): cardinal;
begin
  Result:=Crc32(Crc,pbyte(@buf),len);
  end;

{ ------------------------------------------------------------------- }
constructor TCopyThread.Create (const ASourceName,ADestName : string;
                                ASuspend : Boolean; ABufSize : integer;
                                APriority : TThreadPriority);
begin
  inherited Create (ASuspend);
  SourceName:=ASourceName;
  DestName:=ADestName;
  SourceNameXL:=FilenameToXL(ASourceName);
  DestNameXL:=FilenameToXL(ADestName);
  Priority:=APriority;
  FOnProgress:=nil;
  FCopyTimeStamp:=true;
  FCopyAttr:=true;
  FCheckTime:=true;
  FCompress:=false;
  FOverwrite:=false;
  FError:=errOK; FErrFlag:=errCopy;
  FSysError:=ERROR_SUCCESS; FSysErrMsg:='';
  FBufSize:=ABufSize;
  SetLength(FBuffer,FBufSize);
  FUserBreak:=false;
  UTotal:=0; CTotal:=0; FRatio:=-1;
  // init checksum
  FCrc:=Crc32(0,nil,0);
  FCompLevel:=zcDefault;
  fTmpDir:=TempDirectory;
  end;

destructor TCopyThread.Destroy;
begin
  FBuffer:=nil;
  inherited Destroy;
  end;

// returns true if error occured, set FSysError
function TCopyThread.CheckSysError (ASysError : cardinal) : boolean;
begin
  Result:=ASysError<>ERROR_SUCCESS;
  if Result then begin
    if (TLongWord(ASysError).Hi and $7FF)=0 then FSysError:=WordsToCardinal(FACILITY_WIN32,ASysError)
    else FSysError:=ASysError;
    end;
  end;

function TCopyThread.GetDone : boolean;
begin
  Result:=Terminated;
  end;

procedure TCopyThread.SetProgress (ACallBack : TFileProgressEvent);
begin
  FOnProgress:=ACallBack;
  end;

procedure TCopyThread.SetTempDirectory (const ATempDir : string);
begin
  if (length(ATempDir)>0) and DirectoryExists(ATempDir) then
    fTmpDir:=IncludeTrailingPathDelimiter(ATempDir)
  else fTmpDir:=TempDirectory;
  end;

procedure TCopyThread.EndThread (Error : integer);
begin
  if FCompress and (UTotal>0) then FRatio:=round(1000*CTotal/UTotal);
  if FSysError<>NO_ERROR then FSysErrMsg:=Format(rsErrSystem,[SystemErrorMessage(FSysError)]);
  if Error<>errOK then FError:=FErrFlag or Error;
  Terminate;
  end;

procedure TCopyThread.CancelThread;
begin
  FUserBreak:=true;
  end;

{ ------------------------------------------------------------------- }
function TCopyThread.CopyStream (fSource,fDest : TStream; SLength : int64) : integer;
var
  NRead,NWrite,fb : integer;
begin
  Result:=errOK;
  repeat
    if SLength<FBufSize then fb:=SLength else fb:=FBufSize;
    try
      NRead:=fSource.Read(FBuffer[0],fb);
      if NRead<fb then begin
        Result:=errError+errFileRead;   // z.B. wenn "sSource" gelockt ist
        FSysError:=GetLastError;
        end
      else begin
        UTotal:=UTotal+NRead;        // total number of bytes read
        DoProgress(acCopy,UTotal);
        FCrc:=ZipCrc32(FCrc,FBuffer[0],NRead);
        end;
    except
      on E:Exception do begin
        FSysErrMsg:=E.Message;
        Result:=errError+errFileRead;
        end;
      end;
    if Result=errOK then begin
      try
        if assigned(fDest) then NWrite:=fDest.Write(FBuffer[0],NRead)
        else NWrite:=NRead;
        if NWrite<NRead then Result:=errError+errFileFull; // Ziel-Medium voll
      except
        on E:Exception do begin
          FSysErrMsg:=E.Message;
          Result:=errError+errFileWrite;
          end;
        end;
      if FUserBreak then Result:=errUserBreak;
      end;
    dec(Slength,NRead);
    until (SLength<=0) or (Result<>errOK);
  end;

{ ------------------------------------------------------------------- }
function TCopyThread.CompareStreams (fSource,fDest : TStream) : integer;
var
  NRead1,NRead2,fb : integer;
  CBuffer          : array of byte;
  SLength,STotal   : int64;
begin
  sLength:=fSource.Size;
  SetLength(CBuffer,FBufSize);
  STotal:=0;
  DoProgress(acCompare,-SLength);
  if SLength<>fDest.Size then Result:=errError+errSzMismatch
  else begin
    fSource.Seek(0,soFromBeginning);
    fDest.Seek(0,soFromBeginning);
    Result:=errOK;
    repeat
      if SLength<FBufSize then fb:=SLength else fb:=FBufSize;
      try
        NRead1:=fSource.Read(FBuffer[0],fb);
        if NRead1<fb then begin
          Result:=errError+errFileRead;   // z.B. wenn "sSource" gelockt ist
          FSysError:=GetLastError;
          end
        else begin
          STotal:=STotal+NRead1;        // total number of bytes read
          DoProgress(acCompare,STotal);
          end;
      except
        on E:Exception do begin
          FSysErrMsg:=E.Message;
          Result:=errError+errFileRead;
          end;
        end;
      if Result=errOK then begin
        try
          NRead2:=fDest.Read(CBuffer[0],NRead1);
          if NRead2<NRead1 then begin
            Result:=errError2+errFileRead;    // z.B. wenn "sDest" gelockt ist
            FSysError:=GetLastError;
            end;
        except
          on E:Exception do begin
            FSysErrMsg:=E.Message;
            Result:=errError2+errFileRead;
            end;
          end;
        if FUserBreak then Result:=errUserBreak;
        end;
      dec(Slength,NRead1);
      if (Result=errOK) and not CompareMem(@FBuffer[0],@CBuffer[0],NRead1) then
        Result:=errError+errCompare;
      until (SLength<=0) or (Result<>errOK);
    end;
  CBuffer:=nil;
  end;

{ ------------------------------------------------------------------- }
function TCopyThread.GzCompress (fSource,fDest : TStream) : integer;
var
  sComp         : TZCompressionStream;
  NRead         : integer;
  fp            : int64;
begin
  Result:=errOK;       // o.k.
  // setup for GZip compatible compression
  sComp:=TZCompressionStream.Create(fDest,FCompLevel,defWindowBits);
  fp:=fDest.Position;
  repeat
    try
      NRead:=fSource.Read(FBuffer[0],FBufSize);
      if NRead<0 then begin
        Result:=errError+errFileRead;
        FSysError:=GetLastError;
        end
      else begin
        UTotal:=UTotal+NRead;        // total number of bytes read
        DoProgress(acCompress,UTotal);
        FCrc:=ZipCrc32(FCrc,FBuffer[0],NRead);
        end;
    except
      on E:Exception do begin
        FSysErrMsg:=E.Message;
        Result:=errError+errFileRead;
        end;
      end;
    if Result=errOK then begin
      try
        sComp.Write(FBuffer[0],NRead);
//   does not work with TZCompressionStream: NWrite is always equal to NRead
//        if NWrite<NRead then Result:=errError+errFileFull;  // dest disk full
      except
        on E:Exception do begin
          FSysErrMsg:=E.Message;
          Result:=errError+errFileWrite;
          end;
        end;
      if (Result=errOK) and FUserBreak then Result:=errUserBreak;
      end;
    until (NRead<FBufSize) or (Result<>errOK);
  sComp.Free;
  if (Result=errOK) and (fSource.Size>0) and (fDest.Position<=fp) then
    Result:=errError+errFileFull;  // dest disk full
  end;

function TCopyThread.GzUnCompress (fSource,fDest : TStream) : integer;
var
  ALength : int64;
begin
  with fSource do ALength:=Size-Position-8; // gz-format
  Result:=GzUnCompress (fSource,fDest,ALength);
  end;

function TCopyThread.GzUnCompress (fSource,fDest : TStream; SLength : int64) : integer;
var
  sComp         : TZDecompressionStream;
  NRead,NWrite  : integer;
  RTotal        : int64;
begin
  Result:=errOK;       // o.k.
  // setup for GZip compatible decompression
  sComp:=TZDecompressionStream.Create(fSource,SLength,defWindowBits);
  RTotal:=0;
  repeat
    try
      NRead:=sComp.Read(FBuffer[0],FBufSize);
      if NRead<0 then begin
        Result:=errError+errFileRead;
        FSysError:=GetLastError;
        end
    except
      on E:Exception do begin
        FSysErrMsg:=E.Message;
        Result:=errError+errFileRead;
        end;
      end;
    if Result=errOK then begin
      try
        FCrc:=ZipCrc32(FCrc,FBuffer[0],NRead);
        RTotal:=RTotal+NRead;
        DoProgress(acUnCompress,RTotal);
        if assigned(fDest) then NWrite:=fDest.Write(FBuffer[0],NRead)
        else NWrite:=NRead;
        UTotal:=UTotal+NWrite;        // total number of bytes written
        if (NWrite<NRead) then Result:=errError+errFileFull;    // dest disk full
      except
        on E:Exception do begin
          FSysErrMsg:=E.Message;
          Result:=errError+errFileWrite;
          end;
        end;
      if (Result=errOK) and FUserBreak then Result:=errUserBreak;
      end;
    until (NRead<FBufSize) or (Result<>errOK);;
  sComp.Free;
  end;

{ ------------------------------------------------------------------- }
procedure TCopyThread.DoProgress (AAction : TFileAction; ACount : int64);
begin
  if Assigned(FOnProgress) then begin
    FAction:=AAction; FCount:=ACount;
    Synchronize(UpdateProgress);
    end;
  end;

procedure TCopyThread.UpdateProgress;
begin
  FOnProgress(FAction,FCount);
  end;

{ ------------------------------------------------------------------- }
function TCopyThread.OpenFiles : integer;
begin
  Result:=errOK;
  if not GetFileData(SourceNameXL,SourceFileData) then Result:=errError+errNotFound;
  if Result=errOK then begin
    if (length(DestName)=0) then Result:=errError+errFileCreate;
    end;
  if Result<>errOK then exit;
  try
    sSource:=TFileStream.Create(SourceNameXL,fmOpenRead+fmShareDenyNone);
  except
    on E:EFOpenError do begin
      FSysErrMsg:=E.Message;
      Result:=errError+errFileOpen; Exit;
      end;
    end;
  // overwrite destination, reset attributes
  if FOverwrite and FileExists(DestNameXL,false) then begin
    if CheckSysError(FileSetAttr(DestNameXL,faArchive,false)) then Result:=errError+errFileAttr;
    end;
  if not FOverwrite and FileExists(DestNameXL) then Result:=errError+errFileExists;
  if Result=errOK then begin
    try
      sDest:=TFileStream.Create(DestNameXL,fmCreate);
    except
      on E:Exception do begin
        FSysErrMsg:=E.Message;
        Result:=errError+errFileCreate;
        end;
      end;
    end;
  end;

{ ------------------------------------------------------------------- }
procedure TCopyThread.ReleaseStreams;
begin
  if assigned(sSource) then try FreeAndNil(sSource); except end;
  if assigned(sDest) then try FreeAndNil(sDest); except end;
  end;

{ ------------------------------------------------------------------- }
function TCopyThread.CloseFiles (FTime : TFileTimestamps; Attr : word) : integer;
var
  FAttr : word;
begin
  Result:=errOK;
  ReleaseStreams;
  if (Result=errOK) and FCopyTimeStamp then begin
    if CheckSysError(SetFileTimestamps(DestNameXL,FTime,FCheckTime,false)) then
      Result:=errWarning+errFileTS;
    end;
  if (Result=errOK) and FCopyAttr then begin
    FAttr:=FileGetAttr(DestNameXL,false);
    if (FAttr<>Attr) and CheckSysError(FileSetAttr(DestNameXL,Attr,false)) then
      Result:=errWarning+errFileAttr;
    end;
  end;

function TCopyThread.CloseFiles : integer;
begin
  with SourceFileData do Result:=CloseFiles (TimeStamps,FileAttr);
  end;

{ ------------------------------------------------------------------- }
// copy file
function TCopyThread.CopyFile : integer;
begin
  Result:=OpenFiles;
  if Result=errOK then begin
    DoProgress(acCopy,-sSource.Size);
    Result:=CopyStream(sSource,sDest,sSource.Size);
    if Result=errOk then Result:=CloseFiles
    else ReleaseStreams;
    end
  else ReleaseStreams;
  end;

{ ------------------------------------------------------------------- }
// execute thread
procedure TCopyThread.Execute;
begin
  EndThread (CopyFile);
  end;

{ TCompareThread------------------------------------------------------------------- }
constructor TCompareThread.Create (const ASourceName,ADestName : string;
                           ASuspend : Boolean; ABufSize : integer; APriority : TThreadPriority);
begin
  inherited Create (ASourceName,ADestName,ASuspend,ABufSize,APriority);
  FErrFlag:=errCopy;
  end;

function TCompareThread.CompareFiles : integer;
begin
  Result:=errOK;
  if not FileExists(SourceNameXL) then Result:=errError+errNotFound;
  if (Result=errOK) and not FileExists(DestNameXL,false) then Result:=errError2+errNotFound;
  if Result=errOK then begin
    try
      sSource:=TFileStream.Create(SourceNameXL,fmOpenRead+fmShareDenyNone);
    except
      on E:Exception do begin
        FSysErrMsg:=E.Message;
        Result:=errError+errFileOpen;
        end;
      end;
    end;
  if Result=errOK then begin
    try
      sDest:=TFileStream.Create(DestNameXL,fmOpenRead+fmShareDenyNone);
    except
      on E:Exception do begin
        FSysErrMsg:=E.Message;
        Result:=errError+errFileCreate;
        end;
      end;
    end;
  if Result=errOK then Result:=CompareStreams(sSource,sDest);
  ReleaseStreams;
  end;

procedure TCompareThread.Execute;
begin
  EndThread (CompareFiles);
  end;

{ TGZipThread ------------------------------------------------------------------- }
constructor TGZipThread.Create (const ASourceName,ADestName : string;
                                ASuspend : Boolean; ABufSize : integer; APriority : TThreadPriority);
begin
  inherited Create (ASourceName,ADestName,ASuspend,ABufSize, APriority);
  FName:=ExtractFilename(SourceName);
  FCompress:=true;
  FErrFlag:=errGZip;
  end;

{ ------------------------------------------------------------------- }
// write gz header
// fEncMode = -1 - no encryption
//          =  0 - encryption with automatic keymode
//          >  0 - = keymode (1 = 128 bit, 3 = 256 bit)
function TGZipThread.GzWriteHeader (fDest : TStream;
                                    fName : string;
                                    fTime : cardinal) : integer;
var
  Header : TGzHeader;
  n      : integer;
  w      : word;
  os     : byte;
  s      : RawByteString;
  ef     : TGzExtra64;
begin
  Result:=errOK;       // o.k.
  if IsAnsiStr(fName) then begin    // gzip uses ISO-8859-1
    s:=fName; os:=OsDos;
    end
  else begin
    s:=UTF8Encode(fName); os:=OsNTFS;
    end;
  n:=length(s);
  with Header do begin
    Signature:=GzSignatur;
    Methode:=Z_DEFLATED;
    Flags:=gfExtraField;
    if n>0 then Flags:=Flags or gfFileName;
    TimeStamp:=fTime;
    XFlags:=0;
    OpSys:=os;
    end;
  try
    // write header
    if fDest.Write(Header,sizeof(TGzHeader))<sizeof(TGzHeader) then begin
      Result:=errError+errFileFull;  // dest disk full
      Exit;
      end;
    // write extra field with size information
    w:=sizeof(ef);
    fDest.Write(w,2);
    with ef do begin
      SubfieldID:=ExtraGz64IDA; Size:=2*sizeof(int64);
      CSize:=0; USize:=0;
      end;
    if fDest.Write(ef,sizeof(ef))<sizeof(ef) then begin
      Result:=errError+errFileFull;  // dest disk full
      Exit;
      end;
    if n>0 then begin   // write filename
      if fDest.Write(s[1],n+1)<n+1 then Result:=errError+errFileFull;  // dest disk full
      end;
  except
    on E:Exception do begin
      FSysErrMsg:=E.Message;
      Result:=errError+errFileWrite;
      end;
    end;
  end;

{ ------------------------------------------------------------------- }
// write gz trailer
function TGZipThread.GzWriteTrailer (fDest : TStream; ACrc : cardinal) : integer;
begin
  Result:=errOK;       // o.k.
  try
    with fDest do if Write(ACrc,4)<4 then Result:=errError+errFileFull  // dest disk full
    else if Write(TInt64(UTotal).Lo,4)<4 then Result:=errError+errFileFull  // dest disk full
    else begin  // write size info to extra field
      Position:=sizeof(TGzHeader)+6;
      Write(CTotal,sizeof(int64));
      Write(UTotal,sizeof(int64));
      end;
  except
    on E:Exception do begin
      FSysErrMsg:=E.Message;
      Result:=errError+errFileWrite; // error
      end;
    end;
  end;

{ ------------------------------------------------------------------- }
// compress file
function TGZipThread.CompressFile  : integer;
var
  utime         : cardinal;
  fp            : int64;
begin
  Result:=OpenFiles;
  if Result=errOK then begin
    // unix time for gzip
    utime:=FileTimeToUnixTime(SourceFileData.TimeStamps.LastWriteTime);
    Result:=GzWriteHeader(sDest,FName,utime);
    fp:=sDest.Position;
    // compress file
    if Result=errOK then begin
      DoProgress(acCompress,-sSource.Size);   // Reset progress indicator
      Result:=GzCompress(sSource,sDest);
      if Result=errOK then begin
        // z.B. wenn "sSource" gelockt ist (siehe LockFile)
        if UTotal<>sSource.Size then begin
          Result:=errError+errFileRead;
          FSysError:=GetLastError;
          end;
        if Result=errOK then begin
          CTotal:=sDest.Position-fp;
          Result:=GzWriteTrailer(sDest,FCrc);
          end;
        end;
      end;
    if Result=errOK then Result:=CloseFiles
    else ReleaseStreams;
    end
  else ReleaseStreams;
  end;

{ ------------------------------------------------------------------- }
// execute thread
procedure TGZipThread.Execute;
begin
  EndThread(CompressFile);
  end;

{ TGUnZipThread ------------------------------------------------------------------- }
constructor TGUnZipThread.Create (const ASourceName,ADestName : string;
                                  ASuspend : Boolean; ABufSize : integer; APriority : TThreadPriority);
begin
  inherited Create (ASourceName,ADestName,ASuspend,ABufSize,APriority);
  FErrFlag:=errGUnzip;
  end;

{ ------------------------------------------------------------------- }
// read gz header
function TGUnZipThread.GzReadHeader (fSource   : TStream;
                                     var fName : string;
                                     var fTime : cardinal;
                                     var CSize,USize : int64) : integer;
begin
  Result:=GetGzHeader (fSource,fName,fTime,CSize,USize);
  end;

function TGUnZipThread.GzSkipHeader (fSource : TStream) : integer;
var
  s : string;
  t : cardinal;
  c,u : int64;
begin
  Result:=GetGzHeader(fSource,s,t,c,u);
  end;

function TGUnZipThread.GzReadSizes (fSource   : TStream;
                                    var CSize,USize : int64) : integer;
var
  s : string;
  t : cardinal;
begin
  Result:=GetGzHeader(fSource,s,t,CSize,USize);
  end;

{ ------------------------------------------------------------------- }
// read gz trailer
function TGUnZipThread.GzReadTrailer (fSource : TStream; USize : int64) : integer;
var
  aCrc,FSize : cardinal;
begin
  Result:=errOK;       // o.k.
  try
    fSource.Read(aCrc,4);
    fSource.Read(FSize,4);
    if (FCrc<>aCrc) or (TInt64(USize).Lo<>FSize) or (USize<>UTotal) then begin
      Result:=errError+errFileCheck; exit; // checksum error
      end;
  except
    on E:Exception do begin
      FSysErrMsg:=E.Message;
      Result:=errError+errFileRead; // error
      end;
    end;
  end;

{ ------------------------------------------------------------------- }
// uncompress file
function TGUnZipThread.UncompressFile : integer;
var
  utime         : cardinal;
  FName         : string;
  fp,n,sz       : int64;
begin
  Result:=errOK;
  if not GetFileData(SourceNameXL,SourceFileData) then Result:=errError+errNotFound;
  if (Result=errOK) and (length(DestName)=0) then Result:=errError+errFileCreate;
  if Result=errOK then begin
    try
      sSource:=TFileStream.Create(SourceNameXL,fmOpenRead+fmShareDenyNone);
    except
      on E:Exception do begin
        FSysErrMsg:=E.Message;
        Result:=errError+errFileOpen;
        end;
      end;
    end;
  if Result=errOK then begin
    Result:=GzReadHeader(sSource,FName,utime,n,sz);   // sz = uncomp. size
    if (Result=errOK) then begin
      if FOverwrite and FileExists(DestNameXL,false) then begin
        if FileSetAttr(DestNameXL,faArchive,false)<>0 then Result:=errError+errFileAttr;
        end;
      end;
    if not FOverwrite and FileExists(DestNameXL) then Result:=errError+errFileExists;
    if Result=errOK then begin
      try
        sDest:=TFileStream.Create(DestNameXL,fmCreate);
      except
        on E:Exception do begin
          FSysErrMsg:=E.Message;
          Result:=errError+errFileCreate;
          end;
        end;
      end;
    if Result=errOK then begin
      fp:=sSource.Position;
      DoProgress(acUnCompress,-sz);
      Result:=GzUncompress(sSource,sDest);
      if (Result=errOK) then begin
        CTotal:=sSource.Position-fp;
        Result:=GzReadTrailer (sSource,sz);
        end;
      end;
    if Result=errOK then with SourceFileData do begin
      if utime>0 then Timestamps.LastWriteTime:=UnixTimeToFileTime(utime);
      Result:=CloseFiles (Timestamps,FileAttr)
      end
    else ReleaseStreams;
    end
  else ReleaseStreams;
  end;

procedure TGUnZipThread.Execute;
begin
  EndThread (UncompressFile);
  end;

{ TGzipCompareThread------------------------------------------------------------------- }
constructor TGzipCompareThread.Create (const ASourceName,ADestName : string;
                           ASuspend : Boolean; ABufSize : integer; APriority : TThreadPriority);
begin
  inherited Create (ASourceName,ADestName,ASuspend,ABufSize,APriority);
  FErrFlag:=errGUnzip;
  end;

function TGzipCompareThread.CompareToFile : integer;
var
  tf      : boolean;
  tzn     : string;
  sZTmp   : TStream;
  n,sz    : int64;
begin
  Result:=errOK;
  if not FileExists(SourceNameXL) then Result:=errError+errNotFound;
  if (Result=errOK) and not FileExists(DestNameXL,false) then Result:=errError2+errNotFound;
  if Result=errOK then begin
    try
      sSource:=TFileStream.Create(SourceNameXL,fmOpenRead+fmShareDenyNone);
    except
      on E:Exception do begin
        FSysErrMsg:=E.Message;
        Result:=errError+errFileOpen;
        end;
      end;
    end;
  if Result=errOK then begin
    try
      sDest:=TFileStream.Create(DestNameXL,fmOpenRead+fmShareDenyNone);
    except
      on E:Exception do begin
        FSysErrMsg:=E.Message;
        Result:=errError+errFileCreate;
        end;
      end;
    end;
  if Result=errOK then begin
    Result:=GzReadSizes(sSource,n,sz);
    if Result=errOK then begin
      tf:=sz>UMaxMemSize;
      if tf then begin
        tzn:=FilenameToXL(fTmpDir+tmpGzipName);
        sZTmp:=TFileStream.Create(tzn,fmCreate); // write to disk
        end
      else sZTmp:=TMemoryStream.Create;   // wite to memory
      DoProgress(acUnCompress,-sz);
      Result:=GzUncompress(sSource,sZTmp);
      if Result=errOK then begin
        DoProgress(acCompare,-sZTmp.Size);
        Result:=CompareStreams(sZTmp,sDest);
        end;
      sZTmp.Free;
      if tf then DeleteFile(tzn);
      end;
    end;
  ReleaseStreams;
  end;

procedure TGzipCompareThread.Execute;
begin
  EndThread (CompareToFile);
  end;

end.
