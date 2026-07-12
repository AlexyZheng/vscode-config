# Display comprehensive local system metrics and host firmware info
export def sysinfo [] {
    # 1. Fetch host metrics natively from the updated 0.113+ data records
    let host = sys host
    let bios_path = "/sys/class/dmi/id/bios_version"

    # 2. Extract BIOS info safely using a flat path check
    let bios = if ($bios_path | path exists) { open $bios_path | str trim } else { null }

    # 3. Handle Uptime cleanly from modern Duration metrics (formatting to string safely)
    let uptime_str = if $host.uptime != null { ($host.uptime | into string) } else { null }

    # 4. Format metrics into an explicit record object immediately
    let raw_record = {
        hostname: $host.name,
        bios_version: $bios,
        kernel_version: $host.kernel_version,
        os_version: $host.os_version,
        uptime: $uptime_str
    }

    # 5. Filter out null/empty entries using modern record iteration paths
    let filtered = (
        $raw_record 
        | transpose k v 

        | where {|row| ($row.v | is-not-empty) and ($row.v != "") }
        | transpose --header-row --as-record
    )

    # 6. Extract specific keys safely using direct metadata checks
    let has_uptime = ("uptime" in ($filtered | columns))

    # 7. Execute clean print sweeps using modern version formatting
    if $has_uptime {
        print ($filtered | reject uptime)
        print $"  uptime: ($filtered.uptime)"
    } else {
        print $filtered
    }
}
