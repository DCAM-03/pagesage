import argparse
import csv
import hashlib
import io
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import statistics
import subprocess
import tempfile
import time
import unicodedata

from PIL import Image, ImageEnhance, ImageFilter, ImageOps

COMMIT = '0604d9843f1dfa3a292bd5f253ae83a1ba47cd24'
SOURCE = f'https://raw.githubusercontent.com/opendatalab/OmniDocBench/{COMMIT}'
DATA = f'{SOURCE}/demo_data/omnidocbench_demo'
PROFILES = {'bounded2200': (2200, 5_000_000), 'bounded3300': (3300, 10_000_000)}
PAGE_GROUPS = {'english': [2, 3, 10], 'chinese': [4, 5, 6, 7, 16, 17]}
PERFORMANCE_PAGES = [2, 3, 4, 5, 10, 16]
OPEN_PUNCTUATION = set('（【《「『([{')
CLOSE_PUNCTUATION = set('，。！？；：、）】》」』,.!?;:)]}')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)


def fetch(url, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + '.download')
    subprocess.run(
        ['curl', '--fail', '--silent', '--show-error', '--location',
         '--connect-timeout', '10', '--max-time', '60', '--retry', '2',
         url, '--output', str(temporary)],
        check=True, timeout=200,
    )
    temporary.replace(destination)


def normalized(text):
    return ''.join(character for character in unicodedata.normalize('NFC', text)
                   if not character.isspace())


def edit_distance(expected, actual):
    if len(expected) < len(actual):
        expected, actual = actual, expected
    previous = list(range(len(actual) + 1))
    for row_index, expected_character in enumerate(expected, 1):
        current = [row_index]
        for column_index, actual_character in enumerate(actual, 1):
            current.append(min(current[-1] + 1, previous[column_index] + 1,
                               previous[column_index - 1] +
                               (expected_character != actual_character)))
        previous = current
    return previous[-1]


def is_cjk(character):
    return '\u3400' <= character <= '\u9fff' or '\uf900' <= character <= '\ufaff'


def parse_tsv(value):
    reader = csv.DictReader(io.StringIO(value), delimiter='\t', quoting=csv.QUOTE_NONE)
    required = {'level', 'page_num', 'block_num', 'par_num', 'line_num', 'text'}
    if not reader.fieldnames or not required.issubset(reader.fieldnames):
        raise ValueError('invalid TSV header')
    lines = []
    line_key = None
    current = ''
    word_count = 0
    for row in reader:
        if row['level'] != '5' or not row['text'].strip():
            continue
        key = tuple(row[name] for name in ('page_num', 'block_num', 'par_num', 'line_num'))
        if key != line_key:
            if current:
                lines.append(current)
            current = ''
            line_key = key
        word = row['text'].strip()
        if current and not (is_cjk(current[-1]) and is_cjk(word[0])) and \
                word[0] not in CLOSE_PUNCTUATION and current[-1] not in OPEN_PUNCTUATION:
            current += ' '
        current += word
        word_count += 1
    if current:
        lines.append(current)
    return '\n'.join(lines), word_count


def self_check():
    assert edit_distance('', '') == 0
    assert edit_distance('kitten', 'sitting') == 3
    assert edit_distance('阅读器', '阅读气') == 1
    assert normalized('e\u0301 中\n文 123。') == 'é中文123。'
    assert normalized('1。') != normalized('1.')
    header = 'level\tpage_num\tblock_num\tpar_num\tline_num\ttext\n'
    parsed, count = parse_tsv(header + '5\t1\t1\t1\t1\t阅\n5\t1\t1\t1\t1\t读\n'
                              + '5\t1\t1\t1\t2\tHello\n5\t1\t1\t1\t2\tworld\n')
    assert parsed == '阅读\nHello world' and count == 4
    assert parse_tsv(header) == ('', 0)
    try:
        parse_tsv('bad\n')
    except ValueError:
        pass
    else:
        raise AssertionError('invalid header accepted')


