"""
AWS Lambda: MediaLive Deleter
Functionality: Safe Stop -> Wait -> Delete lifecycle.
"""

import json
import os
import time
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

medialive = boto3.client("medialive")

def lambda_handler(event, context):
    logger.info(f"Deleter Event: {json.dumps(event)}")
    
    channel_id = None
    
    # Handle Stream (TTL) or Direct Invoke
    if "Records" in event:
        for record in event["Records"]:
            if record["eventName"] == "REMOVE":
                channel_id = record["dynamodb"].get("OldImage", {}).get("channel_id", {}).get("S")
    else:
        channel_id = event.get("channel_id")

    if not channel_id:
        return {"statusCode": 400, "error": "No channel_id found"}

    try:
        # 1. Check State
        resp = medialive.describe_channel(ChannelId=channel_id)
        state = resp.get("Channel", {}).get("State")
        logger.info(f"Channel {channel_id} is in state: {state}")

        # 2. Stop if necessary
        if state in ["RUNNING", "STARTING"]:
            logger.info(f"Stopping channel {channel_id}...")
            medialive.stop_channel(ChannelId=channel_id)
            
            # Wait logic
            max_attempts = 15 # 5 second intervals = 75 seconds
            for i in range(max_attempts):
                time.sleep(5)
                check = medialive.describe_channel(ChannelId=channel_id)
                new_state = check.get("Channel", {}).get("State")
                logger.info(f"Wait attempt {i+1}: {new_state}")
                if new_state == "STOPPED":
                    break
                if i == max_attempts - 1:
                    raise TimeoutError(f"Channel {channel_id} failed to stop in time.")
        
        elif state == "STOPPING":
            # Just wait
            time.sleep(30)
        
        # 3. Final Delete
        # If state is IDLE, CREATED, or STOPPED, we can delete
        try:
            logger.info(f"Executing final deletion for {channel_id}")
            medialive.delete_channel(ChannelId=channel_id)
            return {"statusCode": 200, "message": "Deleted"}
        except Exception as delete_err:
            if "NotFoundException" in str(delete_err):
                return {"statusCode": 200, "message": "Already deleted"}
            raise delete_err

    except medialive.exceptions.NotFoundException:
        logger.info(f"Channel {channel_id} already gone.")
        return {"statusCode": 200, "message": "Not found"}
    except Exception as e:
        logger.error(f"Cleanup failed for {channel_id}: {str(e)}")
        # Re-raise so Lambda retries if it's a transient AWS error
        raise e