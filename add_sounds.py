import os
import re

def process_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # check if we already have it
    if "AudioService()." in content and "import '../services/audio_service.dart'" in content:
        return

    # find onTap: () { or onPressed: () {
    # We will just do a simple replacement for common patterns.
    # Pattern 1: onTap: () {
    # Pattern 2: onPressed: () {
    
    new_content = content
    
    # We also need to add import if we modify
    modified = False
    
    def repl(m):
        nonlocal modified
        modified = True
        return m.group(1) + " {\n" + (" " * len(m.group(1))) + "AudioService().playTap();\n"

    new_content = re.sub(r'(onTap:\s*\(\)\s*(?:async)?)\s*\{', repl, new_content)
    new_content = re.sub(r'(onPressed:\s*\(\)\s*(?:async)?)\s*\{', repl, new_content)

    if modified:
        # Add import at the top of the file
        # Find last import
        import_str = "import '../services/audio_service.dart';\n"
        # Adjust import path if in lib/ or lib/widgets/ or lib/screens/
        parts = path.split(os.sep)
        if 'lib' in parts:
            idx = parts.index('lib')
            depth = len(parts) - idx - 2
            if depth < 0: depth = 0
            prefix = '../' * depth if depth > 0 else './'
            import_str = f"import '{prefix}services/audio_service.dart';\n"

        lines = new_content.split('\n')
        last_import = -1
        for i, line in enumerate(lines):
            if line.startswith('import '):
                last_import = i
        
        if last_import != -1:
            lines.insert(last_import + 1, import_str.strip())
        else:
            lines.insert(0, import_str.strip())
            
        with open(path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines))
        print(f"Added sounds to {path}")

def main():
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart') and 'audio_service' not in file:
                process_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
