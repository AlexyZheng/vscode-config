def --env cd [...args: string] {
    let raw_input = ($args | str join " ")
    if $raw_input == "" {
        # Added ctrl-x:abort to the FZF bind string
        let target = (with-env { 
            FZF_DEFAULT_OPTS: ($env | get -o FZF_DEFAULT_OPTS | default "" | append " --bind=ctrl-c:ignore,esc:abort,ctrl-x:abort" | str join " ")
        } {
            zoxide query --interactive
        })
        if $target != "" { %cd $target }
    } else if ($raw_input | path exists) or $raw_input == "~" or $raw_input == "-" {
        %cd $raw_input
    } else {
        let target = (zoxide query $raw_input | str trim)
        if $target != "" { %cd $target }
    }
}