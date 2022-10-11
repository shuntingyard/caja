# caja
Simple, rather minimal zsh theme. Some code has been stolen from [Pure](https://github.com/sindresorhus/pure).

## Installation
1. Clone this repo somewhere. Here we'll use `$HOME/.zsh/pure`.
```sh
mkdir -p "$HOME/.zsh"
git clone https://github.com/shuntingyard/caja.git "$HOME/.zsh/caja"
```

2. Add the path of the cloned repo to `$fpath` in `$HOME/.zshrc`.
```sh
# .zshrc
fpath+=($HOME/.zsh/pure)
```

3. Enable the `prompt` function in `$HOME/.zshrc`.
```sh
# .zshrc
autoload -U promptinit
promptinit
```

## How to use caja
When in zsh
```
prompt -h caja
```
to get help about settings and more.

## TODO
[ ] Write a concise help text.
