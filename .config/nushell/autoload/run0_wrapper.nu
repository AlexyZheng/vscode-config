
#====================================================================
# sudo run0 alias
#====================================================================

# Core Wrapper: Intercepts 'sudo' and routes securely through run0
def --wrapped sudo [...args: string] {
    if ($args | is-empty) {
        # Open an interactive privileged root shell loading your styles using the detected binary
        ^run0 --empower --background="" --setenv=PATH $nu.current-exe --env-config $nu.env-path --config $nu.config-path
    } else {
        # Convert individual command arrays into a string payload
        let cmd_string = $args | str join " "

        # Execute via setsid inside a sub-dash process for seamless Ctrl+C handling
        ^run0 --empower --background="" --setenv=PATH setsid dash -c $"($cmd_string)"
    }
}




