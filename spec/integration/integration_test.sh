#!/bin/bash

TMPDIR=/private$TMPDIR docker-compose up &>/dev/null &
sleep 5
aws --endpoint-url=http://localhost:4581 cloudformation deploy --template-file local_setup.yml --stack-name local

sam build --use-container
sam local start-api --env-vars prod-env.json &>/dev/null &
SAM_PID=$!

sleep 5

curl -X POST http://localhost:3000/event_data/2019pahat
KEY="$(aws --endpoint-url=http://localhost:4572 s3api list-objects --bucket my-private-bucket | grep "\"Key\": \"raw_data/event_code=2019pahat/fetch_time" | cut -c 21-84)"
FULL_PATH="s3://my-private-bucket/${KEY}"

aws --endpoint http://localhost:4572 s3 cp $FULL_PATH spec/fixtures/test.json

docker-compose down
kill $SAM_PID


cmp --silent spec/fixtures/2019pahat.json spec/fixtures/test.json
EXIT_CODE=$?
rm spec/fixtures/test.json

exit $EXIT_CODE
