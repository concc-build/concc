# Assumed that `strace` is executed with `-ttt -T -v -xx -X raw -y` so that it
# makes it possible to implementation a tokenizer without using any external
# library.

import decimal
import json
import os
import re
import sys

TRACE_RE = re.compile(r'(.+)\s+([a-z0-9]+)\((.*)\)\s+=\s+(.+)\s+<(.+)>')
EXITED_RE = re.compile(r'(.+)\s+[+]+ exited with (\d)+ [+]+')
COMMENT_RE = re.compile(r'/\*.*\*/')
FD_RE = re.compile(r'(\d+)<(.*)>')

def tokenize(s):
  s = COMMENT_RE.sub('', s)  # removes comments
  s = s.replace('"...', '..."')  # moves ellipsis marks inside strings
  s = s.replace(', ', '\n')
  s = s.replace('[', '[\n')
  s = s.replace(']', '\n]')
  s = s.replace('{', '{\n')
  s = s.replace('}', '\n}')
  s = s.replace('=', '\n=\n')
  for token in s.split():
    yield token

def parse_params(s):
  tokenizer = tokenize(s)
  return parse_array(tokenizer)

def parse_array(tok):
  result = []
  for token in tok:
    if token == ']':
      break
    if token == '[':
      result.append(parse_array(tok))
    elif token == '{':
      result.append(parse_struct(tok))
    else:
      result.append(parse_atom(token))
  return result

def parse_struct(tok):
  result = {}
  k = None
  v = None
  for token in tok:
    if token == '}':
      break
    if token == '=':
      continue
    if k is None:
      k = token
    else:
      if token == '[':
        result[k] = parse_array(tok)
      elif token == '{':
        result[k] = parse_struct(tok)
      else:
        result[k] = parse_atom(token)
      k = None
  return result

def parse_atom(tok):
  match = FD_RE.match(tok)
  if match:
    fd = int(match.group(1))
    text = eval('"{}"'.format(match.group(2)))
    return '{}:{}'.format(fd, text)
  try:
    return eval(tok)
  except:
    return tok

def parse_result(s):
  result, *_ = s.split(' ', 1)
  return parse_atom(result)

def parse_error(s):
  try:
    result, code, message = s.split(' ', 2)
    return {
      'code': code,
      'message': message[1:-1],
    }
  except:
    return None

for line in sys.stdin:
  line = line.strip()

  match = EXITED_RE.match(line)
  if match:
    entry = {
      'timestamp': int(decimal.Decimal(match.group(1)) * 1000000),
      'exit_code': int(match.group(2)),
    }
    try:
      print('{}'.format(json.dumps(entry)))
      continue
    except:
      break;

  match = TRACE_RE.match(line)
  if match:
    entry = {
      'timestamp': int(decimal.Decimal(match.group(1)) * 1000000),
      'syscall': match.group(2),
      'params': parse_params(match.group(3)),
      'result':  parse_result(match.group(4)),
      'error': parse_error(match.group(4)),
      'elapsed': int(decimal.Decimal(match.group(5)) * 1000000),
    }
    try:
      print('{}'.format(json.dumps(entry)))
      continue
    except:
      break
