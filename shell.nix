{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {

buildInputs = with pkgs; [
python3Packages.Mako # template processor
];

}
