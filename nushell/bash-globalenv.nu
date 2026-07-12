# ── interactive prompt helpers ─────────────────────
def bash_prompt [] {
    let user = $env.USER? | default "user"
    let host = $nu.os-info.hostname? | default "bash"
    let raw_pwd = $env.PWD
    let home = $env.HOME? | default ""

    let current_dir = if $home != "" and $raw_pwd == $home {
        "~"
    } else if $home != "" and ($raw_pwd | str starts-with $home) {
        $raw_pwd | str replace $home "~"
    } else {
        $raw_pwd | path basename
    }

    $"[($user)@($host) ($current_dir)]$ "
}

def bash_has_line_continuation [code: string] {
    let last_line = (
        $code
        | lines
        | last
        | default ""
        | str trim --right
    )
    $last_line | str ends-with '\'
}

def bash_needs_more [code: string] {
    if (bash_has_line_continuation $code) { return true }

    let check = (with-env { LANG: "C", LC_ALL: "C", LC_MESSAGES: "C" } {
        ^bash -n -c $code | complete
    })
    let stderr = $check.stderr | default ""

    if $check.exit_code == 0 {
        return (
            ($stderr | str contains "here-document") and
            ($stderr | str contains "delimited by end-of-file")
        )
    }

    let incomplete_markers = [
        "unexpected EOF"
        "unexpected end of file"
        "syntax error: unexpected end of file"
        "looking for matching"
    ]
    $incomplete_markers | any {|marker| $stderr | str contains $marker }
}

# ── environment diff helpers ───────────────────────
def _bash_env_lines_to_record [] {
    let raw_string = $in
    if ($raw_string == null) or (($raw_string | str trim) == "") {
        {}
    } else {
        mut env_record = {}
        let split_lines = ($raw_string | split row "\n")
        for line in $split_lines {
            let clean = ($line | str trim)
            if $clean != "" and ($clean | str contains "=") {
                let parts = ($clean | split row -n 2 "=")
                let name = ($parts | get -o 0 | default "")
                let value = ($parts | get -o 1 | default "")
                if $name != "" {
                    $env_record = ($env_record | upsert $name $value)
                }
            }
        }
        $env_record
    }
}

def _bash_env_convert_value [name: string, value: string] {
    let conv = (try { $env.ENV_CONVERSIONS | get -o $name } catch { null })
    if $conv != null {
        try { do $conv.from_string $value } catch {
            if $name in ["PATH", "Path"] { $value | split row (char esep) } else { $value }
        }
    } else if $name in ["PATH", "Path"] { $value | split row (char esep) } else { $value }
}

def _bash_env_changed_record [before: record] {
    let trans = (transpose name value)
    if ($trans | is-empty) {
        {}
    } else {
        mut changes = {}
        for row in $trans {
            let old = ($before | get -o $row.name)
            if $old != $row.value {
                let value = (_bash_env_convert_value $row.name $row.value)
                $changes = ($changes | upsert $row.name $value)
            }
        }
        $changes
    }
}

# ── history helper ─────────────────────────────────
def _bash_append_to_history [command: string] {
    $command | history import | null
    try {
        let target_dir = ($nu.config-path | path dirname)
        let files_list = (try { ls $target_dir } catch { [] })
        
        for file in $files_list {
            if ($file.name =~ "history.sqlite3.bak") {
                try { rm $file.name } catch { }
            }
        }
    } catch { }
}

# ── main portal execution command ───────────────────
def --env bash_portal [
    code_or_file?: string,          # optional: command or script path
    --raw(-r),                      # Switch flag to completely force plain text
    --format(-f): string = "guess"  # Default to smart automated data structures
] {
    let code = if $code_or_file != null {
        let expanded = ($code_or_file | path expand)
        if ($expanded | path exists) {
            $". '($expanded)'"
        } else {
            $code_or_file
        }
    } else {
        mut lines = []
        loop {
            let prompt = if ($lines | is-empty) {
                bash_prompt
            } else {
                "bash> "
            }

            let line = try {
                input --reedline $prompt
            } catch {
                return
            }

            $lines = ($lines | append $line)
            let current_code = $lines | str join "\n"

            if not (bash_needs_more $current_code) {
                break
            }
        }
        $lines | str join "\n"
    }

    _bash_append_to_history $code

    let before_path = (mktemp)
    let after_path  = (mktemp)

    let raw_output = try {
        let exec = (
            ^bash -c 'env > "$1"; eval "$3"; env > "$2"' nu-bash-env $before_path $after_path $code
            | complete
        )

        if ($exec.stderr | str trim) != "" {
            let clean_error = ($exec.stderr | str replace --all "nu-bash-env" "bash")
            print -e $clean_error
        }

        let before = (open --raw $before_path | _bash_env_lines_to_record)
        let after  = (open --raw $after_path  | _bash_env_lines_to_record)
        let changes = $after | _bash_env_changed_record $before

        load-env $changes
        $exec.stdout
    } catch { null }

    try { rm $before_path $after_path } catch { }

    if $raw_output == null or ($raw_output | str trim) == "" { return }

    if $raw { return $raw_output }

    let target_format = if $format == "guess" {
        let trimmed = ($raw_output | str trim)
        if ($trimmed | str starts-with "{") or ($trimmed | str starts-with "[") {
            "json"
        } else if ($trimmed | lines | first | str contains ",") {
            "csv"
        } else if ($trimmed | lines | length) > 1 {
            "columns"
        } else {
            "raw"
        }
    } else {
        $format | str downcase
    }

    if $target_format == "raw" {
        $raw_output
    } else if $target_format == "columns" {
        $raw_output | detect columns --guess
    } else {
        try { 
            $raw_output | nu -c $"$in \| from ($target_format)" 
        } catch { 
            $raw_output 
        }
    }
}
