#!/usr/bin/env python3
"""
DynamoDB Helper for MediaLive Configuration Management
Uses boto3 SDK to bypass AWS CLI JSON parsing issues
"""

import boto3
import json
import sys
from typing import Dict, Any, Optional

class DynamoDBConfigManager:
    def __init__(self, region: str = "us-east-2", table_name: str = "live-stream-dev-medialive-configs"):
        self.region = region
        self.table_name = table_name
        self.dynamodb = boto3.resource('dynamodb', region_name=region)
        self.table = self.dynamodb.Table(table_name)
    
    def save_config(self, config_name: str, video_renditions: list, audio_renditions: list, 
                   caption_renditions: list, color_space: str, global_color_correction: dict, 
                   description: str) -> Dict[str, Any]:
        """Save configuration to DynamoDB"""
        try:
            import time
            timestamp = int(time.time())
            
            item = {
                'config_name': config_name,
                'video_renditions': json.dumps(video_renditions),
                'audio_renditions': json.dumps(audio_renditions),
                'caption_renditions': json.dumps(caption_renditions),
                'color_space': color_space,
                'global_color_correction': json.dumps(global_color_correction),
                'description': description,
                'created_at': timestamp,
                'updated_at': timestamp
            }
            
            self.table.put_item(Item=item)
            return {'success': True, 'message': f'Configuration saved: {config_name}'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_config(self, config_name: str) -> Dict[str, Any]:
        """Retrieve configuration from DynamoDB"""
        try:
            response = self.table.get_item(Key={'config_name': config_name})
            if 'Item' not in response:
                return {'success': False, 'error': f'Configuration not found: {config_name}'}
            
            item = response['Item']
            # Parse JSON strings back to objects
            item['video_renditions'] = json.loads(item.get('video_renditions', '[]'))
            item['audio_renditions'] = json.loads(item.get('audio_renditions', '[]'))
            item['caption_renditions'] = json.loads(item.get('caption_renditions', '[]'))
            item['global_color_correction'] = json.loads(item.get('global_color_correction', '{}'))
            
            return {'success': True, 'data': item}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def delete_config(self, config_name: str) -> Dict[str, Any]:
        """Delete configuration from DynamoDB"""
        try:
            self.table.delete_item(Key={'config_name': config_name})
            return {'success': True, 'message': f'Configuration deleted: {config_name}'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def list_configs(self) -> Dict[str, Any]:
        """List all configurations"""
        try:
            response = self.table.scan()
            items = response.get('Items', [])
            
            # Parse JSON strings in each item
            for item in items:
                item['video_renditions'] = json.loads(item.get('video_renditions', '[]'))
                item['audio_renditions'] = json.loads(item.get('audio_renditions', '[]'))
                item['caption_renditions'] = json.loads(item.get('caption_renditions', '[]'))
                item['global_color_correction'] = json.loads(item.get('global_color_correction', '{}'))
            
            return {'success': True, 'data': items}
        except Exception as e:
            return {'success': False, 'error': str(e)}

def main():
    """CLI interface for PowerShell integration"""
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'Missing command'}))
        sys.exit(1)
    
    command = sys.argv[1]
    manager = DynamoDBConfigManager()
    
    try:
        if command == 'save':
            # Arguments: save <config_name> <video_json> <audio_json> <caption_json> <color_space> <correction_json> <description>
            if len(sys.argv) < 8:
                raise ValueError("Missing arguments for save command")
            
            config_name = sys.argv[2]
            video_renditions = json.loads(sys.argv[3])
            audio_renditions = json.loads(sys.argv[4])
            caption_renditions = json.loads(sys.argv[5])
            color_space = sys.argv[6]
            global_color_correction = json.loads(sys.argv[7])
            description = sys.argv[8] if len(sys.argv) > 8 else ""
            
            result = manager.save_config(
                config_name, video_renditions, audio_renditions, caption_renditions,
                color_space, global_color_correction, description
            )
            print(json.dumps(result))
        
        elif command == 'get':
            if len(sys.argv) < 3:
                raise ValueError("Missing config_name argument")
            result = manager.get_config(sys.argv[2])
            print(json.dumps(result, default=str))
        
        elif command == 'delete':
            if len(sys.argv) < 3:
                raise ValueError("Missing config_name argument")
            result = manager.delete_config(sys.argv[2])
            print(json.dumps(result))
        
        elif command == 'list':
            result = manager.list_configs()
            print(json.dumps(result, default=str))
        
        else:
            print(json.dumps({'error': f'Unknown command: {command}'}))
            sys.exit(1)
    
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        sys.exit(1)

if __name__ == '__main__':
    main()
