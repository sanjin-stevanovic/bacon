#!/bin/sh

get_full_path() {
    path=$1
    if [ "$(echo "$path" | cut -c 1)" != "/" ]; then
        if [ "$(echo "$path" | cut -c -3)" = "../" ]; then
            cd ..
            dir_path=$(pwd -P)
            path="$dir_path${path#..}"
        elif [ "$(echo "$path" | cut -c -2)" = "./" ]; then
            dir_path=$(pwd -P)
            path="$dir_path${path#.}"
        else
            dir_path=$(pwd -P)
            path="$dir_path/${path}"
        fi
    fi
}

# set install direcory
install_dir=${1:-/opt}
get_full_path "$install_dir"
install_dir=${path%/}/bacon
# set link directory
link_dir=${2:-/usr/local/bin}
get_full_path "$link_dir"
link_dir=${path%/} 

# run as sudo for the permissions to /directory
sudo INSTALL_DIR="$install_dir" LINK_DIR="$link_dir" sh -c '
    mkdir -p "$INSTALL_DIR" && \
    cp -r ./src/* "$INSTALL_DIR" && \
    chmod +x "$INSTALL_DIR/bacon.sh" && \
    chmod +x "$INSTALL_DIR/modules/"* && \
    sed -i "8s|.*|modules_dir=\"$INSTALL_DIR/modules\"|" "$INSTALL_DIR/bacon.sh" || \
    echo "Failed to install bacon to $INSTALL_DIR" >&2; \
    rm -f "$LINK_DIR/bacon"; \
    ln -s "$INSTALL_DIR/bacon.sh" "$LINK_DIR/bacon" || \
    echo "failed to create link in $LINK_DIR" >&2 \
    '
    
