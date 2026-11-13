import argparse
import importlib.metadata
import json
from pathlib import Path
import resource
import time

import soundfile as sf
import mlx.core as mx
from mlx_audio.stt.utils import load_model

parser = argparse.ArgumentParser()
parser.add_argument('--manifest', type=Path, required=True)
parser.add_argument('--model', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
clips = json.loads(args.manifest.read_text())
start = time.perf_counter()
model = load_model(args.model)
mx.eval(model.parameters())
mx.synchronize()
report = dict(model=args.model, loadSeconds=time.perf_counter() - start,
              runtime=importlib.metadata.version('mlx-audio'), measurements=[])
first_audio, _ = sf.read(clips[0]['path'], dtype='float32')
start = time.perf_counter()
model.generate(first_audio, language='Polish', max_tokens=512, temperature=0.0)
mx.synchronize()
report['firstInferenceSeconds'] = time.perf_counter() - start
for repeat in range(2):
    for clip in clips:
        audio, _ = sf.read(clip['path'], dtype='float32')
        mx.synchronize()
        start = time.perf_counter()
        result = model.generate(audio, language='Polish', max_tokens=512, temperature=0.0)
        mx.synchronize()
        report['measurements'].append(dict(id=clip['id'], **{'pass': repeat},
                                           seconds=time.perf_counter() - start, text=result.text))
        args.output.with_suffix('.partial.json').write_text(json.dumps(report, ensure_ascii=False))
        if len(report['measurements']) % 10 == 0:
            print(args.model, len(report['measurements']), flush=True)
report['peakRSSBytes'] = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
report['peakMLXBytes'] = mx.get_peak_memory()
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2))
