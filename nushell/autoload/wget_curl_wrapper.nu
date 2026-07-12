# Helper: Translates common wget flags into curl equivalents
def translate-wget-flags [args: list<string>] {
    mut translated = []
    mut idx = 0
    let total = ($args | length)

    while $idx < $total {
        let arg = ($args | get $idx)
        
        match $arg {
            # Output file mapping: -O file -> -o file
            "-O" => {
                if $idx + 1 < $total {
                    $translated = ($translated | append ["-o", ($args | get ($idx + 1))])
                    $idx += 2
                    continue
                }
            }
            # Continue download: -c -> -C -
            "-c" | "--continue" => {
                $translated = ($translated | append ["-C", "-"])
            }
            # Quiet/Silent mode: -q -> -s
            "-q" | "--quiet" => {
                $translated = ($translated | append "-s")
            }
            # Background execution: -b -> curl doesn't natively background, run silently
            "-b" | "--background" => {
                $translated = ($translated | append ["-s", "-O"])
            }
            # Ignore SSL certificates: --no-check-certificate -> -k
            "--no-check-certificate" => {
                $translated = ($translated | append "-k")
            }
            # Custom Headers: --header "X: Y" -> -H "X: Y"
            "--header" => {
                if $idx + 1 < $total {
                    $translated = ($translated | append ["-H", ($args | get ($idx + 1))])
                    $idx += 2
                    continue
                }
            }
            # User Agent string: -U string -> -A string
            "-U" | "--user-agent" => {
                if $idx + 1 < $total {
                    $translated = ($translated | append ["-A", ($args | get ($idx + 1))])
                    $idx += 2
                    continue
                }
            }
            # Timeout flags: Convert custom user timeouts to curl syntax on the fly
            "-T" | "--timeout" | "--connect-timeout" | "--read-timeout" => {
                if $idx + 1 < $total {
                    $translated = ($translated | append ["--max-time", ($args | get ($idx + 1))])
                    $idx += 2
                    continue
                }
            }
            # Pass everything else directly through
            _ => {
                $translated = ($translated | append $arg)
            }
        }
        $idx += 1
    }
    return $translated
}

# Sane file downloader: relies entirely on system binary fallbacks
def --wrapped wget [...rest: string] {
    if ($rest | length) == 1 and not ($rest.0 | str starts-with "-") {
        let clean_url = ($rest.0 | split row "?" | first)
        try { ^wget2 -T 30 -N $clean_url } catch {
            try { ^wget -T 30 -N $clean_url } catch {
                try { ^wcurl --curl-options "--connect-timeout 30 --max-time 30" $clean_url } catch {
                    ^curl --connect-timeout 30 --max-time 30 -L -O -J --retry 3 $clean_url
                }
            }
        }
    } else {
        try { ^wget2 ...$rest } catch {
            try { ^wget ...$rest } catch { 
                # Parse temporary flags out of the mutation engine
                let raw_translated = (translate-wget-flags $rest)
                
                # Assign to an immutable 'let' array so it is safe to capture in closures
                let curl_flags = if not ($raw_translated | any { |x| $x in ["--max-time", "-m", "--connect-timeout"] }) {
                    $raw_translated | prepend ["--connect-timeout", "30", "--max-time", "30"]
                } else {
                    $raw_translated
                }
                
                let wcurl_opt_str = ($curl_flags | str join " ")
                
                try { 
                    ^wcurl --curl-options $wcurl_opt_str
                } catch { 
                    try { ^curl ...$curl_flags } catch {
                        print $"(ansi red)Error: No compatible download engine found to execute flags.(ansi reset)"
                    }
                }
            }
        }
    }
}

# Advanced curl replacement: uses native Nushell HTTP data streams first
def --wrapped curl [...rest: string] {
    if ($rest | length) == 1 and not ($rest.0 | str starts-with "-") {
        let clean_url = ($rest.0 | split row "?" | first)
        try {
            http get --timeout 30sec $clean_url
        } catch {
            try {
                ^wcurl --curl-options "--connect-timeout 30 --max-time 30" $clean_url
            } catch {
                try {
                    ^curl --connect-timeout 30 --max-time 30 $clean_url
                } catch {
                    try { ^wget2 -T 30 -q -O - $clean_url } catch { ^wget -T 30 -q -O - $clean_url }
                }
            }
        }
    } else {
        # Establish timeouts inside an immutable binding before entering closures
        let curl_args = if not ($rest | any { |x| $x in ["--max-time", "-m", "--connect-timeout"] }) {
            $rest | prepend ["--connect-timeout", "30", "--max-time", "30"]
        } else {
            $rest
        }

        let wcurl_opt_str = ($curl_args | str join " ")

        try {
            ^wcurl --curl-options $wcurl_opt_str
        } catch {
            try { ^curl ...$curl_args } catch {
                print $"(ansi red)Error: System curl/wcurl binaries are missing and cannot execute flags.(ansi reset)"
            }
        }
    }
}
