import json
import sys

transcript_path = r"C:\Users\Long\.gemini\antigravity-ide\brain\7475e932-ff5b-4a25-ba85-4310e3767b3c\.system_generated\logs\transcript_full.jsonl"

def process():
    changes = []
    with open(transcript_path, 'r', encoding='utf-8') as f:
        for line in f:
            data = json.loads(line)
            if data.get('type') == 'PLANNER_RESPONSE':
                for tool in data.get('tool_calls', []):
                    name = tool.get('function', {}).get('name')
                    args = tool.get('function', {}).get('arguments')
                    if name in ('default_api:multi_replace_file_content', 'default_api:replace_file_content'):
                        if type(args) == str:
                            try:
                                args = json.loads(args)
                            except:
                                continue
                        changes.append((name, args))
    
    # Process them in order
    for name, args in changes:
        target_file = args.get('TargetFile')
        if not target_file: continue
        
        print(f"Applying {name} to {target_file}")
        
        try:
            with open(target_file, 'r', encoding='utf-8') as f:
                content = f.read()
        except FileNotFoundError:
            print(f"File not found: {target_file}")
            continue

        if name == 'default_api:multi_replace_file_content':
            chunks = args.get('ReplacementChunks', [])
            for chunk in chunks:
                target = chunk.get('TargetContent', '').replace('\r\n', '\n')
                replacement = chunk.get('ReplacementContent', '')
                content_norm = content.replace('\r\n', '\n')
                if target in content_norm:
                    content_norm = content_norm.replace(target, replacement, 1)
                    content = content_norm
                    print("  Chunk applied!")
                else:
                    print("  Target content not found!")
        else:
            target = args.get('TargetContent', '').replace('\r\n', '\n')
            replacement = args.get('ReplacementContent', '')
            content_norm = content.replace('\r\n', '\n')
            if target in content_norm:
                content_norm = content_norm.replace(target, replacement, 1)
                content = content_norm
                print("  Chunk applied!")
            else:
                print("  Target content not found!")

        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(content)

if __name__ == '__main__':
    process()
