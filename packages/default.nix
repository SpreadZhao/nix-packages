{ pkgs }:

{
  bili23-downloader = pkgs.callPackage ./bili23-downloader { };
  cc-connect = pkgs.callPackage ./cc-connect { };
  docsify-cli = pkgs.callPackage ./docsify-cli { };
  github-copilot-app = pkgs.callPackage ./github-copilot-app { };
  zcode = pkgs.callPackage ./zcode { };
}
