(* Delphi-Unit
  Error codes and messages for ExtFileTools and FtpFileTools

  © Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

  Acknowledgements:
  ZLibEx (Vers. 1.2.3) and ZLib routines from http://www.base2ti.com
  AES functions from http://fp.gladman.plus.com/index.htm

  The contents of this file may be used under the terms of the
  Mozilla Public License ("MPL") or
  GNU Lesser General Public License Version 2 or later (the "LGPL")

  Software distributed under this License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
  the specific language governing rights and limitations under the License.

  last modified: August 2020
*)

unit FileErrors;

interface

const
  // error codes
  errOK = 0;
  errFileCreate = 1;
  errFileOpen = 2;
  errFileClose = 3;
  errFileRead = 4;
  errFileWrite = 5;
  errFileAttr = 6; // Error setting attr.
  errFileFull = 7;
  errFileGZip = 8; // ill. GZip header
  errFileCheck = 9; // corrupt copied or packed file
  errFileECrypt = 10; // error encrypting file
  errFileDCrypt = 11; // error decrypting file
  errFileVerify = 12; // verification error
  errLongPath = 13; // path too long (>260)
  errNotFound = 14; // source file not found
  errFileTS = 15; // Error setting timestamp after copy
  errStorage = 16; // Error copying document summary
  errTimeout = 17; // Timeout error on file transfer
  errStream = 18; // undefined stream
  errAcl = 19; // Error copying ACL
  errFileExists = 20; // File already exists
  errSzMismatch = 21; // verify error (size mismatch)
  errVerOpen = 22; // verify error (opening file)
  errDirCreate = 23; // could not create directory
  errFtpRead = 24; // error reading via FTP
  errFtpWrite = 25; // error writing via FTP
  errFtpConnect = 26; // connection error on FTP
  errFtpBroken = 27; // connection reset by server
  errFTPDatConn = 28; // error opening data connection
  errFtpTimeout = 29; // Timeout error on file transfer
  errCompare = 30; // verify error (Error comparing files)
  errZipCrSeg = 31; // Error creating new zip segment
  errSignature = 32; // ill. Zip signature
  errExtract = 33; // Error extracting file
  errFormat = 34; // Unsupported file format
  errTmpFile = 35; // Temp. file could not be renamed
  errZipRdSeg = 36; // Error reading next zip segment
  errAltStreams = 37; // Error copying alternate file streams
  errFileDel = 38; // Error deleting file
  errFileRen = 39; // Error renameing file

  errUserBreak = $80; // process stopped by user
  errAllCodes = $00FF;

  errError = $0100;
  errWarning = $0200;
  errError2 = $0300;
  errAllTypes = $0F00;

  errCopy = $1000;
  errGZip = $2000;
  errGUnzip = $3000;
  errZip = $4000;
  errEncrypt = $5000;
  errDecrypt = $6000;
  errUnzip = $7000;
  errAllSources = $F000;

  // get error message
function GetCopyErrMsg(AError: integer): string;

implementation

uses System.SysUtils, FileConsts;

{ ------------------------------------------------------------------- }
// Format without raising an exception on errors
function TryFormat(const AFormat: string; const Args: array of const): string;
begin
  try
    Result:=Format(AFormat,Args);
  except
    on E:Exception do Result:=rsStrFormatError+AFormat;
    end;
  end;

function GetCopyErrMsg(AError: integer): string;
var
  s: string;
begin
  case AError and errAllTypes of
    errError: s:=rsError;
    errError2: s:=rsError2;
    errWarning: s:=rsWarning;
  else s:=''; // rsInfo;
  end;
  case AError and errAllCodes of
    errOk : s:=SysErrorMessage(0);
    errFileCreate: s:=s + rsFileCreate; // Could not create file
    errFileOpen: s:=s + rsFileOpen; // Could not open file
    errFileClose: s:=s + rsFileClose; // Could not close file
    errFileRead: s:=s + rsFileRead; // Could not read from file
    errFileWrite: s:=s + rsFileWrite; // Could not write to file
    errFileAttr: s:=s + rsFileAttr; // File attributes could not be set
    errFileFull: s:=s + rsFileFull; // Low disk space
    errFileGZip: s:=s + rsFileGZip; // Illegal file header
    errFileCheck: s:=s + rsFileCheck; // Corrupt file
    errFileECrypt: s:=s + rsFileECrypt; // Encryption failed
    errFileDCrypt: s:=s + rsFileDCrypt; // Decryption failed
    errFileVerify: s:=s + rsFileVerify; // Verification failed
    errLongPath: s:=s + rsLongPath; // Path too long
    errNotFound: s:=s + rsNotFound; // File not found
    errFileTS: s:=s + rsFileTS; // Timestamp could not be set
    errStorage: s:=s + rsStorage; // Error copying document summary
    errTimeout: s:=s + rsTimeout; // Timeout error on copying file
    errStream: s:=s + rsStream; // Undefined stream
    errAcl: s:=s + rsAcl; // Permissions could not be copied
    errFileExists: s:=s + rsFileExists; // File already exists
    errSzMismatch: s:=s + rsSzMismatch; // Size mismatch
    errVerOpen: s:=s + rsVerOpen;
      // Could not open destination file for verification
    errDirCreate: s:=s + rsDirCreate; // Could not create directory
    errFtpRead: s:=s + rsFtpRead; // Could not read from FTP
    errFtpWrite: s:=s + rsFtpWrite; // Could not write to FTP
    errFtpConnect: s:=s + rsFtpConnect; // Could not connect to FTP server
    errFtpBroken: s:=s + rsFtpBroken; // FTP connection was closed by server
    errFTPDatConn: s:=s + rsFtpDatConn; // Could not open FTP data connection
    errFtpTimeout: s:=s + rsFtpTimeout; // Timeout error on copying file via FTP
    errCompare: s:=s + rsCompare; // Contents mismatch
    errZipCrSeg: s:=s + rsZipCrSeg; // Error creating new zip segment
    errSignature: s:=s + rsSignature; // Illegal zip signature
    errExtract: s:=s + rsExtract; // Could not extract file
    errFormat: s:=s + rsFormat; // Unsupported file format
    errTmpFile: s:=s + rsTmpFile; // Could not rename temporary file
    errZipRdSeg: s:=s + rsZipRdSeg; // Error reading next zip segment
    errAltStreams: s:=s + rsAltStreams; // Error copying alternate file streams
    errFileDel: s:=s + rsFileDel; // Error deleting file

    errUserBreak: s:=s + rsUserBreak; // Terminated by user
  else s:=s + TryFormat(rsUnknownErrCode, [AError]); // should not happen
  end;
  case AError and errAllSources of
    errCopy: s:=s + rsCopy; // (Copy)
    errGZip: s:=s + rsGZip; // (gzip)
    errGUnzip: s:=s + rsGUnzip; // (gunzip)
    errZip: s:=s + rsZip; // (Zip)
    errUnzip: s:=s + rsUnzip; // (Unzip)
    errEncrypt: s:=s + rsEnCrypt; // (Encrypt)
    errDecrypt: s:=s + rsDeCrypt; // (Decrypt)
  end;
  Result:=s;
end;

end.
