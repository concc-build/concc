import glob
import json
import os
import sys

def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)

def get_path_label(path):
  if path.startswith('pipe:'):
    return 'pipe'
  if path.startswith('/workspace/'):
    return 'src'
  if path.startswith('/'):
    return 'sys'
  return 'src'

def collect_jobs(datadir):
  jobs = {}
  for jsonl_file in glob.glob(os.path.join(datadir, '*.strace.jsonl')):
    pid = int(os.path.basename(jsonl_file).split('.')[0])
    first_timestamp = None
    last_timestamp = None
    syscall_elapsed = 0
    syscall_stats = {}
    command = None
    args = None
    child_pids = []
    with open(jsonl_file) as file_:
      for line in file_:
        strace = json.loads(line.strip())
        if not first_timestamp:
          first_timestamp = strace['timestamp']
        last_timestamp = strace['timestamp']
        if 'syscall' in strace:
          syscall = strace['syscall']
          elapsed = strace['elapsed']
          error = strace['error']
          syscall_elapsed += elapsed
          path_label = None
          if syscall == 'execve' and not error:
            command = strace['params'][0]
            args = strace['params'][1]
          elif syscall == 'vfork' and not error:
            child_pids.append(strace['result'])
          elif syscall == 'access':
            path = strace['params'][0]
            path_label = get_path_label(path)
          elif syscall == 'close':
            _, path = strace['params'][0].split(':', 1)
            path_label = get_path_label(path)
          elif syscall == 'fstat':
            _, path = strace['params'][0].split(':', 1)
            path_label = get_path_label(path)
          elif syscall == 'lseek':
            _, path = strace['params'][0].split(':', 1)
            path_label = get_path_label(path)
          elif syscall == 'lstat':
            path = strace['params'][0]
            path_label = get_path_label(path)
          elif syscall == 'openat':
            path = strace['params'][1]
            path_label = get_path_label(path)
          elif syscall == 'stat':
            path = strace['params'][0]
            path_label = get_path_label(path)
          elif syscall == 'read':
            _, path = strace['params'][0].split(':', 1)
            path_label = get_path_label(path)
          elif syscall == 'write':
            _, path = strace['params'][0].split(':', 1)
            path_label = get_path_label(path)
          if error:
            result_label = 'err'
          else:
            result_label = 'ok'
          if path_label:
            label = '{}.{}.{}'.format(syscall, path_label, result_label)
          else:
            label = '{}.{}'.format(syscall, result_label)
          if label not in syscall_stats:
            syscall_stats[label] = {
              'count': 0,
              'elapsed': 0,
            }
          syscall_stats[label]['count'] += 1
          syscall_stats[label]['elapsed'] += elapsed
    jobs[pid] = {
      'pid': pid,
      'file': os.path.abspath(jsonl_file),
      'command': command,
      'args': args,
      'elapsed': last_timestamp - first_timestamp,
      'syscall': {
        'elapsed': syscall_elapsed,
        'stats': syscall_stats,
      },
      'child_pids': child_pids,
    }
  return jobs

def create_job_node(case, job, jobs):
  summary = {}
  summary[case] = {
    'file': job['file'],
    'elapsed': job['elapsed'],
    'syscall': job['syscall'],
  }
  child_jobs = list(
    map(lambda x: create_job_node(case, jobs[x], jobs), job['child_pids']))
  return {
    'command': job['command'],
    'args': job['args'],
    'summary': summary,
    'jobs': child_jobs,
  }

def merge_job_node(outcome, case, job1, job2):
  if case in job1['summary']:
    eprint('WARN: already exists: {} {} {}'.format(outcome, case, job1['command']))
    eprint('  job1: {}'.format(json.dumps(job1['summary'][case]['file'])))
    eprint('  job2: {}'.format(json.dumps(job2['summary'][case]['file'])))
    return
  job1['summary'][case] = job2['summary'][case]
  for sub_job1 in job1['jobs']:
    for sub_job2 in job2['jobs']:
      if sub_job1['command'] == sub_job2['command']:
        merge_job_node(outcome, case, sub_job1, sub_job2)

outcomes = {}
for datadir in glob.glob(os.path.join(sys.argv[1], '*')):
  eprint('Processing files in {}...'.format(datadir))
  case = os.path.basename(datadir)
  jobs = collect_jobs(datadir)
  for job in jobs.values():
    if not job['command'].endswith('/gcc'):
      continue
    try:
      i = job['args'].index('-o')
    except:
      eprint('ERROR: no -o option in gcc command')
      continue
    outcome = job['args'][i + 1]
    job_node = create_job_node(case, job, jobs)
    if outcome not in outcomes:
      outcomes[outcome] = {
        'outcome': outcome,
        'job': job_node,  # job tree
      }
    else:
      merge_job_node(outcome, case, outcomes[outcome]['job'], job_node)

results = sorted(outcomes.values(), key=lambda x: x['outcome'])
print('{}'.format(json.dumps(results)))
