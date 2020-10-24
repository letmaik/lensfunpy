# adapted from https://stackoverflow.com/a/1517652
import sys
import subprocess

# Note: This doesn't handle @-prefixed library paths like @loader_path/...

def otool(s):
    print(s)
    o = subprocess.Popen(['/usr/bin/otool', '-L', s], stdout=subprocess.PIPE, universal_newlines=True)
    for l in o.stdout:
        if l[0] == '\t':
            path = l.split(' ', 1)[0][1:]
            if path == s or path.startswith('/usr/lib/') or path.startswith('/System/'):
                continue
            print(' ' + path)
            yield path

need = set([sys.argv[1]])
done = set()

while need:
    needed = set(need)
    need = set()
    for f in needed:
        need.update(otool(f))
    done.update(needed)
    need.difference_update(done)
