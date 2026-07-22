#!/bin/bash
# SSM session into the private web server instance, reading its ID straight from terraform output.
set -euo pipefail

aws ssm start-session \
    --target "$(terraform output -raw webserver_id)" \
    --document-name AWS-StartInteractiveCommand \
    --parameters 'command=["cd ~ && exec bash -l"]'
