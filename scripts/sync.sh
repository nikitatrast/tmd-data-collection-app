#!/bin/bash

rsync -a ./server/ vmj:~/data_collection_app/server --exclude=app/data --exclude=.vscode --exclude=__pycache__
