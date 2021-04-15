import os

exclude = [
    '/sys/',
    '/proc/',
    '/runtime/lib/python3.9/',
    '/app-libs/numpy/',
]

def should_skip(path):
    for prefix in exclude:
        if path.startswith(prefix):
            return True
    
    return False

def show_dirtree():
    for root, dirs, files in os.walk('/'):
        for d in dirs:
            path = os.path.join(root, d)
            if not should_skip(path):
                print('->', path)
