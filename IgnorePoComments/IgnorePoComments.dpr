(* Winmerge Plugin
   ---------------
   Unpack: Remove all lines starting with '#' from po file
   Pack:   not supported

   © Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

   The contents of this file may be used under the terms of the
   Mozilla Public License ("MPL") or
   GNU Lesser General Public License Version 2 or later (the "LGPL")

   Software distributed under this License is distributed on an "AS IS" basis,
   WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
   the specific language governing rights and limitations under the License.

   created: 2011-12-02
   *)

library IgnorePoComments;

uses
  System.Win.ComServ,
  IgnorePoCommentsUnit in 'IgnorePoCommentsUnit.pas';

exports
  DllGetClassObject,
  DllCanUnloadNow,
  DllRegisterServer,
  DllUnregisterServer;

{$R *.RES}

{$R *.TLB}

begin
end.

