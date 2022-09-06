setup() {
    load '/usr/lib/bats-support/load'
    load '/usr/lib/bats-assert/load'
    cd ./src
}

teardown() {
    rm -f ./modules/test-module.sh
    rm -rf $HOME/.cache/bacon/*
    rm -f ../test/test.yaml
}

@test "test the local-shell module" { 
    echo 'echo "readlink /proc/\$\$/exe" > "$BACON_MODULE_OUTPUT_DIR/00_test"' \
    > ./modules/test-module.sh && chmod +x ./modules/test-module.sh
    
    printf "test-module:\nlocal-shell: zsh\n" > ../test/test.yaml

    run ./bacon.sh ../test/test.yaml

    assert_output '/usr/bin/zsh'
    
    rm -rf $HOME/.cache/bacon/*
    printf "test-module:\nlocal-shell: bash\n" > ../test/test.yaml
    
    run ./bacon.sh ../test/test.yaml

    assert_output '/usr/bin/bash'

}

@test "test the remote-ssh module with a remote server" {
    # will fail, replace the ssh information placeholders 
    skip
    echo 'echo "hostname" > "$BACON_MODULE_OUTPUT_DIR/00_test"' \
    > ./modules/test-module.sh && chmod +x ./modules/test-module.sh
    
    printf "test-module:\nremote-ssh:\n   user: root\n   port: 21\n   domain: example.com\n" \
        > ../test/test.yaml

    run ./bacon.sh ../test/test.yaml

    assert_output 'Debrah'
}

@test "test the rmote-ssh module by inspecting the apply file" {
    printf 'remote-ssh:
    group-1:
      user: ug1
      port: 32
      domain: 
        - test.com
        - example.net
        - domain.org
    group-2:
      domain:
        - g2.com
        - mydomain.net
    group-3:
      user: ug3
      shell: zsh
      domain: hello.world\n' \
        > ../test/test.yaml

    run ./bacon.sh ../test/test.yaml --print

    assert_line --index 3 'ssh -p 32 ug1@test.com bash -s < %config-file%'
    assert_line --index 4 'ssh -p 32 ug1@example.net bash -s < %config-file%'
    assert_line --index 5 'ssh -p 32 ug1@domain.org bash -s < %config-file%'
    assert_line --index 6 'ssh -p 21 root@g2.com bash -s < %config-file%'
    assert_line --index 7 'ssh -p 21 root@mydomain.net bash -s < %config-file%'
    assert_line --index 8 'ssh -p 21 ug3@hello.world zsh -s < %config-file%'
}

@test "test the shell-command module" {
    echo 'echo "bash %config-file%" > "$BACON_APPLY_FILE"' \
    > ./modules/test-module.sh && chmod +x ./modules/test-module.sh

    printf "test-module:\nshell-command:\n\
      - echo \"hello world\"\n\
      - echo \"\$SHELL\"\n" \
      > ../test/test.yaml

    run ./bacon.sh ../test/test.yaml

    assert_line --index 0 'hello world'
    assert_line --index 1 '/usr/bin/zsh'
}
