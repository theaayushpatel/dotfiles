# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

## GNU Stow Guide

### 1. Apply / Link Dotfiles
To symlink all configuration files and folders from this repository into your home directory (`~`):

```bash
cd ~/dotfiles
stow -t ~ .
```

- `-t ~` / `--target=~`: Specifies the target directory where the symlinks will be created (your `$HOME` directory).
- `.`: Uses the current directory (`dotfiles`) as the package to stow.

---

### 2. Remove / Unlink Dotfiles
To safely remove the symlinks created by Stow without deleting your source repository files:

```bash
cd ~/dotfiles
stow -D .
```

- `-D` / `--delete`: Unlinks/removes all symlinks pointing to this repository from the target directory.

---

### Helpful Stow Options

| Command | Description |
| :--- | :--- |
| `stow -R .` / `stow --restow .` | Prunes broken symlinks and recreates all links (useful after renaming or moving files). |
| `stow -n -v -t ~ .` | **Dry run**: Simulates what Stow will link or unlink without making any real changes. |
| `stow --adopt -t ~ .` | Adopts existing conflicting files in `$HOME` by copying them back into the repository before linking. |

