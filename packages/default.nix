{ pkgs }:

{
  bili23-downloader = pkgs.callPackage ./bili23-downloader { };
  feilian = pkgs.callPackage ./feilian { };
  micyou-cli = pkgs.callPackage ./micyou-cli { };
  nyxt4 = pkgs.callPackage ./nyxt4 { };
  opentypeless = pkgs.callPackage ./opentypeless { };
  psst-auth = pkgs.callPackage ./psst-auth { };
  shmooz = pkgs.callPackage ./shmooz { };
}
