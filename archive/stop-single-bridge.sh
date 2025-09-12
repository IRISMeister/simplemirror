#!/bin/bash
docker compose -f docker compose-single-bridge.yml down
sudo rm -fR iris1A/* iris1B/* iris2A/* iris2B/*
