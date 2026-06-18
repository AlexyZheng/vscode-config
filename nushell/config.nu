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

# Set Fcitx environment variables for the session
$env.GTK_IM_MODULE = "fcitx"
$env.QT_IM_MODULE = "fcitx"
$env.XMODIFIERS = "@im=fcitx"
# $env.SDL_IM_MODULE = "fcitx"

# Aliases
alias vps = ssh ubuntu@82.70.46.93

alias apt = pac
alias micro = sudo nano -A -D -F -G -G -I -L -M -S -U -Z -a -l -q -_ -/
alias nano = sudo nano -A -D -F -G -G -I -L -M -S -U -Z -a -l -q -_ -/
alias docker = sudo podman
alias pacman = sudo pacman
alias pacman.conf = sudo nano /etc/pacman.conf
alias yay = paru
alias cachyos-rate-mirrors = sudo cachyos-rate-mirrors


alias bash = sudo bash -c
alias b = sudo bash -c


# Text processing (Nushell equivalents)
alias cat = open


