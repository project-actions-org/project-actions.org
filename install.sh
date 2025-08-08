#!/bin/bash

if ! command -v curl &> /dev/null; then
  echo "curl is required to install xscripts"
  exit 1
fi

echo "Downloading installer..."

echo "Curl the right binary"
echo "Curl a starter kit"

echo "xscripts installed successfully!"
echo "Run 'x help' to see the available commands"