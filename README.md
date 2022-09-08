# BACON: The Bash Configurator

BACON is a simple confiuration managment tool written entirelly in Bash. 

## Installation

Clone this repository:
```sh
$ git clone https://github.com/sanjin-stevanovic/bacon.git
```
BACON can be used directly from the src directory without installation:
```sh
$ cd bacon/src
$ ./bacon.sh
```
Or installed globally by using the install.sh script
```sh
$ cd bacon
$ ./install.sh
```
By default this installs bacon to /opt/bacon\
NOTE: the install.sh scripts uses sudo to gain premissions to the install directory

## Usage

bacon <options> <path to .yaml|.yml file>

## Add New Modules

Copy the new module to the modules directory, and make sure the module is exectutable.