def eligible(page):
    result = []
    for block in page['layout_dets']:
        text = block.get('text', '')
        attributes = block.get('attribute', {})
        if (block['category_type'] == 'text_block' and not block.get('ignore')
                and not block.get('merge_list') and 60 <= len(text) <= 1400
                and '\\' not in text and '$' not in text
                and attributes.get('text_rotate', 'normal') == 'normal'
                and attributes.get('text_background', 'white') == 'white'):
            result.append(block)
    return sorted(result, key=lambda block: (block.get('order', 0), block['anno_id']))


def select_blocks(pages, group):
    selections = []
    candidates = {index: eligible(pages[index]) for index in PAGE_GROUPS[group]}
    position = 0
    while len(selections) < 10:
        found = False
        for page_index, blocks in candidates.items():
            if position < len(blocks):
                block = blocks[position]
                selections.append({'id': f'{group}-{len(selections) + 1:02}',
                                   'group': group, 'page': page_index,
                                   'block_id': block['anno_id'], 'transform': 'none'})
                found = True
                if len(selections) == 10:
                    break
        if not found:
            raise ValueError(f'insufficient independent annotated blocks for {group}')
        position += 1
    return selections


def prepare(root):
    metadata = root / 'corpus' / 'annotations.json'
    fetch(f'{DATA}/OmniDocBench_demo.json', metadata)
    fetch(f'{SOURCE}/README.md', root / 'corpus' / 'SOURCE_README.md')
    pages = json.loads(metadata.read_text())
    samples = select_blocks(pages, 'english') + select_blocks(pages, 'chinese')
    mixed = next(
        (dict(sample) for sample in samples
         if re.search(r'[A-Za-z]{3}', get_block(pages[sample['page']], sample['block_id'])['text'])
         and sum(is_cjk(character) for character in
                 get_block(pages[sample['page']], sample['block_id'])['text']) >= 10),
        None,
    )
    if mixed is None:
        raise ValueError('no genuinely mixed-language paragraph selected')
    samples.append({**mixed, 'id': 'special-mixed', 'group': 'special'})
    for degrees in (90, 180, 270):
        samples.append({**samples[10], 'id': f'special-rotate-{degrees}',
                        'group': 'special', 'transform': f'rotate-{degrees}'})
    samples.append({**samples[0], 'id': 'special-two-column', 'group': 'special',
                    'transform': 'two-column', 'second': samples[1]})
    for identifier, base_index, transform in (
        ('blur-english', 0, 'blur'), ('blur-chinese', 10, 'blur'),
        ('contrast-chinese', 10, 'contrast'), ('low-resolution', 0, 'low-resolution'),
    ):
        samples.append({**samples[base_index], 'id': identifier,
                        'group': 'degraded', 'transform': transform})
    samples.append({'id': 'blank', 'group': 'degraded', 'transform': 'blank'})
    indices = sorted({sample['page'] for sample in samples if 'page' in sample}
                     | set(PERFORMANCE_PAGES))
    sources = []
    for index in indices:
        info = pages[index]['page_info']
        filename = info['image_path']
        if Path(filename).name != filename:
            raise ValueError('invalid image path')
        destination = root / 'corpus' / filename
        fetch(f'{DATA}/images/{filename}', destination)
        with Image.open(destination) as image:
            dimensions = image.size
            if image.getexif().get(274, 1) != 1:
                raise ValueError('EXIF orientation requires an explicit annotation transform')
        declared = (info['width'], info['height'])
        transposed_header = dimensions != declared and dimensions == declared[::-1]
        if dimensions != declared and not transposed_header:
            raise ValueError(f'annotation/image size mismatch: {index}')
        for block in page_blocks(pages[index]):
            polygon = block['poly']
            if (min(polygon) < -3 or max(polygon[::2]) > dimensions[0] + 3
                    or max(polygon[1::2]) > dimensions[1] + 3):
                raise ValueError(f'annotation coordinates outside image: {index}')
        sources.append({'page': index, 'url': f'{DATA}/images/{filename}',
                        'sha256': digest(destination), 'bytes': destination.stat().st_size,
                        'annotation_dimensions': declared, 'image_dimensions': dimensions,
                        'transposed_dimension_header': transposed_header,
                        'attributes': info['page_attribute']})
        print(f'prepared source {index}', flush=True)
    manifest = {'source_commit': COMMIT, 'annotations_sha256': digest(metadata),
                'license': 'research-only; no dataset images or text redistributed',
                'selection': 'round-robin source order, first 10 eligible prose blocks per language',
                'quality_samples': samples, 'performance_pages': PERFORMANCE_PAGES,
                'sources': sources, 'profiles': PROFILES}
    write_json(root / 'manifest.json', manifest)
    print(f'frozen {len(samples)} quality samples from {len(sources)} pages', flush=True)


