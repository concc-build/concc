import json
import os
import sys
from functools import reduce

jobs = {}
job = None
last_job_name = None

LABEL_MAP = {
  'Command being timed': 'command',
  'User time (seconds)': 'user_time',
  'System time (seconds)': 'system_time',
  'Percent of CPU this job got': 'cpu',
  'Elapsed (wall clock) time (h:mm:ss or m:ss)': 'real_time',
  'Average shared text size (kbytes)': 'text_kb',
  'Average unshared data size (kbytes)': 'data_kb',
  'Average stack size (kbytes)': 'stack_kb',
  'Average total size (kbytes)': 'total_kb',
  'Maximum resident set size (kbytes)': 'max_resident_kb',
  'Average resident set size (kbytes)': 'avg_resident_kb',
  'Major (requiring I/O) page faults': 'major_page_faults',
  'Minor (reclaiming a frame) page faults': 'minor_page_faults',
  'Voluntary context switches': 'voluntary_context_switch',
  'Involuntary context switches': 'involuntary_context_switch',
  'Swaps': 'swaps',
  'File system inputs': 'fs_inputs',
  'File system outputs': 'fs_outputs',
  'Socket messages sent': 'socket_sent',
  'Socket messages received': 'socket_recv',
  'Signals delivered': 'signals',
  'Page size (bytes)': None,
  'Exit status': None,
}

def parse_command(value):
  parts = value[1:-1].split(' ')
  while True:
    if parts[0].endswith('concc-dispatch'):
      parts = parts[1:]  # removes the concc-dispatch command
      continue
    if parts[0] == '/usr/bin/time':
      parts = parts[5:]  # removes `/usr/bin/time -v -a -o /path/to/file`
      continue
    break
  return ' '.join(parts)

# This function works properly IFF all commands were executed on the same
# directory.
def make_job_name(command):
  parts = command.split(' ')
  if parts[0].endswith('gcc') or parts[0].endswith('g++') or \
     parts[0].endswith('clang') or parts[0].endswith('clang++'):
    i = parts.index('-o')
    if i == -1:
      return command
    output = parts[i + 1]
    if output == '-':
      return command
    return output
  return command

for line in sys.stdin:
  label, value = line.strip().split(': ', 2)
  if label not in LABEL_MAP:
    continue
  prop = LABEL_MAP[label]
  if prop == 'command':
    command = parse_command(value)
    job_name = make_job_name(command)
    if job_name not in jobs:
      jobs[job_name] = { 'command': command }
      last_job_name = job_name
    job = jobs[job_name]
  else:
    if prop not in job:
      job[prop] = []
    if prop in ['user_time', 'system_time']:
      val = float(value) * 1000  # ms
    elif prop == 'real_time':
      val = reduce(lambda a, v: a * 60 + v, map(float, value.split(':')))
    elif prop == 'cpu':
      val = int(value[:-1])
    else:
      val = int(value)
    job[prop].append(val)

if sys.argv[1] != 'worker':
  main_job = jobs[last_job_name]
  del jobs[last_job_name]
  jobs['MAIN'] = main_job

print('{}'.format(json.dumps({
  'name': sys.argv[1],
  'jobs': jobs,
})))
