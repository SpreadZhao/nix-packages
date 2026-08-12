{ pkgs }:

{
  bili23-downloader = pkgs.callPackage ./bili23-downloader { };
  cc-connect = pkgs.callPackage ./cc-connect { };
  docsify-cli = pkgs.callPackage ./docsify-cli { };
  gaomon-tablet = pkgs.callPackage ./gaomon-tablet { };
  github-copilot-app = pkgs.callPackage ./github-copilot-app { };
  nyxt4 = pkgs.callPackage ./nyxt4 { };
  zcode = pkgs.callPackage ./zcode { };
}
