#!/bin/sh

# directory where the modules are insalled
# should be replaced with an absolute path
# either manually or via the provided install.sh
# usally same directory as main script

modules_dir="$PWD/modules"

parse_yaml() {
    file="$1"
 
    # load the lines from file including whitespace characters
    while IFS=""; read -r line; do
        # remove all non space characters from the end
        # this leaves only spaces at the start of the line
        line_indent=${line%%[^ ]*}
        
        # remove the whitespaces from the start of the line
        # and from the endl of the line 
        line=${line#"$line_indent"}
        line=${line%"${line##*[^ ]}"}
        
        # skip empty lines and comments, lines that start with #
        if [ "$line" = "" ] || [ "$(echo "$line" | cut -c 1)" = "#" ]; then
            continue
        fi
       
        # get indent of line as number of whitespaces
        line_indent=${#line_indent}
         
        # remove inline comments, lines containing unquted #
        # and all the extra whitespace characters that are left
        comment=${line##*[\"\']}
        comment=${comment#*#}
        if [ "$comment" != "$line" ]; then
            line=${line%#"$comment"}
            comment=${line##*[^ ]}
            line=${line%"$comment"}
        fi
       
        # prefix defines the path from the root to the value
        # if there is no prefix set it
        if [ "$prefix" = "" ]; then
            prefix="${line%%:*}"
            prefix_indent="$line_indent"
        # if the current line is more indented then the previous 
        # it is added to the prefix, the previous prefix is its parent
        elif [ "$line_indent" -gt "${prefix_indent##*_BACON_DELIMITER_}" ] \
            && [ "${line#*:}" != "$line" ]; then
            line=${line#- }
            prefix="${prefix}_BACON_DELIMITER_${line%%:*}"
            prefix_indent="${prefix_indent}_BACON_DELIMITER_$line_indent"
        # if the current line is less indented than the previous
        # find out how far back to go to reach the variables parent
        # then add it to parent
        elif [ "$line_indent" -le "${prefix_indent##*_BACON_DELIMITER_}" ]; then
            temp=${prefix_indent##*"$line_indent"}
            temp=$(echo "$temp" | sed 's/^_BACON_DELIMITER_//g')
            temp=$(echo "$temp" | sed 's/_BACON_DELIMITER_/_/g')
            temp=${#temp}
                
            i=0; while [ "$i" -le "$temp" ]; do 
                prefix=${prefix%_BACON_DELIMITER_*}
                prefix_indent=${prefix_indent%_BACON_DELIMITER_*}
            i=$((i+1)); done
            
            # root variable needs to change
            if [ "$line_indent" -le "${prefix_indent##*_BACON_DELIMITER_}" ]; then                
                module=${prefix%%_BACON_DELIMITER_*}
                send_to_module "$module" "$variables_list"
                variables_list=""
                
                prefix="${line%%:*}"
                prefix_indent="$line_indent"
            # if line doesnt start with "-"
            # add variable to prefix
            elif [ "${line#*:}" != "$line" ]; then
                line=${line#- }
                prefix="${prefix}_BACON_DELIMITER_${line%%:*}"
                prefix_indent="${prefix_indent}_BACON_DELIMITER_$line_indent"
            fi
        fi
       
        # set the value of the variable
        # supports three ways of setting varaible values
        # 1ST variable: value
        # 2ND variable:
        #       - value1
        #       - value2
        # 3RD variable: [ value1, value2 ]
        
        # 1ST & 3RD way
        # the current line defiens both variable name and its value
        if [ "${line#*:}" != "" ] && [ "${line#*:}" != "$line" ]; then
            value="${line#*:}"
            temp=${value%%[^ ]*}
            value=${value#"$temp"}
           
            # 3RD way
            # the line defines multiple values for one varaible, an array
            if echo "${line#*:}" | grep -q '^*[\[\]*$'; then
                value=${value#[* }
                value=${value% *]}
                temp=$(echo "$value" | sed 's/[^,]//g')
                temp=${#temp}
               
                i=0; while [ "$i" -le "$temp" ]; do 
                    single_value=${value%%,*}
                    value=${value#"$single_value",* }
                    
                    variable=${prefix#*_BACON_DELIMITER_}
                    
                    single_value=$(echo "$single_value" | sed 's/\\n/\\\\n/g')
                    single_value=$(echo "$single_value" | sed 's/\"/\\\"/g')
                    variable=$(echo "$variable" | sed 's/_BACON_DELIMITER_/_/g')
                    variables_list="${variables_list}$variable=\"$single_value\"\n"
                i=$((i+1)); done
            # 1ST way
            # the line defines a single value for variable
            else
                variable=${prefix#*_BACON_DELIMITER_}
               
                value=$(echo "$value" | sed 's/\\n/\\\\n/g')
                value=$(echo "$value" | sed 's/\"/\\\"/g')
                variable=$(echo "$variable" | sed 's/_BACON_DELIMITER_/_/g')
                variables_list="${variables_list}$variable=\"$value\"\n"
            fi
        # 2ND way
        # the current line  is a value for a already defined variable 
        elif [ "$(echo "$line" | cut -c 1)" = "-" ]; then
            value="${line#*- }"     
            
            variable=${prefix#*_BACON_DELIMITER_}
            value=$(echo "$value" | sed 's/\\n/\\\\n/g')
            value=$(echo "$value" | sed 's/\"/\\\"/g')
            variable=$(echo "$variable" | sed 's/_BACON_DELIMITER_/_/g')
            variables_list="${variables_list}$variable=\"$value\"\n"
        fi
        
    done < "$file"
        
    module=${prefix%%_BACON_DELIMITER_*}
    send_to_module "$module" "$variables_list"

}

# send list of varibles to the module
send_to_module() {
    module="$1"
    variables_list="$2"
   
    # get the executible of the module
    module_run=$(ls "$modules_dir/$module"* 2>/dev/null)
   
    # if the executible exists run it with the variables
    if [ "$module_run" != "" ]; then
        BACON_MODULE_OUTPUT_DIR=$module_output_dir/latest \
        BACON_APPLY_FILE=$apply_file \
        BACON_VARIABLE_LIST="$variables_list" \
        "$module_run"
    else
        echo "bacon: skipping $module section: Module is not installed" >&2
    fi
}

# create configuration file using the module output
create_configuration() {
    # get list of all outputs from modules
    if [ "$revert" = "true" ]; then
        apply_path="$module_output_dir/previous"
        compare_path="$module_output_dir/latest"
    else
        apply_path="$module_output_dir/latest"
        compare_path="$module_output_dir/previous"
    fi

    # module outputs can be prefixed with a number indicating their priority
    # making sure some modules are configured before others
    # if the module output did not change since the previous configuration
    # no need to apply it again
    for file_path in "$apply_path"/*; do
        updated=true
        if [ -f "$compare_path"/"${file_path##*/}" ]; then
            updated=$(diff "$file_path" "$compare_path/${file_path##*/}")
        fi
        
        if [ "$updated" != "" ]; then
            cat "$file_path" >> "$configuration_file" 2>/dev/null \
                || echo "bacon: cannot create config file: No module output was found" >&2
        fi
    done
}

# apply the configuration file as defined int the apply file
# or if the --print option is used print out the file to stdout
apply_configuration() {
   
    if [ "$print" = "true" ]; then
        echo "########## Config File ##########"
        cat "$configuration_file" 2>/dev/null || echo "NO CONFIG FILE CREATED"
        
        printf "\n########## Apply File ##########\n"
        cat "$apply_file" 2>/dev/null || echo "NO APPLY FILE CREATED"
    elif [ -f "$apply_file" ]; then
        while read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | sed  "s|\%config-file\%|$configuration_file|g")
            eval "($line) 2>/dev/null"
        done < "$apply_file"
    fi
}

# get path provided
# and resolve relative paths with ./ or ../
get_path() {
    yaml_file="$*"

    while true ; do
        if [ "$(echo "$yaml_file" | cut -c 1)" = "-" ]; then
            yaml_file=${yaml_file#-* }
        elif [ "${yaml_file##*.}" != "yaml" ] && [ "${yaml_file##*.}" != "yml" ]; then
            yaml_file=${yaml_file% *-*}
        else
            break
        fi
    done

    if [ "$(echo "$yaml_file" | cut -c 1)" != "/" ]; then
        if [ "$(echo "$yaml_file" | cut -c -3)" = "../" ]; then
            cd ..
            path=$(pwd -P)
            yaml_file="$path${yaml_file#..}"
        elif [ "$(echo "$yaml_file" | cut -c -2)" = "./" ]; then
            path=$(pwd -P)
            yaml_file="$path${yaml_file#.}"
        else
            path=$(pwd -P)
            yaml_file="$path/${yaml_file}"
        fi
    fi

}

# help menu
list_options() {
    printf "Usage bacon <options> <path to .yaml|.yml file>\n\
    -h, --help       Show this help text\n\
    -P, --print      Show the configuration file and apply file, do not execute them\n\
    -R, --revert     Undo the most recent configuration\n"
}

if echo "$*" | grep -q '^.*--help.*$' || echo "$*" | grep -q '^.*-h.*$'; then
    list_options
    exit
fi 

if echo "$*" | grep -q '^.*--revert.*$' || echo "$*" | grep -q '^.*-R.*$'; then
    revert=true
fi

if echo "$*" | grep -q '^.*--print.*$' || echo "$*" | grep -q '^.*-P.*$'; then
    print=true
fi

if echo "$*" | grep -q '^.*-.*[^\.yaml] .*$' || echo "$*" | grep -q '^.*-.*[^\.yaml]$' && \
    [ "$revert" != "true" ] && [ "$print" != "true" ]; then
    echo "bacon: Unrecognized option use --help for more information"
    exit
elif echo "$*" | grep -q '^.*-.*[^\.yml] .*$' || echo "$*" | grep -q '^.*-.*[^\.yml]$' && \
    [ "$revert" != "true" ] && [ "$print" != "true" ]; then
    echo "bacon: Unrecognized option use --help for more information"
    exit
fi

# set cache directory
# freedesktop.org secifications
if [ -d "$XDG_CACHE_HOME" ]; then
    cache_dir=$XDG_CACHE_HOME/bacon
else
    cache_dir=$HOME/.cache/bacon
fi

module_output_dir=$cache_dir/modules
apply_file=$cache_dir/apply
configuration_file=$cache_dir/config

if echo "$*" | grep -q '^.*\.yaml.*$' || echo "$*" | grep -q '^.*\.yml.*$'; then

    get_path "$@"
    
    # if there is no configuration file exit
    if [ ! -f "$yaml_file" ]; then
        echo "bacon: file not found: $yaml_file" >&2
        exit
    fi
       
    # save old configuration before creating new one
    if [ "$revert" != "true" ]; then
        rm -rf "$module_output_dir/previous" 2>/dev/null
        mv "$module_output_dir/latest" "$module_output_dir/previous" 2>/dev/null
        
    elif [ ! -d "$module_output_dir/previous" ]; \
    then 
        echo "bacon: cannot revert: No previous configuration" >&2
        exit
    fi
    
    # create dir for latest configuration
    mkdir -p "$module_output_dir/latest"
    
    # parse the yaml file create the config file and apply it
    parse_yaml "$yaml_file"
    create_configuration
    apply_configuration
    
    # remove the configuration_file & apply_file list
    # they are generated everytime
    rm "$apply_file" 2>/dev/null
    rm "$configuration_file" 2>/dev/null
else
    echo "bacon: Unrecognized option use --help for more information"
fi
