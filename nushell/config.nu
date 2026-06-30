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

# config shell environment
use std "path add"
path add "~/.local/bin"

path add ($env.HOME | path join ".cargo" "bin")
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

    # ... your existing configuration ...
    history: {file_format: "sqlite", isolation: false}
}

$env.config = {

    # ... your other configuration settings ...

    display_errors: {exit_code: false, termination_signal: false}
}

# Set Fcitx environment variables for the session
$env.GTK_IM_MODULE = "fcitx"
$env.QT_IM_MODULE = "fcitx"
$env.XMODIFIERS = "@im=fcitx"

# $env.SDL_IM_MODULE = "fcitx"

######################################################################
#Switch between shannon shell's with command "switch" - requires wayland, active ydotool socket & also bashrc config
#could try embedding required bashrc string config within this file
#otherwise just use termux as a terminal emulator, it has onscreen keys

$env.YDOTOOL_SOCKET = "/run/user/1000/.ydotool_socket"

def switch [] {
    ydotool key 42:1 15:1 15:0 42:0
}




#====================================================================
# systemd run0 wrapper
#====================================================================

# Core Wrapper: Intercepts 'sudo' and routes securely through run0
def --wrapped sudo [...args: string] {
    if ($args | is-empty) {
        # Open an interactive privileged root shell loading your styles using the detected binary
        ^run0 --background="" --setenv=PATH $nu.current-exe --env-config $nu.env-path --config $nu.config-path
    } else {
        # Convert individual command arrays into a string payload
        let cmd_string = $args | str join " "

        # Execute via setsid inside a sub-dash process for seamless Ctrl+C handling
        ^run0 --background="" --setenv=PATH setsid dash -c $"($cmd_string)"
    }
}

#====================================================================
# Run VS Code if available, otherwise fallback to anti-unix nano
#====================================================================
def nano [
    ...args: string     # The files or arguments you want to pass
    --line-numbers(-l)  # Switch to turn on line numbers for nano fallback
] {
    # 1. Check if VS Code ('code') is available in the PATH
    let vscode_installed = (which code | is-not-empty)

    if $vscode_installed {
        # Get VS Code settings from VISUAL, fallback to basic 'code' if not set
        let editor_cmd = if ($env | get -o VISUAL) != null { $env.VISUAL } else { ["code"] }
        let binary = $editor_cmd | first
        let env_flags = $editor_cmd | drop 1

        # Launch safely as a regular user (the caret '^' forces external execution)
        ^$binary ...$env_flags ...$args
    } else {
        # 2. Fallback to the real nano binary
        let base_flags = ["-A" "-D" "-F" "-G" "-I" "-L" "-M" "-S" "-U" "-Z" "-a" "-q" "-_" "-/"]
        
        let final_flags = if $line_numbers {
            $base_flags | append ["-l"]
        } else {
            $base_flags
        }

        # Use the absolute path to the binary to guarantee no infinite loop
        run0 --setenv=PATH /usr/bin/nano ...$final_flags ...$args
    }
}

### Reload Nushell cleanly on Linux by replacing the active process

def reload [] {}

  def --env "reload nu" [] {
let timestamp = (date now | format date "%H:%M:%S")
print $"(ansi green)Config reloaded at ($timestamp)!(ansi reset)"
exec nu
}


alias vps = ssh ubuntu@work.76543211.xyz

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

# Display comprehensive local system metrics and host firmware info
def sysinfo [] {
    # 1. Fetch system details safely using modern sys commands
    let host_data = sys host | select hostname os_version kernel_version uptime

    # 2. Extract BIOS firmware info
    let bios_version = (
        try {
            open /sys/class/dmi/id/bios_version | str trim
        } catch { null }
    )

    # 3. Merge all gathered metrics into one uniform Nushell Record
    let result = (
        $host_data
        | insert bios_version $bios_version
        | move bios_version --after hostname
        | move os_version --after kernel_version
    )

    # 4. Filter out null/empty values using where with explicit row parameter
    let filtered_result = (
        $result
        | transpose key value

        | where {|row| ($row.value | is-not-empty) and ($row.value != "")}
        | transpose --header-row --as-record
    )

    # 5. Print system info record and uptime on separate lines
    if not ($filtered_result | is-empty) {
        # Check if uptime exists dynamically to avoid compilation schema crashes
        if ($filtered_result | columns | any {|col| $col == "uptime"}) {
            print ($filtered_result | reject uptime)
            print $"  uptime: ($filtered_result | get uptime)"
        } else {
            print $filtered_result
        }
    }
}

######################################################################################################
# Helper: Generate the interactive bash prompt
def bash_prompt [] {
    let user = $env.USER? | default "user"
    # OPTIMIZATION: $nu.os-info is cached and instant compared to 'sys host'
    let host = $nu.os-info.hostname? | default "bash"
    let raw_pwd = $env.PWD
    let home = $env.HOME? | default ""

    let current_dir = if $home != "" and $raw_pwd == $home {
        "~"
    } else if $home != "" and ($raw_pwd | str starts-with $home) {
        $raw_pwd | str replace $home "~"
    } else {
        $raw_pwd | path basename
    }

    $"[($user)@($host) ($current_dir)]$ "
}

# Helper: Detect line continuations (\)
def bash_has_line_continuation [code: string] {
    let last_line = (
        $code
        | lines
        | last
        | default ""
        | str trim --right
    )
    $last_line | str ends-with '\'
}

