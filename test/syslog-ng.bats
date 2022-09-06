setup() {
    load '/usr/lib/bats-support/load'
    load '/usr/lib/bats-assert/load'

    printf '  test-module:
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

    echo 'echo "bash %config-file%" > "$BACON_APPLY_FILE"' \
    > ./src/modules/test-module.sh && chmod +x ./src/modules/test-module.sh

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
    > ./test/expected.conf
   
    mkdir /tmp/bacon_test
    cd ./src
}

teardown() {
    rm -f ./modules/test-module.sh
    rm -rf $HOME/.cache/bacon/*
    rm -f ../test/test.yaml
    rm -f ../test/expected.conf
    rm -rf /tmp/bacon_test
}

@test "test syslog-ng module" {
    
    run ./bacon.sh ../test/test.yaml
    run diff ../test/expected.conf /tmp/bacon_test/syslog-ng.conf
    
    assert_output ''
}
