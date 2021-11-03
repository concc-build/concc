import json
import os
import sys

data = json.load(sys.stdin)
outcomes = list(map(lambda x: x['outcome'], data))
jobs = {}
for entry in data:
  jobs[entry['outcome']] = entry['job']

print('''
<!DOCTYPE html>
<html>
  <head>
    <link href="https://unpkg.com/gridjs/dist/theme/mermaid.min.css" rel="stylesheet" />
  </head>
  <body>
    <select id="select"></select>
    <div id="content"></div>
    <script src="https://unpkg.com/gridjs/dist/gridjs.umd.js"></script>
    <script>
      const JOBS = {jobs};
      const OUTCOMES = {outcomes};
      const select = document.getElementById('select');
      for (const outcome of OUTCOMES) {{
        const option = document.createElement('option');
        option.setAttribute('value', outcome);
        option.innerText = outcome;
        select.appendChild(option);
      }}
      function collectSyscallNames(job) {{
        const syscall_names = [];
        for (const summary_name of Object.keys(job.summary)) {{
          const summary = job.summary[summary_name];
          for (const syscall_name of Object.keys(summary.syscall.stats)) {{
            if (!syscall_names.includes(syscall_name)) {{
              syscall_names.push(syscall_name)
            }}
          }}
        }}
        return syscall_names.sort();
      }}
      function renderJob(job) {{
        const syscall_names = collectSyscallNames(job);
        const columns = ['case', 'total', 'syscalls', ...syscall_names];
        const data = [];
        const slow_syscalls = [];
        for (const summary_name of Object.keys(job.summary).sort()) {{
          const summary = job.summary[summary_name];
          const per = (100 * summary.syscall.elapsed / summary.elapsed).toFixed(2);
          summary_data = [
            summary_name,
            summary.elapsed,
            `${{per}} %, ${{summary.syscall.elapsed}}`,
          ];
          for (const syscall_name of syscall_names) {{
            const syscall = summary.syscall.stats[syscall_name];
            if (syscall) {{
              const per_total = (100 * syscall.elapsed / summary.elapsed).toFixed(2);
              if (per_total >= 10 && !slow_syscalls.includes(syscall_name)) {{
                slow_syscalls.push(syscall_name);
              }}
              const per_syscall = (100 * syscall.elapsed / summary.syscall.elapsed).toFixed(2);
              summary_data.push(`${{per_total}}%, ${{per_syscall}}% ${{syscall.elapsed}} (${{syscall.count}})`);
            }} else {{
              summary_data.push('');
            }}
          }}
          data.push(summary_data);
        }}
        const container = document.createElement('dl');
        const title = document.createElement('dt');
        container.appendChild(title);
        title.innerText = job.command;
        const content = document.createElement('dd');
        container.appendChild(content);
        const grid = document.createElement('div');
        content.appendChild(grid);
        new gridjs.Grid({{ columns, data }}).render(grid);
        setTimeout(() => {{
          for (const slow_syscall of slow_syscalls) {{
            const cells = grid.querySelectorAll(`td[data-column-id="${{slow_syscall}}"]`);
            for (let i = 0; i < cells.length; ++i) {{
              cells.item(i).style.color = 'red';
            }}
          }}
        }}, 1000);
        const child = document.createElement('div');
        content.appendChild(child);
        for (const subJob of job.jobs) {{
          child.appendChild(renderJob(subJob));
        }}
        return container;
      }}
      function render(outcome) {{
        const job = JOBS[outcome];
        const container = renderJob(job);
        const content = document.getElementById('content');
        content.innerHTML = '';
        content.appendChild(container);
      }}
      select.addEventListener('change', (event) => {{
        render(event.target.value);
      }})
      render(OUTCOMES[0]);
    </script>
  </body>
</html>
'''.format(
  outcomes=json.dumps(outcomes),
  jobs=json.dumps(jobs),
).strip())
