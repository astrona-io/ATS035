# Reusable Question Banks

`assessments/index.yaml` lists banks in teaching order. Each bank uses schema
version 1 and the contract in `schemas/question-bank.schema.json`. This is an
authoring format for future application integration, not an existing Astrona
quiz API. No YAML question file is registered as a Markdown reading.

Banks follow their declared module summaries. Larger domains use an intermediate
checkpoint after the third section and a final domain review; smaller domains
use a final domain review. The index records covered sections and teaching order. Banks contain 5–15 original single-choice
questions, scoped to concepts taught in the course.

## Fields And Rendering

- `id`: stable bank or question identity; preserve it when editing wording.
- `scope`: module, section or domain checkpoint.
- `placement`: relative reading path after which the checkpoint belongs.
- `learning_objective`: the measurable outcome checked by the question.
- `source_readings`: author traceability to the teaching; not learner navigation.
- `prompt`: learner-visible question text.
- `options`: stable option IDs, answer text and per-option feedback.
- `correct_option`: the ID of the single correct option.
- `explanation`: feedback reinforcing the supported answer.

The application should send only the question ID, prompt and option IDs/text to
the learner before submission. Keep `correct_option`, `explanation` and option
explanations on the server until feedback is permitted. Match answers by option
ID, not display position, so a later renderer can shuffle choices safely.

The banks contain answer keys and are public learning material, so this is not
a secure examination bank. Do not treat scores as an official CKS result.

## Hands-On Coverage

This course has 12 ungraded module playgrounds, all on kind, and 24 graded labs (21 on kind, 3 on a qemu VM). Each lab sits right after the reading it practises, with its task before and its solution after. Every lab passed `astrona validate` and `astrona test` on its own runtime, and every playground started with `scripts/ci/test-playground.sh`.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Serve Content With A Minimal Runtime; Build A Minimal Runtime Image |
| 010/02 | Compare Base Images And Move A Workload To The Smaller One; Run A Pod With A Restricted Security Context |
| 010/03 | Pin An Image To The Digest The Node Reports; Choose An Image Pull Policy From What The Node Holds |
| 020/01 | Record The Images That Run In A Namespace; Bind A Package Inventory To A Running Image |
| 020/02 | Record A Structured Package Inventory; Bind An SBOM And A VEX Statement To An Image Digest |
| 020/03 | Diagnose A Failed Image Pull And Record The Resolved Image; Repair Authenticated Image Pulls |
| 030/01 | Enforce An Approved Image Registry; Sign And Verify An Immutable Image |
| 030/02 | Require Image Digests In A Namespace; Combine Registry And Digest Rules In One Admission Policy |
| 030/03 | Make ImagePolicyWebhook Fail Closed; Enforce A Registry Policy And Attach Pull Credentials |
| 040/01 | Lint A Live Deployment With KubeLinter; Analyze And Correct A Workload Security Document |
| 040/02 | Decide A Scan Gate From Scan Results; Scan An Image And Bind The Release Decision |
| 040/03 | Enforce Baseline And Warn On Restricted With Pod Security Admission; Enforce The Restricted Pod Security Standard |
