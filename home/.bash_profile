# Bash login shell.
# Kept thin on purpose: environment lives in .profile, interactive config in
# .bashrc (which sources .profile itself).
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
