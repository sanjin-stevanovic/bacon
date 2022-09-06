#!/bin/sh

IFS=$(printf '\n\t')
for variable_value in $(printf "$BACON_VARIABLE_LIST" ); do
    value=${variable_value##*=}
    value=${value#\"}
    value=${value%\"}
    
    echo "$value" >>  "$BACON_MODULE_OUTPUT_DIR/10_shell_command"
done
