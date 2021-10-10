import json
import os
import sys

jobs = {}
names = []

for line in sys.stdin:
  metrics = json.loads(line.strip())
  names.append(metrics['name'])
  for job_name, job in metrics['jobs'].items():
    if job_name not in jobs:
      jobs[job_name] = {}
    real_time_data = job['real_time']
    jobs[job_name][metrics['name']] = round(sum(real_time_data) / len(real_time_data), 3)

columns = ['jobs'] + names + ['client/nondist']
data = []
for job_name in sorted(jobs.keys()):
  job = jobs[job_name]
  job_data = [job_name] + [job.get(name) for name in names]
  job_data.append(round(job['client'] / job['nondist'], 3))
  data.append(job_data)

print('''
<!DOCTYPE html>
<html>
  <head>
    <link href="https://unpkg.com/gridjs/dist/theme/mermaid.min.css" rel="stylesheet" />
  </head>
  <body>
    <div id="wrapper"></div>
    <script src="https://unpkg.com/gridjs/dist/gridjs.umd.js"></script>
    <script>
      new gridjs.Grid({{
        columns: {},
        data: {},
      }}).render(document.getElementById('wrapper'));
    </script>
  </body>
</html>
'''.format(json.dumps(columns), json.dumps(data)).strip())
