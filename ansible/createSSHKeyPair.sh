#!/bin/bash

set -eu

ssh-keygen -t rsa -b 4096 -C "adoptopenjdk@gmail.com"

ls -lash $HOME/.ssh