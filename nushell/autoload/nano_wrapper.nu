#====================================================================
# Run VS Code if available, otherwise fallback to anti-unix nano
#====================================================================
def nano [
    ...args: string     # The files or arguments you want to pass
    --line-numbers(-l)  # Switch to turn on line numbers for nano fallback
] {
    # Check for installation, AND that standard input is a terminal
    let vscode_installed = (which code | is-not-empty)
    let is_tty = (is-terminal --stdin)

    if ($vscode_installed and $is_tty) {
        let editor_cmd = if ($env | get -o VISUAL) != null { $env.VISUAL } else { ["code"] }
        let binary = $editor_cmd | first
        let env_flags = $editor_cmd | drop 1

        ^$binary ...$env_flags ...$args
    } else {
        let base_flags = ["-A" "-D" "-F" "-G" "-I" "-L" "-M" "-S" "-U" "-Z" "-a" "-q" "-_" "-/"]
        
        let final_flags = if $line_numbers {
            $base_flags | append ["-l"]
        } else {
            $base_flags
        }

        # Safe fallback execution path for minimal/single-user environments
        ^run0 --empower --setenv=PATH /usr/bin/nano ...$final_flags ...$args
    }



}




#====================================================================
# Separate logic for running elevated nano directly with run0
#====================================================================
def "sudo nano" [
    ...args: string     # The files or paths you want to edit as root
    --line-numbers(-l)  # Switch to turn on line numbers
] {
    let base_flags = ["-A" "-D" "-F" "-G" "-I" "-L" "-M" "-S" "-U" "-Z" "-a" "-q" "-_" "-/"]
    
    let final_flags = if $line_numbers {
        $base_flags | append ["-l"]
    } else {
        $base_flags
    }

    run0 --empower --setenv=PATH /usr/bin/nano ...$final_flags ...$args
}
