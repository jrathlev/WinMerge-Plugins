(* Winmerge Plugin
   ---------------
   Unpack: Remove HTML tags from file to compare pure text with WinMerge
     and keep the original HTML fiel as template with placeholders
   Pack: Replace the placeholders in the template with merged text

   Requires PreDiffer plugin "IgnoreHtmlMarker"

   � Dr. J. Rathlev, D-24222 Schwentinental (kontakt(a)rathlev-home.de)

   The contents of this file may be used under the terms of the
   Mozilla Public License ("MPL") or
   GNU Lesser General Public License Version 2 or later (the "LGPL")

   Software distributed under this License is distributed on an "AS IS" basis,
   WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
   the specific language governing rights and limitations under the License.

   created: 2011-08-01
   *)

library IgnoreHtmlTags;

uses
  System.Win.ComServ,
  IgnoreHtmlTagsUnit in 'IgnoreHtmlTagsUnit.pas';

exports
  DllGetClassObject,
  DllCanUnloadNow,
  DllRegisterServer,
  DllUnregisterServer;

{$R *.TLB}

{$R *.RES}

begin
end.
