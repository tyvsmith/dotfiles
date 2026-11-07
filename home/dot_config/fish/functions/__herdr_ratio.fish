function __herdr_ratio --description 'Echo a split ratio as a float: __herdr_ratio <numerator> <denominator>'
    math -s4 "$argv[1] / $argv[2]"
end
