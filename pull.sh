#!/bin/bash
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 705098187465.dkr.ecr.us-east-2.amazonaws.com
docker compose pull releasebelt
