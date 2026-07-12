# Helper completion function: Generates the main core subcommands
def "complete cargo subcommands" [] {
    [
        { value: "install", description: "Fetch and securely migrate a precompiled binary using run0" },
        { value: "uninstall", description: "Purge a migrated binary from system and local configurations" },
        { value: "list", description: "Display a structured table of securely migrated system binaries" },
        { value: "build", description: "Compile a local package using the native toolchain" },
        { value: "run", description: "Run a binary or convenience example of the local project" },
        { value: "test", description: "Execute all local unit and integration tests" },
        { value: "check", description: "Analyze the local package and report compiler errors instantly" }
    ]
}

# Helper completion function: Dynamically reads your local json registry database
def "complete cargo installed packages" [] {
    let tracking_file = ("~/.cargo/.crates2.json" | path expand)
    if not ($tracking_file | path exists) { return [] }

    try {
        open $tracking_file 
        | get insts 
        | record keys 

        | each {|key| $key | split row " " | get 0}
    } catch {
        []
    }
}

# FIX: External context block that binds completions to specific subcommands dynamically
def "complete cargo custom" [context: string, pos: int] {
    let words = ($context | str trim | split row " ")
    let word_count = ($words | length)

    if $word_count <= 1 {
        # Cursor is right behind 'cargo ', show subcommands
        complete cargo subcommands
    } else if $word_count == 2 and ($words | get 1) == "uninstall" {
        # Cursor is behind 'cargo uninstall ', show packages
        complete cargo installed packages
    } else {
        []
    }
}

# Exported custom wrapper utilizing robust directory delta calculations and native completions
# FIX: Swapped positional arguments for a flat array to prevent 'cargo install' argument bugs
export def --wrapped cargo [
    ...args: string@"complete cargo custom" 
] {
    let action = ($args | get -o 0)

    # GUARD: If user types 'cargo' or 'cargo install' with zero parameters, pass straight to raw cargo safely
    if ($action | is-empty) or (($action == "install" or $action == "uninstall") and ($args | length) == 1) {
        ^cargo ...$args
        return
    }

    # LOOP 1: SYSTEM INSTALLATION HOOK
    if $action == "install" {
        let package_args = ($args | skip 1)
        let clean_pkg = ($package_args | where {|x| not ($x | str starts-with "-")} | get -o 0)
        
        if ($clean_pkg | is-empty) {
            # Fallback if installing via --path or --git
            ^cargo ...$args
            return
        }

        print $"(ansi green)Running cargo-binstall for ($clean_pkg)...(ansi reset)"
        
        mkdir ~/.cargo/bin
        let cargo_home_bin = ("~/.cargo/bin" | path expand)
        let binaries_before = (ls $cargo_home_bin | get -o name | path basename)

        ^cargo binstall -y --force ...$package_args
        
        if $env.LAST_EXIT_CODE != 0 {
            print -e $"(ansi red_bold)Error:(ansi reset) cargo-binstall failed to process ($clean_pkg)."
            error make {msg: "Installation aborted"}
        }

        let binaries_after = (ls $cargo_home_bin | get -o name | path basename)
        let new_binaries = ($binaries_after | where {|x| not ($binaries_before | any {|b| $b == $x})})

        let binary_list = (if ($new_binaries | is-empty) {
            let possible_names = [$clean_pkg]
            let variations = (if ($clean_pkg | str contains "-") {
                $possible_names | append ($clean_pkg | split row "-" | last)
            } else {
                $possible_names
            })
            
            $variations | where {|name| ($cargo_home_bin | path join $name | path exists)}
        } else {
            $new_binaries
        })

        if ($binary_list | is-empty) {
            print $"(ansi yellow)Warning:(ansi reset) Installation succeeded, but no target binary could be mapped at ($cargo_home_bin). Skipping migration."
            return
        }

        $binary_list | each {|bin_name|
            let source_binary = ($cargo_home_bin | path join $bin_name)
            let target_destination = $"/usr/local/bin/($bin_name)"

            if ($source_binary | path exists) {
                print $"(ansi cyan)Migrating binary '($bin_name)' to system paths via native run0...(ansi reset)"
                ^run0 cp $source_binary $target_destination
                ^run0 chmod 755 $target_destination
                
                if $env.LAST_EXIT_CODE != 0 {
                    print -e $"(ansi red_bold)Error:(ansi reset) Failed to migrate ($bin_name)."
                } else {
                    print $"(ansi green_bold)Success:(ansi reset) ($bin_name) is now securely available at ($target_destination)"
                }
            }
        } | null

    # LOOP 2: SYSTEM UNINSTALLATION HOOK
    } else if $action == "uninstall" {
        let package_args = ($args | skip 1)
        let clean_pkg = ($package_args | where {|x| not ($x | str starts-with "-")} | get -o 0)

        if ($clean_pkg | is-empty) {
            ^cargo ...$args
            return
        }

        let potential_names = [$clean_pkg]
        let potential_names = (if ($clean_pkg | str contains "-") {
            $potential_names | append ($clean_pkg | split row "-" | last)
        } else {
            $potential_names
        })

        $potential_names | each {|name|
            let target_destination = $"/usr/local/bin/($name)"
            if ($target_destination | path exists) {
                print $"(ansi yellow)Removing global system binary ($target_destination) via run0...(ansi reset)"
                ^run0 rm $target_destination
            }
        } | null

        print $"(ansi green)Cleaning up local user space files...(ansi reset)"
        ^cargo ...$args

    # LOOP 3: TYPED-VARIABLE BASED LIST PIPELINE
    } else if $action == "list" {
        let cargo_home_bin = ("~/.cargo/bin" | path expand)
        
        if not ($cargo_home_bin | path exists) {
            print "No local cargo tools found."
            return
        }

        let raw_contents = (ls $cargo_home_bin)
        if ($raw_contents | is-empty) {
            print "No tools found in local path directory."
            return
        }

        let user_binaries = ($raw_contents | get name)
        mut global_tools = []
        
        for user_bin in $user_binaries {
            let bin_name = ($user_bin | path basename)
            let system_bin = $"/usr/local/bin/($bin_name)"
            
            if ($system_bin | path exists) {
                let sys_meta = (ls $system_bin | get 0)
                $global_tools = ($global_tools | append {
                    binary: $bin_name,
                    global_path: $system_bin,
                    size: $sys_meta.size,
                    modified: $sys_meta.modified
                })
            }
        }

        $global_tools

    } else {
        # Pass standard loops (build, check, test, run) natively straight to system cargo
        ^cargo ...$args
    }
}
