#!/bin/bash

# queueurl is required to send or receive messages from SQS

# Note: AWS CLI and boto3 need to use legacy endpoint
# If we use the AWS CLI or SDK for Python, we need to use the legacy endpoints from https://docs.aws.amazon.com/general/latest/gr/sqs-service.html.
# Otherwise, you will get the following error
# botocore.exceptions.ClientError: An error occurred (InvalidAddress) when calling the ReceiveMessage operation: The address https://eu-central-1.queue.amazonaws.com/ is not valid for this endpoint.

queueurl=$(aws sqs get-queue-url --queue-name "MyMessages"|jq ".QueueUrl"|sed "s/sqs.us-east-1.amazonaws.com/queue.amazonaws.com/g"|sed 's/"//g')
echo "queueurl:" $queueurl

for i in {1..2000};
do
    # receiptHandle is required to delete the message from SQS after the message is retreived
    receiptHandle=$(aws sqs receive-message --queue-url $queueurl|jq .Messages[0].ReceiptHandle|sed 's/"//g')
    #echo "receiptHandle:" $receiptHandle

    #echo -e "aws sqs delete-message --queue-url $queueurl --receipt-handle $receiptHandle --region us-east-1"
    aws sqs delete-message --queue-url $queueurl --receipt-handle $receiptHandle --region us-east-1;

    echo "Sleep for 1 second..."
    sleep 1
done;
