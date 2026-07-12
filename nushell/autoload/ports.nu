
export def --env "ports" [] {
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
