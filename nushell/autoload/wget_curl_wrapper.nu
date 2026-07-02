# Lean downloader: runs wget first, falls back to curl if wget is missing
def --wrapped wget [...rest: string] {
    if ($rest | length) == 1 and not ($rest.0 | str starts-with "-") {
        let clean_url = ($rest.0 | split row "?" | first)
        try {
            print $"[wget] Downloading..."
            ^wget -N $clean_url
        } catch {
            print $"[curl] wget missing, falling back to curl..."
            ^curl -L -O -J --retry 3 $clean_url
        }
    } else {
        try { ^wget ...$rest } catch { ^curl ...$rest }
    }
}

# Clean parameter-stripping curl
def --wrapped curl [...rest: string] {
    if ($rest | length) == 1 and not ($rest.0 | str starts-with "-") {
        let clean_url = ($rest.0 | split row "?" | first)
        ^curl $clean_url
    } else {
        ^curl ...$rest
    }
}
