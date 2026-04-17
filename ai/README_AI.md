# AI Module - Community Action Planner (V1)

This folder contains a first AI model named **Community Action Planner**.

Goal: from a simple user text, predict an action plan for either:

- `create_post`
- `create_help_request`

The model predicts project-compatible fields and also generates fallback text:

- `generatedContent` (for posts)
- `generatedDescription` (for help requests)

V1.5 additions:

- text cleaning (`lower().strip()`)
- `legacyType` mapping for posts (Flutter compatibility)
- `predictedPriority` heuristic (`high` / `medium`) for help/readiness flows
- robust dataset normalization in training (`fillna`, bool coercion, non-relevant fields -> `none`)

## Structure

```text
ai/
  data/community_action_dataset.csv
  models/
  src/train_model.py
  src/predict.py
  src/app.py
  src/labels.py
  requirements.txt
  README_AI.md
```

## Model / Pipeline (V1)

- `pandas`
- `scikit-learn`
- `TfidfVectorizer`
- `MultiOutputClassifier`
- `RandomForestClassifier`

## Route

Inference API route:

- `POST /ai/community/action-plan`

Payload supports:

- `text`
- `contextHint` (`post` | `help` | `community`, optional)
- `inputModeHint` (optional)
- `isForAnotherPersonHint` (optional boolean)

## Output fields

For posts:

- `postNature`
- `targetAudience`
- `postInputMode`
- `locationSharingMode`
- `dangerLevel`

For help requests:

- `helpType`
- `requesterProfile`
- `helpInputMode`
- `presetMessageKey`

Common:

- `needsAudioGuidance`
- `needsVisualSupport`
- `needsPhysicalAssistance`
- `needsSimpleLanguage`
- `isForAnotherPerson`
- `action`
- `legacyType` (for posts)
- `predictedPriority` (heuristic suggestion)
- `confidence` (nullable in V1)

## Run

From the `ai/` folder:

```bash
pip install -r requirements.txt
python src/validate_dataset.py
python src/train_model.py
uvicorn src.app:app --reload
```

Test example:

```bash
curl -X POST http://127.0.0.1:8000/ai/community/action-plan \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"Je suis bloque devant un trottoir\", \"inputModeHint\":\"voice\", \"isForAnotherPersonHint\": false}"
```

