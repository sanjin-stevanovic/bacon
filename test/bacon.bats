setup() {
    load '/usr/lib/bats-support/load'
    load '/usr/lib/bats-assert/load'
    printf "test-module:\n  - variable-1: TEST VARIABLE\n" > ./test/test.yaml
    cd ./src
}

teardown() {
    rm -f ./modules/test-module.sh
    rm -rf $HOME/.cache/bacon
    rm -f ./test/test.yaml
}

@test "use shellcheck to verify POSIX compatibility" {
    run shellcheck ./bacon.sh
    
    assert_output ''
}

@test "run bacon with option: --help" {
    run ./bacon.sh --help
 
    assert_line --index 0 'Usage bacon <options> <path to .yaml|.yml file>'
    assert_line --index 1 '    -h, --help       Show this help text'
    assert_line --index 2 \
        '    -P, --print      Show the configuration file and apply file, do not execute them'
    assert_line --index 3 '    -R, --revert     Undo the most recent configuration'
}

@test "run with unsuported option" {
    run ./bacon.sh --create-config ../test/test.yaml
    
    assert_output 'bacon: Unrecognized option use --help for more information'
}

@test "run with non-yaml file" { 
    run ./bacon.sh ../test/test_yaml_files/non-existant.config
    
    assert_output 'bacon: Unrecognized option use --help for more information'
}

@test "run with supported option but without specifying a yaml file" {
    run ./bacon.sh --print

    assert_output 'bacon: Unrecognized option use --help for more information'

    run ./bacon.sh -P --revert
    
    assert_output 'bacon: Unrecognized option use --help for more information'
}

@test "run with non-existant file" {
    run ./bacon.sh ./non-existant.yaml
    
    assert_output --regexp 'bacon: file not found: .*/non-existant.yaml'
}

@test "test for error message when module is not installed" {
    run ./bacon.sh ../test/test.yaml
    
    assert_line --index 0 'bacon: skipping test-module section: Module is not installed'
}

@test "use a mock module to verfy the correct module is exectuded" {
    echo 'echo "Hello From Test Module"' \
        > ./modules/test-module.sh && chmod +x ./modules/test-module.sh
    
    run ./bacon.sh ../test/test.yaml
    
    assert_line --index 0 'Hello From Test Module'
}

@test "use a mock module to verfy the correct environmetal variables are passed" {
    echo 'echo "$BACON_VARIABLE_LIST"; echo "$BACON_APPLY_FILE"; echo "$BACON_MODULE_OUTPUT_DIR"' \
        > ./modules/test-module.sh && chmod +x ./modules/test-module.sh
    
    run ./bacon.sh ../test/test.yaml

    assert_line --index 0 'variable-1="TEST VARIABLE"\n'
    assert_line --index 1 "$HOME/.cache/bacon/apply"
    assert_line --index 2 "$HOME/.cache/bacon/modules/latest"
}

@test "use a mock module to test error for no module output" {
    echo 'true' > ./modules/test-module.sh && chmod +x ./modules/test-module.sh
    
    run ./bacon.sh ../test/test.yaml
    
    assert_output 'bacon: cannot create config file: No module output was found'
}

@test "use a mock modules that module is ignored if no changes were made" {
    echo 'echo "echo HELLO FROM CONFIG FILE" > "$BACON_MODULE_OUTPUT_DIR/00_test" && \
        echo "bash %config-file%" > "$BACON_APPLY_FILE"' \
        > ./modules/test-module.sh && chmod +x ./modules/test-module.sh

    run ./bacon.sh ../test/test.yaml
    run ./bacon.sh ../test/test.yaml

    assert_output ''
}

@test "use mock module to test the --print option" {
    echo 'echo "echo HELLO FROM CONFIG FILE" > "$BACON_MODULE_OUTPUT_DIR/00_test" && \
        echo "bash %config-file%" > "$BACON_APPLY_FILE"' \
        > ./modules/test-module.sh && chmod +x ./modules/test-module.sh
    
    run ./bacon.sh --print ../test/test.yaml

    assert_line --index 0 '########## Config File ##########'
    assert_line --index 1 'echo HELLO FROM CONFIG FILE'
    assert_line --index 2 '########## Apply File ##########'
    assert_line --index 3 'bash %config-file%'

}

@test "use mock module to test the --revert option" {
    echo 'echo "echo HELLO FROM CONFIG FILE VERSION 1" > "$BACON_MODULE_OUTPUT_DIR/00_test" && \
        echo "bash %config-file%" > "$BACON_APPLY_FILE"' \
        > ./modules/test-module.sh && chmod +x ./modules/test-module.sh
    
    run ./bacon.sh ../test/test.yaml
    
    assert_output 'HELLO FROM CONFIG FILE VERSION 1'

    echo 'echo "echo HELLO FROM CONFIG FILE VERSION 2" > "$BACON_MODULE_OUTPUT_DIR/00_test" && \
        echo "bash %config-file%" > "$BACON_APPLY_FILE"' \
        > ./modules/test-module.sh && chmod +x ./modules/test-module.sh

    run ./bacon.sh ../test/test.yaml
    
    assert_output 'HELLO FROM CONFIG FILE VERSION 2'

    run ./bacon.sh --revert ../test/test.yaml

    assert_output 'HELLO FROM CONFIG FILE VERSION 1'
}
