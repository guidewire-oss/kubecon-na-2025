#!/bin/bash
docker exec -i k3d-kubevela-demo-server-0 kubectl "$@"
