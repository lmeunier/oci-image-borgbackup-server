#!/usr/bin/env bash

set -e

if ls /etc/ssh/host_keys/ssh_host_* 1> /dev/null 2>&1; then
    echo ">> Found Host keys in default location"
else
    echo ">> Generating new host keys"
    ssh-keygen -A
    mv /etc/ssh/ssh_host_*  /etc/ssh/host_keys/
fi

# command="borg serve --restrict-to-path ~/laurent --append-only",restrict ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD5iKp7+IFQZtsuWfTurbwxlZgwfyKY0oVQpCv8WhfsW0rWpDrWkCr5h4gSroPN7FlYwo62eHMVA22nawafQz9Li4Gpz9DYrOTO8uE18aF9ZEmtil4vL5Zn/DPMTtvh09I6dQYgRg80NMwg1U4OxQ4/3GFoDRzkgiVC8GKLAjH259z74l69AqrnkxHLoIj6LSOXZq2psAjHEibStFxQO9D/yJS+3QyO4/bBojc//zhk1AkM9DnWLtNX7aOdI5YOCXGevY7lgFjnKE2gMe/LvlJCtW60IWFlefz2Um6V0kzC3Z/f+pENXP+e7baJtP3l7MI8KYM/MJZ+8tSjNZmk7ILd laurent@deltalima.net

echo ">> Running $@"
exec "$@"

