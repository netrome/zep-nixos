let
  marten = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAl4uMk/HNkQauwnCoX4nBWmEp0Qka4rQ7YNxBET/9w8 marten@edo";
  zep = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHseT8DjWLWiSMWIKctVtde5Ne+nF4GPv+g6svaRorOz root@zep";
in
{
  "mindex-env.age".publicKeys = [ marten zep ];
  "github-pat-dev-near.age".publicKeys = [ marten zep ];
}
