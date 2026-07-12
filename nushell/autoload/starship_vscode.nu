# Force Starship execution to loop over VS Code's closure mapping
$env.config = ($env.config? | default {} | merge {
    hooks: {
        pre_prompt: [{ ||
            # This triggers right before the prompt draws, neutralizing VS Code's override loop
            $env.PROMPT_COMMAND = { || 
                starship prompt --cmd-duration $env.CMD_DURATION_MS $"--status=($env.LAST_EXIT_CODE)" 
            }
        }]
    }
})


$env.PROMPT_COMMAND = { || 
    # Grab the variable directly from the current shell's memory
    let mode = ($env.ACTIVE_SHELL? | default "nu")
    
    # We use STARSHIP_SESSION_KEY or a similar existing env var 
    # to pass the state into the Starship process
    with-env { SHANNON_MODE: $mode } {
        starship prompt --cmd-duration $env.CMD_DURATION_MS $"--status=($env.LAST_EXIT_CODE)" 
    }
}

# 4. Strip secondary indicators to prevent layout conflicts
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ""
$env.PROMPT_INDICATOR_VI_NORMAL = ""
$env.PROMPT_MULTILINE_INDICATOR = "::: "
