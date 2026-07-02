# Sane file downloader: relies entirely on system binary fallbacks
def --wrapped wget [...rest: string] {
    if ($rest | length) == 1 and not ($rest.0 | str starts-with "-") {
        let clean_url = ($rest.0 | split row "?" | first)
        try { ^wget2 -N $clean_url } catch {
            try { ^wget -N $clean_url } catch {
                ^curl -L -O -J --retry 3 $clean_url
            }
        }
    } else {
        try { ^wget2 ...$rest } catch {
            try { ^wget ...$rest } catch { ^curl ...$rest }
        }
    }
}

# Advanced curl replacement: uses native Nushell HTTP data streams first, 
# and drops back to system binaries if plugins or dependencies are missing.
def --wrapped curl [...rest: string] {
    if ($rest | length) == 1 and not ($rest.0 | str starts-with "-") {
        let clean_url = ($rest.0 | split row "?" | first)
        
        # Priority 1: Try native Nushell HTTP processing for clean tables
        try {
            http get $clean_url
        } catch {
            # Priority 2: Fallback to system curl if native http command is missing
            try {
                ^curl $clean_url
            } catch {
                # Priority 3: Fallback to silent wget output stream if curl is missing
                try { ^wget2 -q -O - $clean_url } catch { ^wget -q -O - $clean_url }
            }
        }
    } else {
        # If manual flags are typed (-H, -X), bypass native engines and run raw curl
        try { ^curl ...$rest } catch {
            print $"(ansi red)Error: System curl binary is missing and cannot execute flags.(ansi reset)"
        }
    }
}
