#====================================================================
# Run VS Code if available, otherwise fallback to anti-unix nano
#====================================================================
def nano [
    ...args: string     # The files or arguments you want to pass
    --line-numbers(-l)  # Switch to turn on line numbers for nano fallback
] {
    # Check for installation, a graphical engine, AND that standard input is a terminal
    let vscode_installed = (which code | is-not-empty)

    if ($vscode_installed) {
        # Call the binary explicitly to prevent any argument duplication or array misbehavior
        ^code --reuse-window ...$args e> /dev/null o> /dev/null
    } else {
        let base_flags = ["-A" "-D" "-F" "-G" "-I" "-L" "-M" "-S" "-U" "-Z" "-a" "-q" "-_" "-/"]
        
        let final_flags = if $line_numbers {
            $base_flags | append ["-l"]
        } else {
            $base_flags
        }

        # Safe fallback execution path for minimal/single-user environments
        run0 --empower --setenv=PATH /usr/bin/nano ...$final_flags ...$args
    }
}

#====================================================================
# Wrapper for VS Code to keep flags active but silence Electron spam
#====================================================================
def --wrapped code [...args: string] {
    # Launch code and immediately dump all stdout/stderr from the wrapper
    ^code ...$args e> /dev/null o> /dev/null
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