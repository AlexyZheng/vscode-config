module reload_utility {
    # ── configuration reloader ───────────────────────────
    export def --env "reload nu" [] {
        let timestamp = (date now | format date "%H:%M:%S")
        print $"(ansi green)Config reloaded at ($timestamp)!(ansi reset)"
        
        # 1. CLEANUP PASS: Explicitly target and purge background temporary logs
        try {
            # FIX: Removed the non-existent '--all' flag to satisfy the compiler parser parameters
            let temp_frames = (glob /tmp/nu-bash-env*)
            
            for frame in $temp_frames {
                # Force delete permanently to prevent data filling your system trash
                ^rm --force $frame
            }
        } catch { }
        
        # 2. PROCESS REPLACEMENT: Blast straight through the virtual machine layers
        exec nu
    }
}

# Export the module context bindings explicitly
use reload_utility *
