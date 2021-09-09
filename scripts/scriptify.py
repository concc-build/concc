import os
import shlex
import sys

EXCLUDED_ENVS = [
  '_',
  'HOSTNAME',
  'PWD',
  'LC_CTYPE',
]

cmd = ' '.join([shlex.quote(arg) for arg in sys.argv[1:]])

debug = False
if os.environ.get('CONCC_DEBUG') == '1':
  debug = True

script = []

if debug:
  script.append('set -x')

script.append('cd {}'.format(os.getcwd()))

for k, v in os.environ.items():
  if k in EXCLUDED_ENVS:
    continue
  script.append('export {}={}'.format(k, shlex.quote(v)))

script.append('{}'.format(cmd))

script = '\n'.join(script)
if debug:
  print('{}'.format(script), file=sys.stderr)
print('{}'.format(script))
