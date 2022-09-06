#!/bin/bash

function create_config {
    local select="$1"
    IFS=$'\n'
    for variable_value in $(printf "$BACON_VARIABLE_LIST" ); do

        local variable=${variable_value%%=*}
        local value=${variable_value#*=}
        value=${value#\"}
        value=${value%\"}
        
        value=${value//\"/\\\"}
        value=${value//\\n/\\\\\\n}
        value=${value//\$/\\\$}
        
        case ${variable%%_*} in
            path)
                path="$value"
                continue
                ;;
            version)
                if [[  "$section_old" == "version" || "$section_old" == "include" \
                    || "$section_old" == "" ]]; then
                    output="${output}@version: $value\n"
                else
                    output="${output}};\n@version: $value\n"
                fi
                ;;
            include)
                if [[  "$section_old" == "version" || "$section_old" == "include" \
                    || "$section_old" == "" ]]; then
                    output="${output}@include: \\\"$value\\\"\n"
                else
                    output="${output}\};\n@include: \\\"$value\\\"\n"
                fi
                ;;
            *)
                local section_name=${variable#*_}
                section_name=${section_name%%_*}
                section_name=${section_name//-/_}
                if [[ "$section_name" != "$section_name_old" ]]; then
                    if [[ "$section_old" == "version" || "$section_old" == "include" \
                        || "$section_old" == "" ]]; then
                        output="${output}${variable%%_*} $section_name {\n"
                    else
                        output="${output}};\n${variable%%_*} $section_name {\n"
                    fi
                fi
                if [[ "${variable##*_}" == "${section_name//_/-}" ]]; then 
                    output="${output}   $value();\n"
                elif [[ "${variable##*_}" == *"-"* ]]; then
                    local logic_variable="${variable##*_}"
                    logic_variable=${logic_variable//-/ }
                    output="${output%);*}) ${logic_variable}($value);\n"
                else
                    output="${output}   ${variable##*_}($value);\n"
                fi
                ;;
        esac
     
    section_old="${variable%%_*}"
    section_name_old="$section_name"
    done
    
    if [[ "$section_old" != "version" && "$section_old" != "include" \
        && "$section_old" != "" ]]; then
        output="${output}};\n"
    fi
}

output="##### THIS CONFIGURATE WAS MADE WITH BACON #####\n"
create_config

if [[ "${path:(-1)}" == "/" ]]; then
    path=${path%/*}
fi

printf "\
if [[ -f \"$path\" ]]; then\n\
    BACON_SYSLOG_NG_CONFIG_FILE=\"$path\"\n\
elif [[ -d \"$path\" ]]; then\n\
    BACON_SYSLOG_NG_CONFIG_FILE=\"${path}/syslog-ng.conf\"\n\
fi\n\
\n\
if [[ \"\$BACON_SYSLOG_NG_CONFIG_FILE\" != \"\" ]]; then\n\
    printf \"%s\" > \"\$BACON_SYSLOG_NG_CONFIG_FILE\"\n\
else\n\
    echo \"ERROR: No config output for module (syslog-ng)\" >/dev/stderr\n\
fi\n\
" "$output" > $BACON_MODULE_OUTPUT_DIR/10_syslog_ng
