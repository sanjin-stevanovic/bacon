#!/bin/sh

shell=${BACON_VARIABLE_LIST##*=\"}
shell=${shell%\"*}

echo "${shell:-bash} %config-file%" >> "$BACON_APPLY_FILE"