def get_block(page, block_id):
    return next(block for block in page['layout_dets'] if block['anno_id'] == block_id)


def page_blocks(page):
    return [block for block in page['layout_dets'] if 'poly' in block]


def page_image(root, page, profile):
    edge, pixels = PROFILES[profile]
    with Image.open(root / 'corpus' / page['page_info']['image_path']) as opened:
        image = ImageOps.exif_transpose(opened).convert('RGB')
    scale = min(1.0, edge / max(image.size), math.sqrt(pixels / (image.width * image.height)))
    if scale < 1:
        resized = image.resize((max(1, round(image.width * scale)),
                                max(1, round(image.height * scale))), Image.Resampling.LANCZOS)
        image.close()
        image = resized
    return image, scale


def crop_sample(root, pages, sample, profile):
    page = pages[sample['page']]
    image, scale = page_image(root, page, profile)
    block = get_block(page, sample['block_id'])
    polygon = block['poly']
    box = (max(0, math.floor(min(polygon[::2]) * scale) - 2),
           max(0, math.floor(min(polygon[1::2]) * scale) - 2),
           min(image.width, math.ceil(max(polygon[::2]) * scale) + 2),
           min(image.height, math.ceil(max(polygon[1::2]) * scale) + 2))
    cropped = ImageOps.expand(image.crop(box), border=12, fill='white')
    image.close()
    return cropped, block['text']


