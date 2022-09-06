setup() {
    load '/usr/lib/bats-support/load'
    load '/usr/lib/bats-assert/load'
}

setup_file() {

    # To test the remote module make sure the remote-ssh section is uncometed
    # and the placeholder information is replaced
    printf '  local-shell: bash
  #remote-ssh:
    #user: root
    #port: 21
    #domain: example.com
  shell-command:
    - mkdir /tmp/bacon_test
    - echo "Test File" > /tmp/bacon_test/shell_command.conf
  syslog-ng:
    path: /tmp/bacon_test
    version: 3.29
    include: scl.conf
    include: scl2.conf
    source:
      s-local:
        - internal
        - system
      s-network:
        - syslog: transport(tcp) port(6601) flags(no-parase)
        - syslog: transport(udp) port(5514) flags(no-parase)
      s-network-2:
        - syslog: transport(tcp) port(7665)
    destination:
      d-program:
        - program: "LOG_DESTINATION=/var/log/hotspot.log /config/scripts/format.sh" template($FULLDATE $MESSAGE\\n)
    filter:
      f-hotspot:
        - match: associated$ value(MESSAGE)
        - or-match: login failed value(MESSAGE)
        - or-match: Mikrotik-hs value(MESSAGE)
    log:
      l-log:
        - source: s_network
        - filter: f_hotspot
        - destination: d_program\n' \
            > ./test/test.yaml

    printf '##### THIS CONFIGURATE WAS MADE WITH BACON #####
@version: 3.29
@include: "scl.conf"
@include: "scl2.conf"
source s_local {
   internal();
   system();
};
source s_network {
   syslog(transport(tcp) port(6601) flags(no-parase));
   syslog(transport(udp) port(5514) flags(no-parase));
};
source s_network_2 {
   syslog(transport(tcp) port(7665));
};
destination d_program {
   program("LOG_DESTINATION=/var/log/hotspot.log /config/scripts/format.sh" template($FULLDATE $MESSAGE\\n));
};
filter f_hotspot {
   match(associated$ value(MESSAGE)) or match(login failed value(MESSAGE)) or match(Mikrotik-hs value(MESSAGE));
};
log l_log {
   source(s_network);
   filter(f_hotspot);
   destination(d_program);
};\n' \
    > ./test/expected_syslog_ng.conf

    echo 'Test File' > ./test/expected_shell_command.conf
}

teardown_file() {
    sudo rm -rf ./test/bacon
    sudo rm -f ~/.local/bin/bacon
    rm -rf $HOME/.cache/bacon/*
    rm -f ./test/test.yaml
    rm -f ./test/expected_syslog_ng.conf
    rm -f ./test/expected_shell_command.conf
    rm -f ./test/ssh_syslog_ng.conf
    rm -f ./test/ssh_shell_command.conf
    rm -rf /tmp/bacon_test
    #ssh -p 21 root@example.com 'rm -rf /tmp/bacon_test'
}

@test "test installation and that no errors occure on program run" {
    ./install.sh ./test ~/.local/bin

    run bacon ./test/test.yaml

    assert_output ''
}

@test "test syslog-ng module output locally" {
    run diff ./test/expected_syslog_ng.conf /tmp/bacon_test/syslog-ng.conf

    assert_output ''
}

@test "test shell-command module output locally" {
    run diff ./test/expected_shell_command.conf /tmp/bacon_test/shell_command.conf

    assert_output ''
}

@test "test syslog-ng module output remotely" {
    # will fail, replace the ssh information placeholders 
    skip
    
    ssh -p 21 root@example.com 'cat /tmp/bacon_test/syslog-ng.conf' > ./test/ssh_syslog_ng.conf
    
    run diff ./test/expected_syslog_ng.conf ./test/ssh_syslog_ng.conf
    
    assert_output ''
}

@test "test shell-command module output remotely" {
    # will fail, replace the ssh information placeholders 
    skip
    
    ssh -p 21 root@example.com 'cat /tmp/bacon_test/shell_command.conf' \
        > ./test/ssh_shell_command.conf
    
    run diff ./test/expected_shell_command.conf ./test/ssh_shell_command.conf
    
    assert_output ''
}
