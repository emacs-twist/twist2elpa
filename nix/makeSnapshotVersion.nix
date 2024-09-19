# * Construct an ELPA-devel like version string (i.e. suffixed with .0.DATE.TIME).
{ lib }:
{ sourceInfo }:
version:
let
  inherit (builtins) substring;
  versionBody = if version != null then version else "0.0.0";

  normalizeDigits = str: builtins.elemAt (builtins.match "0*(.+)" str) 0;

  dateComponent = substring 0 8 (sourceInfo.lastModifiedDate);

  timeComponent = normalizeDigits (substring 8 6 (sourceInfo.lastModifiedDate));
in
if sourceInfo != null && sourceInfo ? lastModifiedDate then
  versionBody + ".0.${dateComponent}.${timeComponent}"
else
  versionBody
