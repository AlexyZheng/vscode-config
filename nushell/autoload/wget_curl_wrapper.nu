
# Smart Nushell replacement for wget using system curl for downloading
def --wrapped wget [...rest: string] {
    if ($rest | length) == 1 {
        let url = ($rest | first)
        # Strip query strings (like ?token=...) to extract a clean filename
        let clean_url = ($url | split row "?" | first)
        let filename = ($clean_url | path parse | get stem) + "." + ($clean_url | path parse | get extension)
        
        print $"[Nu Wrapper] Downloading to ($filename)..."
        # -L follows redirects, -o specifies output destination
        ^curl -L $url -o $filename
    } else {
        # Fall back to your system's actual wget command if extra flags are supplied
        ^wget ...$rest
    }
}

# Smart Nushell replacement for curl to execute plain URLs or arbitrary flags
def --wrapped curl [...rest: string] {
    # Transparently passes all text requests straight to the platform binary
    ^curl ...$rest
}
