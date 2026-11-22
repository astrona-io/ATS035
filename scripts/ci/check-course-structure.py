#!/usr/bin/env python3
"""Check course registration, lab boundaries and local runtime references."""
from collections import Counter
import importlib.util
from pathlib import Path
import re
import sys

import yaml

ROOT = Path(__file__).resolve().parents[2]
SHARED = Path(__file__).resolve().parent / "lab-files"
# Files every module lab carries unchanged; the key is the path inside the lab.
SHARED_FILES = {
    "testing/check.py": "check.py",
    "testing/verify-start.sh": "verify-start.sh",
    "testing/wait-solved.sh": "wait-solved.sh",
}
# A qemu lab runs the same scripts inside its VM through the generated vm/
# wrappers (scripts/ci/vm-lab.py), so config.yaml names those instead.
VM_LIFECYCLE = ["vm/verify-start.sh", "vm/apply-solution.sh", "vm/wait-solved.sh"]
spec = importlib.util.spec_from_file_location("vm_lab", Path(__file__).with_name("vm-lab.py"))
vm_lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm_lab)
errors = []


def require(condition, message):
    if not condition:
        errors.append(message)


def read_yaml(path):
    try:
        return yaml.safe_load(path.read_text())
    except (OSError, yaml.YAMLError) as error:
        errors.append(f"{path.relative_to(ROOT)}: {error}")
        return {}


outline = read_yaml(ROOT / "astrona.yaml")
registered = []
for section in outline.get("modules", []):
    content = section.get("content", [])
    for index, item in enumerate(content):
        path = item.get("path", "")
        require(bool(path) and (ROOT / path).exists(), f"Missing course path: {path}")
        if item.get("type") != "lab":
            continue
        registered.append(path)
        require(index > 0 and content[index - 1].get("path") == path + "/question.md",
                f"{path}: lab must follow its question reading")
        require("/module-" in path, f"{path}: every lab belongs to a module")
        require(index > 1 and content[index - 2].get("type") == "reading",
                f"{path}: lab needs a preparation reading")
        if index < 2:
            continue
        lesson = content[index - 2].get("path", "")
        module = str(Path(path).parent.parent)
        require(lesson.startswith(module + "/course-0") and not lesson.endswith("course-000.md"),
                f"{path}: place the lab immediately after its module's preparation lesson")
        question = ROOT / path / "question.md"
        if question.is_file():
            tasks = re.findall(r"^\d+\.\s+", question.read_text(), re.M)
            require(2 <= len(tasks) <= 5, f"{path}: expected 2–5 tasks, found {len(tasks)}")

counts = Counter(registered)
for path, count in counts.items():
    require(count == 1, f"Duplicate lab registration: {path}")

runtime_names = {}
module_labs = 0
for config in sorted((ROOT / "sections").rglob("config.yaml")):
    environment = config.parent
    if environment.name != "playground" and environment.parent.name != "labs":
        continue
    relative = str(environment.relative_to(ROOT))
    data = read_yaml(config)
    name = data.get("metadata", {}).get("name")
    require(bool(name), f"{relative}: missing runtime name")
    require(name not in runtime_names,
            f"{relative}: runtime name {name} also used by {runtime_names.get(name)}")
    runtime_names[name] = relative
    if environment.parent.name == "labs":
        require(relative in counts, f"Unregistered lab: {relative}")
        validation = data.get("validation", {})
        require(bool(validation.get("scripts") or validation.get("script")), f"{relative}: no graders")
        require(bool(data.get("testing", {}).get("init")), f"{relative}: no reference lifecycle")
        if "/module-" in relative:
            # Module labs are exam-ready: one grader per outcome, each with
            # points, and the starting state is checked before the solution.
            module_labs += 1
            scripts = validation.get("scripts") or []
            require(bool(scripts) and all(item.get("points") for item in scripts),
                    f"{relative}: one grader per outcome, each with points")
            steps = [item.get("source") for item in data.get("testing", {}).get("init", [])]
            qemu = data.get("runtime", {}).get("type") == "qemu"
            if qemu:
                require(steps == VM_LIFECYCLE, f"{relative}: testing.init of a qemu lab must be {VM_LIFECYCLE}")
                require([item.get("source") for item in data.get("bootstrap", {}).get("init", [])] == ["vm/install.sh"],
                        f"{relative}: bootstrap.init of a qemu lab must be vm/install.sh")
            else:
                require(bool(steps) and steps[0] == "testing/verify-start.sh",
                        f"{relative}: verify the starting state before the solution")
            wrapper = (SHARED / "validate-outcome.sh").read_bytes()
            for grader in scripts:
                source = f'{"vm" if qemu else "validation"}/validate-{grader.get("name")}.sh'
                require(grader.get("source") == source, f"{relative}: grader {grader.get('name')} must use {source}")
                own = environment / f'validation/validate-{grader.get("name")}.sh'
                require(own.is_file() and own.read_bytes() == wrapper,
                        f"{relative}: {own.relative_to(environment)} differs from scripts/ci/lab-files/validate-outcome.sh")
            for path, shared in SHARED_FILES.items():
                own = environment / path
                require(own.is_file() and own.read_bytes() == (SHARED / shared).read_bytes(),
                        f"{relative}: {path} differs from scripts/ci/lab-files/{shared}")
            question = environment / "question.md"
            require(question.is_file() and re.search(r"^Allow about \d+ minutes for the tasks\.", question.read_text(), re.M),
                    f"{relative}: question.md needs \"Allow about N minutes for the tasks.\"")
            if qemu and vm_lab.stale(environment):
                errors.append(f"{relative}: stale {vm_lab.stale(environment)}; run python3 scripts/ci/vm-lab.py {relative}")
    for value in data.get("metadata", {}).get("docs", {}).values():
        require((environment / value).is_file(), f"{relative}: missing document {value}")

    def check_sources(value):
        if isinstance(value, dict):
            if value.get("type") == "file" and "source" in value:
                require((environment / value["source"]).is_file(),
                        f"{relative}: missing source {value['source']}")
            for child in value.values():
                check_sources(child)
        elif isinstance(value, list):
            for child in value:
                check_sources(child)

    check_sources(data)

for quiz in (ROOT / "sections").rglob("*quiz.yaml"):
    for question in read_yaml(quiz).get("questions", []):
        for reading in question.get("source_readings", []):
            require((ROOT / reading).is_file(), f"{quiz.relative_to(ROOT)}: missing reading {reading}")

if errors:
    print("\n".join(f"FAIL: {error}" for error in errors))
    sys.exit(1)
print(f"PASS: {len(registered)} registered labs, {module_labs} module labs, {len(runtime_names)} unique environments")
