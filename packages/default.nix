{ pkgs }:

{
  bili23-downloader = pkgs.callPackage ./bili23-downloader { };
  cc-connect = pkgs.callPackage ./cc-connect { };
  docsify-cli = pkgs.callPackage ./docsify-cli { };
  feilian = pkgs.callPackage ./feilian { };
  gaomon-tablet = pkgs.callPackage ./gaomon-tablet { };
  micyou-cli = pkgs.callPackage ./micyou-cli { };
  nyxt4 = pkgs.callPackage ./nyxt4 { };
  opentypeless = pkgs.callPackage ./opentypeless { };
  shmooz = pkgs.callPackage ./shmooz { };
  zcode = pkgs.callPackage ./zcode { };
}
