#!/bin/bash

if [ -f .env ]
then
  export $(cat .env | sed 's/#.*//g' | xargs)
fi

API_HOST=$API_HOST make package FINALPACKAGE=1