def bash_needs_more [code: string] {
    if (bash_has_line_continuation $code) {
        return true
    }

    let check = (^bash -n -c $code | complete)
    let stderr = $check.stderr | default ""

    if $check.exit_code == 0 {
        return (
            ($stderr | str contains "here-document")
            and ($stderr | str contains "delimited by end-of-file")
        )
    }

    let incomplete_markers = [
        "unexpected EOF"
        "unexpected end of file"
        "syntax error: unexpected end of file"
        "looking for matching"
    ]

    $incomplete_markers | any {|marker|
        $stderr | str contains $marker
    }
}

def _bash_env_lines_to_record [] {
    lines
    | where {|line| $line != "" }
    | parse --regex '^(?P<name>[^=]+)=(?P<value>.*)$'
    | reduce -f {} {|row, acc|
      $acc | upsert $row.name $row.value
    }
}

def _bash_env_convert_value [name: string, value: string] {
    let conv = (
        try {
            $env.ENV_CONVERSIONS | get -o $name
        } catch { null }
    )

    if $conv != null {
        try {
            do $conv.from_string $value
        } catch {
            if $name in ["PATH", "Path"] {
                $value | split row (char esep)
            } else {
                $value
            }
        }
    } else if $name in ["PATH", "Path"] {
        $value | split row (char esep)
    } else {
        $value
    }
}

def _bash_env_changed_record [before: record] {
    transpose name value
    | reduce -f {} {|row, acc|
      let old = $before | get -o $row.name

      if $old == $row.value {
        $acc
      } else {
        let value = (_bash_env_convert_value $row.name $row.value)
        $acc | upsert $row.name $value
      }
    }
}

def _bash_cleanup_backups [] {
    let dir = $nu.config-path | path dirname
    try {
        ls $dir
        | where name =~ "history.sqlite3.bak"
        | each {|f| rm $f.name }
    } catch { }
}

def _bash_append_to_history [command: string] {
    $command | history import
    _bash_cleanup_backups
}

def --env bash [script?: path, --format(-f): string = "auto"] {
    let before_path = (mktemp)
    let after_path = (mktemp)

    let code = if $script != null {
        let script_path = $script | path expand
        if not ($script_path | path exists) {
            try { rm $before_path $after_path } catch { }
            error make {msg: $"bash: script does not exist: ($script_path)"}
        }
        $". '($script_path)'"
    } else {
        mut lines = []
        loop {
            let prompt = if ($lines | is-empty) {
                bash_prompt
            } else {
                "bash> "
            }

            let line = try {
                input --reedline $prompt
            } catch {
                try { rm $before_path $after_path } catch { }
                return
            }

            $lines = ($lines | append $line)
            let current_code = $lines | str join "\n"

            if not (bash_needs_more $current_code) {
                break
            }
        }
        $lines | str join "\n"
    }

    _bash_append_to_history $code

    let raw_output = try {
        let exec = (
            ^bash -c 'env > "$1"; eval "$3"; env > "$2"' nu-bash-env $before_path $after_path $code
            | complete
        )

        if ($exec.stderr | str trim) != "" {
            print -e $exec.stderr
        }

        let before = open --raw $before_path | _bash_env_lines_to_record
        let after = open --raw $after_path | _bash_env_lines_to_record
        let changes = $after | _bash_env_changed_record $before

        load-env $changes
        $exec.stdout
    } catch {
        null
    }

    try { rm $before_path $after_path } catch { }

    if $raw_output != null and ($raw_output | str trim) != "" {
        match $format {
            "json" => {
                $raw_output | from json
            }
            "csv" => {
                $raw_output | from csv
            }
            "yaml" => {
                $raw_output | from yaml
            }
            "lines" => {
                $raw_output | lines
            }
            "columns" => {
                $raw_output | detect columns --guess
            }
            _ => {
                let trimmed_out = $raw_output | str trim
                if ($trimmed_out | str starts-with "{") or ($trimmed_out | str starts-with "[") {
                    try {
                        $raw_output | from json
                    } catch {
                        $raw_output | lines
                    }
                } else {
                    try {
                        $raw_output | detect columns --guess
                    } catch {
                        $raw_output | lines
                    }
                }
            }
        }
    }
}



######################################################################################################
# Ports Scanner
######################################################################################################


def ports [] {
    let raw = (^ss -atunpH | complete)
    if $raw.exit_code != 0 or ($raw.stdout | str trim | is-empty) { return [] }

    $raw.stdout
    | lines
    | parse --regex '^(?P<protocol>\S+)\s+(?P<state>\S+)\s+(?P<recv_q>\d+)\s+(?P<send_q>\d+)\s+(?P<local>\S+)\s+(?P<peer>\S+)(?:\s+(?P<process>\S+))?$'
    | insert port {|r|
        # Split from the right side to isolate port numbers from IPv4, IPv6, and wildcards safely
        let parts = $r.local | split row ":"
        try { $parts | last | into int } catch { null }
      }
    | insert pid {|r|
        if ($r.process? | is-empty) { null } else {
            let matches = $r.process | parse --regex 'pid=(?P<id>\d+)'
            if ($matches | is-empty) { null } else { $matches.0.id | into int }
        }
      }
    | insert process_name {|r|
        if ($r.process? | is-empty) { null } else {
            let matches = $r.process | parse --regex '"(?P<name>[^"]+)"'
            if ($matches | is-empty) { null } else { $matches.0.name }
        }
      }
    | reject process recv_q send_q
}