def sample_image(root, pages, sample, profile):
    transform = sample['transform']
    if transform == 'blank':
        return Image.new('RGB', (1556, 2200), 'white'), ''
    image, expected = crop_sample(root, pages, sample, profile)
    if transform.startswith('rotate-'):
        changed = image.rotate(int(transform.split('-')[1]), expand=True, fillcolor='white')
    elif transform == 'blur':
        changed = image.filter(ImageFilter.GaussianBlur(1.2))
    elif transform == 'contrast':
        changed = ImageEnhance.Contrast(image).enhance(0.35)
    elif transform == 'low-resolution':
        tiny = image.resize((max(1, image.width // 3), max(1, image.height // 3)),
                            Image.Resampling.BILINEAR)
        changed = tiny.resize(image.size, Image.Resampling.BILINEAR)
        tiny.close()
    elif transform == 'two-column':
        second, second_expected = crop_sample(root, pages, sample['second'], profile)
        changed = Image.new('RGB', (image.width + second.width + 100,
                                   max(image.height, second.height)), 'white')
        changed.paste(image, (0, 0))
        changed.paste(second, (image.width + 100, 0))
        expected += '\n' + second_expected
        second.close()
    else:
        return image, expected
    image.close()
    return changed, expected


def recognize(executable, image, language, root, identifier, psm=3):
    if psm not in (3, 6):
        raise ValueError('unsupported benchmark segmentation mode')
    with tempfile.TemporaryDirectory(prefix='process-', dir=root) as temporary:
        metrics = Path(temporary) / 'metrics.json'
        command = ['/usr/bin/time', '-f',
                   '{"wall_seconds":%e,"user_seconds":%U,"system_seconds":%S,"rss_kib":%M}',
                   '-o', str(metrics), executable, str(image), 'stdout',
                   '-l', language, '--oem', '1', '--psm', str(psm), 'tsv']
        environment = dict(os.environ, OMP_THREAD_LIMIT='2')
        started = time.perf_counter()
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   env=environment, start_new_session=True)
        try:
            output, error = process.communicate(timeout=45)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            output, error = process.communicate()
            return {'state': 'timeout', 'elapsed_seconds': time.perf_counter() - started}, ''
        elapsed = time.perf_counter() - started
        if process.returncode != 0:
            return {'state': 'engine-failed', 'exit_code': process.returncode,
                    'elapsed_seconds': elapsed, 'stderr_bytes': len(error)}, ''
        if len(output) > 8 * 1024 * 1024:
            return {'state': 'output-limit', 'elapsed_seconds': elapsed}, ''
        measured = json.loads(metrics.read_text())
        text, words = parse_tsv(output.decode('utf-8'))
        (root / 'tsv').mkdir(exist_ok=True)
        (root / 'tsv' / f'{identifier}.tsv').write_bytes(output)
        return {'state': 'ok', 'elapsed_seconds': elapsed,
                'peak_rss_mib': measured['rss_kib'] / 1024,
                'cpu_seconds': measured['user_seconds'] + measured['system_seconds'],
                'word_count': words, 'tsv_bytes': len(output), 'stderr_bytes': len(error)}, text


def summary(rows):
    successful = [row for row in rows if row['state'] == 'ok']
    elapsed = sorted(row['elapsed_seconds'] for row in rows)
    quality = [row for row in successful if row.get('expected_characters', 0)]
    return {'runs': len(rows), 'successful': len(successful),
            'median_seconds': statistics.median(elapsed) if elapsed else None,
            'p95_seconds': elapsed[math.ceil(len(elapsed) * 0.95) - 1] if elapsed else None,
            'peak_rss_mib': max((row['peak_rss_mib'] for row in successful), default=None),
            'cer_micro': sum(row['edit_distance'] for row in quality) /
            sum(row['expected_characters'] for row in quality) if quality else None,
            'cer_macro': statistics.mean(row['cer'] for row in quality) if quality else None,
            'blank_false_positives': sum(row.get('word_count', 0) for row in successful
                                         if row.get('id') == 'blank')}


def run(root, executable, repeats, report):
    manifest = json.loads((root / 'manifest.json').read_text())
    metadata = root / 'corpus' / 'annotations.json'
    if digest(metadata) != manifest['annotations_sha256']:
        raise ValueError('annotation hash changed')
    pages = json.loads(metadata.read_text())
    for source in manifest['sources']:
        filename = pages[source['page']]['page_info']['image_path']
        if digest(root / 'corpus' / filename) != source['sha256']:
            raise ValueError('image hash changed')
    language_output = subprocess.check_output([executable, '--list-langs'], text=True)
    if not {'eng', 'chi_sim'}.issubset(set(language_output.splitlines())):
        raise ValueError('required language unavailable')
    images = root / 'inputs'
    images.mkdir(exist_ok=True)
    rows = []
    for profile in PROFILES:
        for sample in manifest['quality_samples']:
            image, expected = sample_image(root, pages, sample, profile)
            path = images / f'{profile}-{sample["id"]}.png'
            dimensions = image.size
            image.save(path)
            image.close()
            source_language = pages[sample['page']]['page_info']['page_attribute']['language'] \
                if 'page' in sample else 'english'
            language = 'eng' if source_language == 'english' else 'chi_sim+eng'
            measured, actual = recognize(executable, path, language, root, path.stem)
            expected_normalized = normalized(expected)
            row = {'phase': 'quality', 'profile': profile, 'id': sample['id'],
                   'group': sample['group'], 'language': language, 'dimensions': dimensions,
                   'image_sha256': digest(path),
                   'expected_sha256': hashlib.sha256(expected.encode()).hexdigest(), **measured}
            if expected_normalized and measured['state'] == 'ok':
                errors = edit_distance(expected_normalized, normalized(actual))
                row.update(expected_characters=len(expected_normalized), edit_distance=errors,
                           cer=errors / len(expected_normalized))
            rows.append(row)
            write_json(root / 'partial-results.json', rows)
        for page_index in manifest['performance_pages']:
            page = pages[page_index]
            started = time.perf_counter()
            image, scale = page_image(root, page, profile)
            path = images / f'{profile}-page-{page_index}.png'
            dimensions = image.size
            image.save(path)
            image.close()
            preparation_seconds = time.perf_counter() - started
            language = 'eng' if page['page_info']['page_attribute']['language'] == 'english' \
                else 'chi_sim+eng'
            for repeat in range(repeats):
                measured, _ = recognize(executable, path, language, root, f'{path.stem}-{repeat}')
                rows.append({'phase': 'page-performance', 'profile': profile,
                             'id': f'page-{page_index}', 'replicate': repeat + 1,
                             'language': language, 'dimensions': dimensions, 'source_scale': scale,
                             'image_sha256': digest(path),
                             'image_preparation_seconds': preparation_seconds, **measured})
                write_json(root / 'partial-results.json', rows)
            print(f'measured {profile} page {page_index}', flush=True)
    summaries = {}
    for profile in PROFILES:
        summaries[profile] = {group: summary([row for row in rows
                                             if row['profile'] == profile and
                                             row.get('group', row['phase']) == group])
                              for group in ('english', 'chinese', 'special', 'degraded',
                                            'page-performance')}
    cpu = next((line.split(':', 1)[1].strip()
                for line in Path('/proc/cpuinfo').read_text().splitlines()
                if line.startswith('model name')), 'unknown')
    language_directory = re.search(r'in "([^"]+)"', language_output)
    if not language_directory:
        raise ValueError('language model directory not reported')
    models = {}
    for language in ('eng', 'chi_sim'):
        path = Path(language_directory.group(1)) / f'{language}.traineddata'
        models[language] = {'sha256': digest(path), 'bytes': path.stat().st_size}
    result = {'status': 'engine-only exploratory benchmark; not F6 application acceptance',
              'measured_at': time.strftime('%Y-%m-%dT%H:%M:%S%z'),
              'environment': {'system': platform.platform(), 'cpu': cpu,
                              'logical_cpus': os.cpu_count(), 'python': platform.python_version(),
                              'executable': str(Path(executable).absolute()),
                              'engine': subprocess.check_output([executable, '--version'],
                                                               stderr=subprocess.STDOUT, text=True),
                              'languages': language_output, 'language_models': models,
                              'omp_thread_limit': 2,
                              'psm': 3, 'oem': 1, 'full_page_repeats': repeats},
              'method': {'cer': 'NFC, remove all Unicode whitespace, preserve case/digits/punctuation',
                         'latency': 'monotonic wall time including subprocess launch, model load, TSV',
                         'rss': 'GNU time maximum RSS of process; excludes app/rasterizer',
                         'p95': 'nearest rank ceil(0.95*n), includes failed elapsed times',
                         'profiles': 'source image downscale caps; never upscale; unknown original DPI',
                         'cache': 'new process per run; OS file cache not flushed',
                         'scope': '30 block/derived samples, not 30 independent pages; no holdout'},
              'manifest': manifest, 'summaries': summaries, 'rows': rows}
    write_json(root / 'results.json', result)
    if report:
        write_json(report, result)
    print(json.dumps(summaries, ensure_ascii=False, indent=2), flush=True)
    if any(row['state'] != 'ok' for row in rows):
        raise SystemExit('at least one OCR invocation failed; retained all outcomes')


def compare_psm(root, executable, report):
    baseline_path = root / 'results.json'
    baseline = json.loads(baseline_path.read_text())
    manifest = baseline['manifest']
    annotations = root / 'corpus' / 'annotations.json'
    if digest(annotations) != manifest['annotations_sha256']:
        raise ValueError('annotation hash changed')
    pages = json.loads(annotations.read_text())
    engine = subprocess.check_output([executable, '--version'], stderr=subprocess.STDOUT, text=True)
    if engine != baseline['environment']['engine']:
        raise ValueError('engine version changed')
    languages = subprocess.check_output([executable, '--list-langs'], text=True)
    directory = re.search(r'in "([^"]+)"', languages)
    if not directory:
        raise ValueError('model directory missing')
    for language, model in baseline['environment']['language_models'].items():
        if digest(Path(directory.group(1)) / f'{language}.traineddata') != model['sha256']:
            raise ValueError('model changed')
    samples = {sample['id']: sample for sample in manifest['quality_samples']}
    rows = []
    previous = [row for row in baseline['rows'] if row['phase'] == 'quality'
                and row['profile'] == 'bounded2200' and row['group'] in ('english', 'chinese')]
    for earlier in previous:
        path = root / 'inputs' / f'bounded2200-{earlier["id"]}.png'
        if digest(path) != earlier['image_sha256']:
            raise ValueError('frozen input changed')
        sample = samples[earlier['id']]
        expected = normalized(get_block(pages[sample['page']], sample['block_id'])['text'])
        measured, actual = recognize(executable, path, earlier['language'], root,
                                     f'psm6-{earlier["id"]}', psm=6)
        row = {'phase': 'psm-comparison', 'profile': 'bounded2200',
               'id': earlier['id'], 'group': earlier['group'],
               'image_sha256': earlier['image_sha256'], **measured}
        if measured['state'] == 'ok':
            errors = edit_distance(expected, normalized(actual))
            row.update(expected_characters=len(expected), edit_distance=errors,
                       cer=errors / len(expected))
        rows.append(row)
    summaries = {group: {'baseline_psm3': summary([row for row in previous if row['group'] == group]),
                         'diagnostic_psm6': summary([row for row in rows if row['group'] == group])}
                 for group in ('english', 'chinese')}
    result = {'status': 'post-baseline development-set diagnostic; not independent acceptance',
              'measured_at': time.strftime('%Y-%m-%dT%H:%M:%S%z'),
              'baseline_sha256': digest(baseline_path),
              'baseline_environment': baseline['environment'],
              'parameters': {'profile': 'bounded2200', 'psm': 6, 'oem': 1,
                             'omp_thread_limit': 2, 'samples': 'same 20 prose blocks'},
              'limitation': 'PSM 6 is for a single uniform text block, not arbitrary full-page layout',
              'summaries': summaries, 'rows': rows}
    write_json(root / 'psm-comparison.json', result)
    if report:
        write_json(report, result)
    print(json.dumps(summaries, ensure_ascii=False, indent=2))
    if any(row['state'] != 'ok' for row in rows):
        raise SystemExit('diagnostic OCR failure; retained all outcomes')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('check', 'prepare', 'run', 'compare-psm'))
    parser.add_argument('--root', type=Path, default=Path('build/ocr-benchmark-2026-11-10'))
    parser.add_argument('--tesseract', default=shutil.which('tesseract'))
    parser.add_argument('--repeats', type=int, default=3)
    parser.add_argument('--report', type=Path)
    arguments = parser.parse_args()
    self_check()
    if arguments.action == 'check':
        print('8 metric/TSV boundary checks passed')
        return
    arguments.root.mkdir(parents=True, exist_ok=True)
    if arguments.action == 'prepare':
        prepare(arguments.root)
    else:
        if not arguments.tesseract or arguments.repeats < 1:
            parser.error('installed tesseract and repeats >= 1 required')
        if arguments.action == 'compare-psm':
            compare_psm(arguments.root, arguments.tesseract, arguments.report)
        else:
            run(arguments.root, arguments.tesseract, arguments.repeats, arguments.report)


if __name__ == '__main__':
    main()
