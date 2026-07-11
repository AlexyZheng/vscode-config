# config.nu
#
# Installed by:
# version = "0.113.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings,
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

# Interactive one-shot Bash portal: Paste raw snippets natively with zero flag conflicts




# 1. Safely source the separate file using your portable relative directory path
source (($nu.config-path | path dirname) | path join "bash-globalenv.nu")

# 2. Hard-clear any lingering alias states to break namespace recursion loops
try { unalias b } catch { }
try { unalias bash } catch { }

# 3. Establish a pristine top-level alias mapping the word 'bash' straight to your utility
alias bash = bash_portal

# FIX: Swapped out the old, un-evaluated $CONFIG_DIR variable 
# for Nushell's native, compile-time $nu.default-config-dir constant
export const NU_LIB_DIRS = [
    ($nu.default-config-dir | path join 'scripts')
    ($nu.default-config-dir | path join 'autoload')
    ($nu.data-dir | path join 'completions')

]

use ~/.config/nushell/completions/adb-completions.nu *
use ~/.config/nushell/completions/cargo-completions.nu *
use ~/.config/nushell/completions/curl-completions.nu *
use ~/.config/nushell/completions/fastboot-completions.nu *
use ~/.config/nushell/completions/gh-completions.nu *
use ~/.config/nushell/completions/make-completions.nu *
use ~/.config/nushell/completions/nano-completions.nu *
use ~/.config/nushell/completions/ssh-completions.nu *
use ~/.config/nushell/completions/tcpdump-completions.nu *
use ~/.config/nushell/completions/vscode-completions.nu *




$env.config.show_banner = false
$env.PROMPT_COMMAND_RIGHT = ""


$env.VISUAL = ["code", "--reuse-window", "--wait"]
$env.EDITOR = ["nano", "-A", "-D", "-F", "-G", "-I", "-L", "-M", "-S", "-U", "-Z", "-a", "-q", "-_", "-/"]


if $env.TERM_PROGRAM? == "vscode" {
    $env.config.shell_integration = {
        osc2: true
        osc7: true
        osc8: true
        osc9_9: false
        osc133: true
        osc633: true
        reset_application_mode: true
    }
}


$env.config = {

    # ... your other configuration settings ...

    display_errors: {exit_code: false, termination_signal: false}
    history: {file_format: "sqlite", isolation: false, max_size: 1_000_000, sync_on_enter: true}
}

# Set Fcitx environment variables for the session
$env.GTK_IM_MODULE = "fcitx"
$env.QT_IM_MODULE = "fcitx"
$env.XMODIFIERS = "@im=fcitx"
# $env.SDL_IM_MODULE = "fcitx"

$env.config.keybindings ++= ($env.config.keybindings | append [
    {
        name: copy_passthrough
        modifier: control
        keycode: char_c
        mode: [emacs, vi_insert, vi_normal]
        event: null
    },
    {
name: catch_vscode_escape_sequence
        modifier: control
        keycode: char_x
        mode: [emacs, vi_insert, vi_normal]
        event: { send: CtrlC } # Forces Nushell to clear the line cleanly
    }
])
#############################################################
#simple aliases

alias visudo = EDITOR="nano -A -D -F -G -I -L -M -S -U -Z -a -q -_ -/" visudo
alias "sudo nano" = nano -A -D -F -G -I -L -M -S -U -Z -a -q -_ -/

alias systemctl = sudo systemctl
alias certbot = sudo certbot
alias apt-get = sudo apt-get
alias apt = sudo apt
alias yay = paru
alias cachyos-rate-mirrors = sudo cachyos-rate-mirrors
alias pacman = sudo pacman
alias pacman.conf = nano /etc/pacman.conf
# Text processing aliases (Nushell equivalents)
alias cat = open

alias mk = touch




