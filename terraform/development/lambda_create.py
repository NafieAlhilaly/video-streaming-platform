"""
AWS Lambda: MediaLive Creator
Functionality: Loads configuration from DynamoDB and creates a MediaLive channel.
"""

import json
import os
import uuid
import time
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

medialive = boto3.client("medialive")
dynamodb = boto3.client("dynamodb")

DYNAMODB_TABLE_NAME = os.environ["DYNAMODB_TABLE_NAME"]
CONFIG_TABLE_NAME = os.environ["DYNAMODB_CONFIG_TABLE_NAME"]
MEDIALIVE_INPUT_ID = os.environ["MEDIALIVE_INPUT_ID"]
MEDIAPACKAGE_INGEST_URL = os.environ["MEDIAPACKAGE_INGEST_URL"]
MEDIALIVE_ROLE_ARN = os.environ["MEDIALIVE_ROLE_ARN"]
ENVIRONMENT = os.environ["ENVIRONMENT"]
PROJECT_NAME = os.environ["PROJECT_NAME"]

def get_config(config_name):
    """Fetch configuration template from DynamoDB"""
    try:
        resp = dynamodb.get_item(
            TableName=CONFIG_TABLE_NAME,
            Key={"config_name": {"S": config_name}}
        )
        if "Item" not in resp:
            return None
        
        item = resp["Item"]
        return {
            "video": json.loads(item["video_renditions"]["S"]) if "video_renditions" in item else [],
            "audio": json.loads(item["audio_renditions"]["S"]) if "audio_renditions" in item else [],
            "color_space": item.get("color_space", {}).get("S", "REC_709"),
            "destination_url": item.get("destination_url", {}).get("S")
        }
    except Exception as e:
        logger.error(f"Error loading config {config_name}: {str(e)}")
        return None

def build_channel_params(name, config, destination_url=None):
    """Build the MediaLive API payload"""
    dest_url = destination_url or config.get("destination_url") or MEDIAPACKAGE_INGEST_URL
    
    video_descriptions = []
    for idx, v in enumerate(config["video"]):
        height = int(v.get("height", 720))
        bitrate = int(v.get("bitrate", 3000)) * 1000 if int(v.get("bitrate", 3000)) < 10000 else int(v.get("bitrate", 3000))
        
        video_descriptions.append({
            "Name": f"video_{height}p_{idx}",
            "Height": height,
            "Width": int(v.get("width", 1280)),
            "CodecSettings": {
                "H264Settings": {
                    "Bitrate": bitrate,
                    "FramerateControl": "SPECIFIED",
                    "FramerateNumerator": int(v.get("frameRate", 30)),
                    "FramerateDenominator": 1,
                    "GopSize": float(v.get("gopSizeInFrames", 90)),
                    "GopSizeUnits": "FRAMES",
                    "Profile": v.get("profile", "MAIN").upper(),
                    "RateControlMode": v.get("rateControl", "CBR").upper()
                }
            }
        })

    audio_descriptions = []
    for idx, a in enumerate(config["audio"]):
        audio_descriptions.append({
            "AudioSelectorName": "default",
            "Name": f"audio_{idx+1}",
            "CodecSettings": {
                "AacSettings": {
                    "Bitrate": int(a.get("bitrate", 128)) * 1000 if int(a.get("bitrate", 128)) < 10000 else int(a.get("bitrate", 128)),
                    "CodingMode": "CODING_MODE_2_0",
                    "SampleRate": int(a.get("sampleRate", 48000))
                }
            }
        })

    outputs = [{
        "AudioDescriptionNames": [a["Name"] for a in audio_descriptions],
        "OutputName": f"out_{v['Height']}p",
        "VideoDescriptionName": v["Name"],
        "OutputSettings": {
            "HlsOutputSettings": {
                "NameModifier": f"_{v['Height']}p",
                "HlsSettings": {"StandardHlsSettings": {"M3u8Settings": {}}}
            }
        }
    } for v in video_descriptions]

    return {
        "Name": name,
        "ChannelClass": "SINGLE_PIPELINE",
        "InputSpecification": {
            "Codec": "AVC",
            "MaximumBitrate": "MAX_20_MBPS",
            "Resolution": "HD"
        },
        "InputAttachments": [{
            "InputAttachmentName": "main-input",
            "InputId": MEDIALIVE_INPUT_ID
        }],
        "Destinations": [{"Id": "hls-destination", "Settings": [{"Url": dest_url}]}],
        "RoleArn": MEDIALIVE_ROLE_ARN,
        "EncoderSettings": {
            "TimecodeConfig": {"Source": "EMBEDDED"},
            "AudioDescriptions": audio_descriptions,
            "VideoDescriptions": video_descriptions,
            "OutputGroups": [{
                "Name": "hls-group",
                "OutputGroupSettings": {
                    "HlsGroupSettings": {
                        "Destination": {"DestinationRefId": "hls-destination"},
                        "HlsCdnSettings": {
                            "HlsBasicPutSettings": {"NumRetries": 3}
                        },
                        "SegmentLength": 2
                    }
                },
                "Outputs": outputs
            }]
        }
    }

def lambda_handler(event, context):
    logger.info(f"Creator Event: {json.dumps(event)}")
    
    config_name = event.get("config_name")
    video_renditions = event.get("video_renditions")
    audio_renditions = event.get("audio_renditions")

    config = None
    if config_name:
        config = get_config(config_name)
        if not config:
            return {"statusCode": 404, "error": f"Config {config_name} not found"}
    elif video_renditions and audio_renditions:
        # Support direct creation without a saved config
        config = {
            "video": video_renditions,
            "audio": audio_renditions,
            "color_space": event.get("color_space", "REC_709"),
            "destination_url": event.get("destination_url")
        }

    if not config:
        return {"statusCode": 400, "error": "config_name or renditions are required"}

    channel_name = event.get("channel_name") or f"{PROJECT_NAME}-{ENVIRONMENT}-{int(time.time())}"
    params = build_channel_params(channel_name, config, event.get("destination_url"))
    
    try:
        response = medialive.create_channel(**params)
        channel_id = response["Channel"]["Id"]
        
        # TTL Logic
        ttl_hours = event.get("ttl_hours", 24)
        expiry = int(time.time()) + (ttl_hours * 3600)
        
        # Registration
        status = "CREATED"
        if event.get("auto_start"):
            try:
                medialive.start_channel(ChannelId=channel_id)
                status = "STARTING"
            except Exception as start_err:
                logger.error(f"Auto-start failed: {str(start_err)}")

        dynamodb.put_item(
            TableName=DYNAMODB_TABLE_NAME,
            Item={
                "channel_id": {"S": channel_id},
                "channel_name": {"S": channel_name},
                "status": {"S": status},
                "created_at": {"N": str(int(time.time()))},
                "deletion_scheduled_at": {"N": str(expiry)},
                "config_used": {"S": config_name or "CUSTOM"}
            }
        )
        
        return {"statusCode": 200, "channel_id": channel_id, "status": status}
    except Exception as e:
        logger.error(f"Creation failed: {str(e)}")
        return {"statusCode": 500, "error": str(e)}