#!/bin/bash

git config --global user.email "jessumolano@gmail.com"
git config --global user.name "jesus-molano"

ssh-keygen -t ed25519 -C "jessumolano@gmail.com" -N "" -f ~/.ssh/id_ed25519

echo "La clave SSH es:"
cat ~/.ssh/id_ed25519.pub
