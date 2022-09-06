#!/bin/sh

# go thru every variable value pair passed to script

variables_list=$(echo "$BACON_VARIABLE_LIST" | sed 's/\\n/ /g')

for variable_value in $variables_list; do
   
    # put into seperate variables
    variable=${variable_value%%=*}
    group=${variable%_*}
    value=${variable_value#*=}
    value=${value#\"}
    value=${value%\"}

    # if a new group is defiend output the previous group
    if [ "$previous_group" != "" ] && [ "$group" != "$previous_group" ] && [ "$group" != "$variable" ]; then
        for domain in $domains; do
            echo \
                "ssh -p ${port:-21} ${user:-root}@$domain ${shell:-bash} -s < %config-file%" \
                >> "$BACON_APPLY_FILE"
        done
        domains=""
        user=""
        port=""
        shell=""
    fi

    # assign the appropriate variable
    case "$variable" in
        *port)
            port="$value"
            ;;
        *user)
            user="$value"
            ;;
        *shell)
            shell="$value"
            ;;
        *domain)
            domains="$domains $value"
            ;;
    esac
    previous_group="$group"
done

# output the last group
for domain in $domains; do
    echo \
        "ssh -p ${port:-21} ${user:-root}@$domain ${shell:-bash} -s < %config-file%" \
        >> "$BACON_APPLY_FILE"
done

