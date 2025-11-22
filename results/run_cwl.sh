#!/bin/bash

cwltool \
  --user-space-docker-cmd docker \
  --default-container gusellerm/coastsat-cwl:latest \
  ../CoastSat-CWL/workflow/update_coastsat.cwl \
  input.yml

