#!/usr/bin/env bash
# ~/.bashrc -- Bash interactive shell configuration
# Sources shared configs from ~/.shell/

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Source shared configs (bash/zsh compatible)
SHELL_CONFIG_DIR="${HOME}/.shell"
if [[ -d "$SHELL_CONFIG_DIR" ]]; then
    for config_file in "$SHELL_CONFIG_DIR"/*.sh; do
        # shellcheck disable=SC1090
        [[ -f "$config_file" ]] && source "$config_file"
    done
fi

# Bash-specific settings
shopt -s histappend
shopt -s checkwinsize
shopt -s globstar 2>/dev/null

HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth
