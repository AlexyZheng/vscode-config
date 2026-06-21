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
fastfetch --logo none --config ~/.config/fastfetch/config.jsonc
$env.config.show_banner = false
$env.PROMPT_COMMAND_RIGHT = ""
$env.config.buffer_editor = ["nano" -A -D -F -G -G -I -L -M -S -U -Z -a -l -q -_ -/]

use ~/.config/nushell/scripts/bash-env.nu

# Set Fcitx environment variables for the session
$env.GTK_IM_MODULE = "fcitx"
$env.QT_IM_MODULE = "fcitx"
$env.XMODIFIERS = "@im=fcitx"
# $env.SDL_IM_MODULE = "fcitx"

# Aliases
def "sudo nano" [...args: string] {
    ^sudo nano -A -D -F -G -I -L -M -S -U -Z -a -l -q '-_' '-/' ...$args
}

def nano [...args: string] {
    ^sudo nano -A -D -F -G -I -L -M -S -U -Z -a -l -q '-_' '-/' ...$args
}

alias vps = ssh ubuntu@rabota.76543211.xyz
alias yay = paru
alias cachyos-rate-mirrors = sudo cachyos-rate-mirrors
alias docker = sudo podman
alias certbot = sudo certbot
alias apt-get = sudo apt-get
#alias apt = sudo apt
alias apt = pac
alias pacman = sudo pacman
alias pacman.conf = sudo nano /etc/pacman.conf
alias systemctl = sudo systemctl
# Text processing aliases (Nushell equivalents)
alias cat = open


# 1. Fetch system details safely using modern sys commands
let host_data = (sys host | select hostname os_version kernel_version uptime)

# 2. Extract BIOS firmware info
let bios_version = (try { open /sys/class/dmi/id/bios_version | str trim } catch { null })

# 3. Extract Android-specific properties using socat to Android's native shell (suppress socat errors via bash subshell)
let android_release = (try {
    (echo "getprop ro.build.version.release" | socat - tcp:localhost:5555 | complete | get stdout | str trim)
} catch { null })

let android_sdk = (try {
    (echo "getprop ro.build.version.sdk" | socat - tcp:localhost:5555 | complete | get stdout | str trim)
} catch { null })

# 3b. Merge Android info into single formatted string
let android_version = if ($android_release != null and $android_sdk != null and ($android_release | is-not-empty) and ($android_sdk | is-not-empty)) {
    $"[($android_release) (SDK ($android_sdk))]"
} else {
    null
}


let android_kernel_version = (try {
    (echo "uname -r" | socat - tcp:localhost:5555 | complete | get stdout | str trim)
} catch { null })

# 4. Merge all gathered metrics into one uniform Nushell Record
let result = (
    $host_data
    | insert bios_version $bios_version
    | move bios_version --after hostname
    | move os_version --after kernel_version
    | insert android_kernel_version $android_kernel_version
    | move android_kernel_version --after os_version
    | insert android_version $android_version
    | move android_version --after android_kernel_version

)

# 5. Filter out null/empty values using where with explicit row parameter
let filtered_result = (
    $result
    | transpose key value
    | where {|row| ($row.value | is-not-empty) and ($row.value != "")}
    | transpose --header-row --as-record
)

# 6. Print system info record and uptime on separate lines
if not ($filtered_result | is-empty) {
    print ($filtered_result | reject uptime)
    print $"  uptime: ($filtered_result | get uptime)"
}

#####################################################################################################

#temporary bash shell
def bash_prompt [] {
    let user = ($env.USER? | default "user")
    let host = (sys host | get hostname | default "host")
    let raw_pwd = $env.PWD
    let home = ($env.HOME? | default "")

    let current_dir = if $home != "" and $raw_pwd == $home {
        "~"
    } else if $home != "" and ($raw_pwd | str starts-with $home) {
        $raw_pwd | str replace $home "~"
    } else {
        $raw_pwd | path basename
    }

    $"[($user)@($host) ($current_dir)]$ "
}

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
    let stderr = ($check.stderr | default "")

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

def b [] {
    mut lines = []

    loop {
        let prompt = if (($lines | length) == 0) {
            bash_prompt
        } else {
            "bash> "
        }

        let line = try {
            input --reedline $prompt
        } catch {
            return
        }

        $lines = ($lines | append $line)

        let code = ($lines | str join "\n")

        if not (bash_needs_more $code) {
            break
        }
    }

    let code = ($lines | str join "\n")

    try {
        ^bash -c $code
    } catch {
        null
    }
}
