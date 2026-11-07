function __herdr_split --description 'Split a herdr pane and echo the new pane id: __herdr_split <pane_id> <right|down> <ratio> <cwd>'
    herdr pane split $argv[1] --direction $argv[2] --ratio $argv[3] --cwd $argv[4] --no-focus |
        jq -r '.result.pane.pane_id'
end
