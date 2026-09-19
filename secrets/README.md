# Secrets (agenix)

Every secret is declared in `modules/common.nix` and encrypted with
[agenix](https://github.com/ryantm/agenix) to the **SSH host keys** of the three
machines plus daniel's personal keys — the recipient list is `secrets.nix`.

## Why they live in the system module

`age.secrets.*` is declared in `modules/common.nix` (a NixOS module) and never in
`home.nix`. The system module decrypts during *system* activation using the host
keys in `/etc/ssh/`, which exist before any user session and do not depend on
`~/.ssh`. Home Manager's agenix module would instead need daniel's personal key
present and readable at activation time, which breaks a fresh install (and is why
the home-manager module is no longer imported in `flake.nix` at all).

Two consequences worth remembering:

* `age.identityPaths` does not need to be set — agenix's default
  (`/etc/ssh/ssh_host_ed25519_key`, `/etc/ssh/ssh_host_rsa_key`) *is* the set of
  recipients.
* A secret must never be copied into the Nix store. That is why the kubeconfig is
  put in place by an activation script in `home.nix` instead of
  `home.file."...".source`, which would copy the plaintext into the
  world-readable `/nix/store`.

## Where each secret ends up

| Secret | Path | Consumer |
| --- | --- | --- |
| `ollama-api-key`, `openrouter-api-key`, `deepseek-api-key`, `opencode-api-key` | `/run/agenix/<name>` (0400, `daniel`) | `home.sessionVariables` in `home.nix` (login shells, and required by avante.nvim) **and** the `opencode`/`aichat` wrappers (launcher / systemd user units, which never source `hm-session-vars.sh`) |
| `kubeconfig` | `/run/agenix/kubeconfig`, symlinked to `~/.kube/config` | kubectl, k9s, editor integrations |
| `weather-api-key` | **not decrypted** | none — see below |

`secrets/weather-api-key.age` is kept encrypted but is deliberately *not*
declared in `modules/common.nix`: Noctalia 5.1's weather widget is keyless (its
generated `~/.config/noctalia/config.toml` has no API-key field, and the package
only exposes `weather-unit`, `weather-refresh-interval` and `weather-effects`).
Nothing consumed it, so it was decrypted into the home directory on every boot
for no reason. Re-add it in one line when a consumer exists:

```nix
age.secrets.weather-api-key = {
  file = ../secrets/weather-api-key.age;
  owner = "daniel";
  mode = "0400";
};
```

## Adding, editing or rotating a secret

```sh
cd ~/nixos-config

# create a new secret (encrypts to the current secrets.nix recipients)
agenix -e secrets/new-secret.age

# edit an existing one
agenix -e secrets/kubeconfig.age

# re-key an existing file to the *current* recipient list
agenix -r -e secrets/kubeconfig.age

sudo nixos-rebuild switch --flake ~/nixos-config   # it appears at /run/agenix/<name>
```

## Adding a machine

A new host needs its **host** public key — `/etc/ssh/ssh_host_ed25519_key.pub`,
which is root-owned and lives on the root filesystem, not `~/.ssh` (that is on
the `/home` subvolume and is not mounted yet when activation runs):

1. add the key to the `recipients` list in `secrets.nix`
2. `agenix -r -e secrets/<name>.age` for every secret
3. declare `age.secrets.<name>` in the new host's module and rebuild

This is the churn that the "rekeyed for yoga" commits record.
