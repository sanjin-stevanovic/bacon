teardown() {
    sudo rm -rf ./test/bacon
    sudo rm -f ~/.local/bin/bacon
}

@test "test install script" {
    ./install.sh ./test ~/.local/bin
    [ -d ./test/bacon ]
    [ -f "$HOME/.local/bin/bacon" ]
    [ "$(readlink -f ~/.local/bin/bacon)" = "$PWD/test/bacon/bacon.sh" ]
}
