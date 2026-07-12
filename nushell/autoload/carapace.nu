let carapace_completer = {|spans|
    carapace $spans.0 nushell ...$spans | from json
}

$env.CARAPACE_UNFILTERED = 1
$env.config = {
    # No custom 'menus' list needed — we configure the behavior here instead
    completions: {
        case_sensitive: false
        quick: false # Keeps the dropdown open so you can type-to-filter
        partial: true
        algorithm: "fuzzy" # Gives you the IDE-like smart filtering
        external: {enable: true, max_results: 100, completer: $carapace_completer}
    }
}
