# Sane, 100% self-contained wget replacement utilizing native curl behaviors
def --wrapped wget [...rest: string] {
    # Case 1: Standard single-link paste (Strip token query strings and download)
    if ($rest | length) == 1 and not ($rest.0 | str starts-with "-") {
        let url = ($rest | first)
        let clean_url = ($url | split row "?" | first)
        print $"[Smart-Download] Stripping tokens and pulling asset..."
        
        # Flags parsed directly to curl:
        # -L follows redirects. -O maps server filename. -J preserves header names.
        # --retry 3 safeguards against erratic server drops.
        ^curl -L -O -J --retry 3 $clean_url

    # Case 2: Multi-parameter script configurations (Intercept custom output files)
    } else if ($rest | length) > 1 {
        let has_short_out = ($rest | any {|x| $x == "-O"})
        let has_long_out = ($rest | any {|x| $x | str starts-with "--output-document=" or $x | str starts-with "--output-file="})

        if $has_short_out or $has_long_out {
            let url = ($rest | last)
            let clean_url = ($url | split row "?" | first)
            
            # Safe extraction of intended destination target filename
            let filename = if $has_short_out {
                let o_index = ($rest | enumerate | where item == "-O" | first | get index)
                let val_index = ($o_index + 1)
                # Safeguard: if -O was the last parameter, fallback to the URL's filename
                if $val_index < ($rest | length) { $rest | get $val_index } else { $clean_url | path parse | get stem }
            } else {
                $rest | filter {|x| $x | str starts-with "--output-document=" or $x | str starts-with "--output-file="} | first | split row "=" | last
            }

            print $"[Smart-Translate] Redirecting flag payload to destination: ($filename)"
            ^curl -L --retry 3 $clean_url -o $filename
        } else {
            # Case 3: Pass standard flags (-q, -c) directly out to curl binary execution
            ^curl ...$rest
        }
    } else {
        ^curl ...$rest
    }
}

# Clean curl wrapper stripping parameters strictly on unflagged, direct tracking URLs
def --wrapped curl [...rest: string] {
    if ($rest | length) == 1 and not ($rest.0 | str starts-with "-") {
        let url = ($rest | first)
        let clean_url = ($url | split row "?" | first)
        ^curl $clean_url
    } else {
        ^curl ...$rest
    }
}
