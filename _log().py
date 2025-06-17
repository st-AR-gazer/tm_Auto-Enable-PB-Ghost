import argparse
import os
import re

ap = argparse.ArgumentParser(description="Patch log(...) calls in .as files")
ap.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
args = ap.parse_args()

LOG_RE      = re.compile(r'log\((.*?)\);')
FUNC_HDR_RE = re.compile(
    r'(?:void|int|uint|int8|uint8|int16|uint16|int64|uint64|float|double|bool|string|'
    r'wstring|vec[234]|int[23]|nat[23]|iso3|mat[34]|quat|RGBAColor|MemoryBuffer|'
    r'DataRef|CMwStack|MwId|MwSArray|MwStridedArray|MwFast(Array|Buffer|BufferCat)|'
    r'MwRefBuffer|MwNodPool|MwVirtualArray|array<[^>]*>|enum\w*|dictionary|ref)'
    r'\s+(\w+)\s*\([^)]*\)\s*\{'
)

DEFAULT_PARAMS = [
    '""',                    # msg placeholder
    'LogLevel::Info',
    '-1',                    # line   (auto)
    '""',                    # func   (auto)
    '""',                    # customTag
    '"\\\\$f80"'             # customColor  (double-backslash!)
]

def nearest_func(lines, idx):
    for i in range(idx, -1, -1):
        m = FUNC_HDR_RE.search(lines[i])
        if m:
            return m.group(2) if m.lastindex >= 2 else m.group(1)
    return "Unknown"

def split_args(argstr):
    out, buf, depth, in_str = [], '', 0, False
    for ch in argstr:
        if ch == '"' and not in_str:
            in_str = True
        elif ch == '"' and in_str:
            in_str = False
        elif ch in '([' and not in_str:
            depth += 1
        elif ch in ')]' and not in_str:
            depth -= 1

        if ch == ',' and depth == 0 and not in_str:
            out.append(buf.strip()); buf = ''
        else:
            buf += ch
    if buf: out.append(buf.strip())
    return out

def ensure_double_backslash(text: str) -> str:
    return re.sub(r'(?<!\\)\\(?=\$)', r'\\\\', text)

def patch_params(params, lineno, lines):
    while len(params) < 6:
        params.append(DEFAULT_PARAMS[len(params)])

    params[2] = str(lineno + 1)
    params[3] = f'"{nearest_func(lines, lineno)}"'

    if "LogLevel::" not in params[1]:
        params[1] = "LogLevel::Info"

    params[5] = '"\\\\$f80"'

    params = [ensure_double_backslash(p) for p in params]

    return params

def process_file(path, verbose=False):
    changed = False
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for i, l in enumerate(lines):
        if 'log(' not in l:
            continue
        m = LOG_RE.search(l)
        if not m:
            continue

        params = split_args(m.group(1))
        params = patch_params(params, i, lines)
        new_line = l.replace(m.group(0), f'log({", ".join(params)});')

        if new_line != l:
            lines[i] = new_line
            changed = True
            if verbose:
                print(f"{path}:{i+1}  {new_line.strip()}")

    if changed:
        with open(path, 'w', encoding='utf-8') as f:
            f.writelines(lines)
    return changed

def walk(root):
    for d, _, files in os.walk(root):
        for fn in files:
            if fn.endswith('.as'):
                process_file(os.path.join(d, fn), args.verbose)

if __name__ == '__main__':
    walk('./src')
