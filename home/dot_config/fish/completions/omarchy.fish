# Completion for the `omarchy` dispatcher, driven by its own command catalog
# (`omarchy commands --json`: route, args spec, summary). The catalog is cached
# to ~/.cache/fish/omarchy-commands.tsv and regenerated when the omarchy binary
# is newer than the cache (package update). Fish port of omarchy's
# default/bash/completions.

function __omarchy_catalog
    set -l bin (command -s omarchy); or return 1
    set -l cache ~/.cache/fish/omarchy-commands.tsv
    if not test -s $cache; or test $bin -nt $cache
        mkdir -p (dirname $cache)
        omarchy commands --json 2>/dev/null |
            jq -r '.commands[] | select(.hidden | not) | [.route, .args, .summary] | @tsv' >$cache 2>/dev/null
    end
    cat $cache
end

# Offer candidates from one `# omarchy:args=` spec. Alternatives are separated
# by " | "; each is a sequence of tokens. `[--flag]` and `[--flag <value>]`
# tokens are offered at any position and do not count as positionals; at the
# current positional slot, <a|b> / [a|b] expand to their choices and a bare
# word is offered literally. Placeholders like <path> offer nothing.
function __omarchy_complete_args --argument-names pos spec
    for alt in (string split ' | ' -- $spec)
        set -l i 0
        set -l in_flag_value 0
        for tok in (string split ' ' -- $alt)
            if test $in_flag_value -eq 1
                string match -q -- '*]' $tok; and set in_flag_value 0
                continue
            end
            set -l bare (string trim -c '[]<>' -- $tok | string replace -r '\.\.\.$' '')
            test -n "$bare"; or continue
            if string match -q -- '--*' $bare
                echo $bare
                # `[--reauth <account>]`: the value token(s) run to the closing bracket
                string match -q -- '*]' $tok; or set in_flag_value 1
                continue
            end
            set i (math $i + 1)
            if test $i -eq (math $pos + 1)
                if string match -q -- '*|*' $bare
                    string split '|' -- $bare
                else if not string match -qr '^[<\[]' -- $tok
                    echo $bare
                end
            end
        end
    end
end

function __omarchy_complete
    set -l typed (commandline -opc)
    set -e typed[1]
    # Route words are the non-flag words typed so far
    set -l route_words (string match -v -- '-*' $typed)
    set -l n (count $route_words)
    set -l seen
    set -l exact_rn 0
    set -l exact_args ''

    __omarchy_catalog | while read -l -d \t route args summary
        set -l rwords (string split ' ' -- $route)
        set -e rwords[1]
        set -l rn (count $rwords)

        if test $rn -gt $n
            # Route extends past what was typed: offer its next word
            if test $n -eq 0; or test "$rwords[1..$n]" = "$route_words"
                set -l next $rwords[(math $n + 1)]
                if test $rn -eq (math $n + 1)
                    printf '%s\t%s\n' $next $summary
                else if not contains -- $next $seen
                    set -a seen $next
                    printf '%s\tomarchy %s …\n' $next (string join ' ' $rwords[1..(math $n + 1)])
                end
            end
        else if test "$rwords" = "$route_words[1..$rn]"; and test $rn -gt $exact_rn
            # Fully typed command (longest match wins): remember its args spec
            set exact_rn $rn
            set exact_args $args
        end
    end

    if test $exact_rn -gt 0
        # Positional slot = non-flag words typed after the route
        __omarchy_complete_args (math $n - $exact_rn) $exact_args
    end
end

complete -c omarchy -f
complete -c omarchy -a '(__omarchy_complete)'
# Like bash's `-o default`: fall back to filenames when the catalog has no
# candidates for this position (e.g. a <path> placeholder).
complete -c omarchy -F -n 'test -z "$(__omarchy_complete)"'
complete -c omarchy -n __fish_use_subcommand -a commands -d 'List omarchy commands'
complete -c omarchy -n '__fish_seen_subcommand_from commands' -l all -l json -l markdown -l check
