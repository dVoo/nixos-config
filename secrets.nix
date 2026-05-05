# secrets/secrets.nix
let
  pcUserKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvUrUJzhcnAAPxgs/BnFQlYDHd2SXRqAubRVNY1QqD9Xe9eRG2BuQoHjqyrKfK47bXKc+73pfBvC57Uf7dkQFK/izOElQtBQRJrveBIwL/34DfpGcmGPtPInypkN8vmcKdUqT51dJ8tI90t6+4yHE/pSk09Vlaq6a0877wiQm7/1Mvn2NFLy5bAbjA/jVMDTMD5j0ZWTyig6d82Y6Nw8VNUIwsHOBG+E3tBdEK2fSVpOJ7CjPLqdP29uAzemTgEnjJhiMRdxDN9Ril8FTGAQLQ+2e2LnqKbQj2pRwboNk0g/kVwNC2tdSv4+UHfWvtKrEdV2LN/hkhB+Mx8oFZ2Hn3 daniel@PC";
  pcHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKEBkdrVQ7h6lyKrLpwEsv9kj2wQszIOpOQdzNxj+vq root@pc";
  xpsUserKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHx0lPZBTuVaaNU+oBRgnfLQQTwOks2OvKERgLntRD+2 daniel@xps";
  xpsHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH0jMj00ssIeg3fgXFEwi5PYjd7jHhPHu7WVc4gMlQTH root@xps";

  all = [
    pcUserKey
    pcHostKey
    xpsUserKey
    xpsHostKey
  ];
  trust = [
    pcUserKey
    xpsUserKey
  ];
in
{
  "secrets/kubeconfig.age".publicKeys = trust;
  "secrets/weather-api-key.age".publicKeys = all;
  "secrets/openrouter-api-key.age".publicKeys = trust;
}
