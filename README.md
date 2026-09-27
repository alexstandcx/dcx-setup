# dcx-setup

The first step of setting up a WSL or Ubuntu machine the way Alex works. On a new machine, run:

```
curl -fsSL https://raw.githubusercontent.com/alexstandcx/dcx-setup/main/install.sh | bash
```

Read it first if you like, it is short:

```
curl -fsSL https://raw.githubusercontent.com/alexstandcx/dcx-setup/main/install.sh | less
```

## What it does

1. Checks the machine runs Ubuntu or Debian (WSL included).
2. Installs git, curl and the GitHub CLI if they are missing. sudo asks for your Linux password.
3. Has you sign in to GitHub, unless you already are with an account that can read the private `alexstandcx/new-project-template`.
4. Fetches that repo into `~/.local/share/dcx/new-project-template`, or updates it (fast forward only) if it is already there.
5. Hands over to its `machine/setup.sh`, which shows a plan of everything it would change and asks before changing anything.

This repo holds nothing private. Running it again is safe: every step that is already done says so and moves on.

## Tests

`bats tests`, with sudo, apt-get and gh replaced by stand ins, so nothing is installed and nothing reaches the network.
