from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import joblib
import pandas as pd

try:
    from src.labels import BOOL_COLUMNS, HELP_ONLY_COLUMNS, POST_ONLY_COLUMNS
except ModuleNotFoundError:
    from labels import BOOL_COLUMNS, HELP_ONLY_COLUMNS, POST_ONLY_COLUMNS


ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "models" / "community_action_planner.joblib"

POST_INPUT_MODES = {"keyboard", "voice", "headEyes", "vibration", "deafBlind", "caregiver"}
HELP_INPUT_MODES = {"text", "voice", "tap", "haptic", "volume_shortcut", "caregiver"}


def _to_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    s = str(value).strip().lower()
    return s in {"1", "true", "yes", "y"}


def _build_feature_text(
    text: str,
    input_mode_hint: str | None = None,
    is_for_another_person_hint: bool | None = None,
) -> str:
    clean_text = text.lower().strip()
    mode = (input_mode_hint or "").strip()
    hint = "unknown" if is_for_another_person_hint is None else ("yes" if is_for_another_person_hint else "no")
    return f"{clean_text} | input_mode_hint:{mode} | for_another_person_hint:{hint}"


def _load_artifact() -> dict[str, Any]:
    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Model not found at {MODEL_PATH}. Run: python src/train_model.py"
        )
    return joblib.load(MODEL_PATH)


def _generated_post_text(pred: dict[str, Any], original_text: str) -> str:
    return (
        f"[{pred['postNature']}] {original_text.strip()} "
        f"(audience={pred['targetAudience']}, danger={pred['dangerLevel']})"
    ).strip()


def _generated_help_description(pred: dict[str, Any], original_text: str) -> str:
    return (
        f"Besoin d'aide ({pred['helpType']}) : {original_text.strip()} "
        f"(profil={pred['requesterProfile']}, preset={pred['presetMessageKey']})"
    ).strip()


def map_post_to_legacy(post_nature: str | None, target_audience: str | None) -> str:
    if target_audience == "motor":
        return "handicapMoteur"
    if target_audience == "visual":
        return "handicapVisuel"
    if target_audience == "hearing":
        return "handicapAuditif"
    if target_audience == "cognitive":
        return "handicapCognitif"
    if post_nature == "conseil":
        return "conseil"
    if post_nature == "temoignage":
        return "temoignage"
    return "general"


def infer_priority(text: str) -> str:
    t = text.lower().strip()
    critical_tokens = {"critical", "critique", "urgence medicale", "medical urgent", "respire plus", "inconscient"}
    high_tokens = {"bloqué", "bloquee", "bloque", "bklé", "bklee", "urgent", "urgence", "danger"}
    low_tokens = {"conseil", "information", "info", "astuce", "tips"}
    if any(tok in t for tok in critical_tokens):
        return "critical"
    if any(tok in t for tok in high_tokens):
        return "high"
    if any(tok in t for tok in low_tokens):
        return "low"
    return "medium"


def infer_recommended_route(
    action: str,
    post_input_mode: str | None,
    help_input_mode: str | None,
) -> tuple[str, str, float]:
    post_mode = (post_input_mode or "").strip()
    help_mode = (help_input_mode or "").strip()

    if action == "create_post":
        if post_mode == "headEyes":
            return (
                "/create-post-head-gesture",
                "Mode headEyes detecte: parcours tete/yeux recommande.",
                0.92,
            )
        if post_mode in {"vibration", "deafBlind"}:
            return (
                "/create-post-vibration",
                "Mode vibration/deafBlind detecte: parcours vibration recommande.",
                0.92,
            )
        if post_mode == "voice":
            return (
                "/create-post-voice-vibration",
                "Mode voice detecte: parcours voix + vibration recommande.",
                0.9,
            )
        return (
            "/create-post",
            "Parcours post standard recommande pour ce profil.",
            0.75,
        )

    if help_mode == "haptic":
        return (
            "/haptic-help",
            "Mode haptic detecte: parcours aide haptique recommande.",
            0.9,
        )
    return (
        "/create-help-request",
        "Parcours demande d'aide standard recommande.",
        0.75,
    )


def predict_action_plan(
    text: str,
    context_hint: str | None = None,
    input_mode_hint: str | None = None,
    is_for_another_person_hint: bool | None = None,
) -> dict[str, Any]:
    artifact = _load_artifact()
    vec = artifact["vectorizer"]
    clf = artifact["classifier"]
    label_columns = artifact["label_columns"]

    clean_text = text.lower().strip()
    feature_text = _build_feature_text(clean_text, input_mode_hint, is_for_another_person_hint)
    X = vec.transform([feature_text])
    pred = clf.predict(X)[0]
    out: dict[str, Any] = dict(zip(label_columns, pred))

    for c in BOOL_COLUMNS:
        out[c] = _to_bool(out[c])

    action = out["actionType"]
    hint_ctx = (context_hint or "").strip().lower()
    if hint_ctx == "post":
        action = "create_post"
    elif hint_ctx == "help":
        action = "create_help_request"

    out["action"] = action
    # API contract: expose one action field only.
    out.pop("actionType", None)
    hint = (input_mode_hint or "").strip()

    if action == "create_post":
        for c in HELP_ONLY_COLUMNS:
            out[c] = None
        if hint in POST_INPUT_MODES:
            out["postInputMode"] = hint
        out["generatedContent"] = _generated_post_text(out, clean_text)
        out["generatedDescription"] = None
        out["legacyType"] = map_post_to_legacy(out.get("postNature"), out.get("targetAudience"))
    else:
        for c in POST_ONLY_COLUMNS:
            out[c] = None
        if hint in HELP_INPUT_MODES:
            out["helpInputMode"] = hint
        out["generatedDescription"] = _generated_help_description(out, clean_text)
        out["generatedContent"] = None
        out["legacyType"] = None

    out["predictedPriority"] = infer_priority(clean_text)

    if is_for_another_person_hint is not None:
        out["isForAnotherPerson"] = bool(is_for_another_person_hint)

    route, route_reason, route_confidence = infer_recommended_route(
        action=action,
        post_input_mode=out.get("postInputMode"),
        help_input_mode=out.get("helpInputMode"),
    )
    out["recommendedRoute"] = route
    out["routeReason"] = route_reason
    out["confidence"] = route_confidence

    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Predict Community Action Plan from text.")
    parser.add_argument("--text", required=True, help="User free text.")
    parser.add_argument("--inputModeHint", default=None, help="Optional input mode hint.")
    parser.add_argument("--contextHint", default=None, help="Optional context hint: post/help/community.")
    parser.add_argument(
        "--isForAnotherPersonHint",
        default=None,
        help="Optional boolean hint: true/false",
    )
    args = parser.parse_args()

    hint_bool = None
    if args.isForAnotherPersonHint is not None:
        hint_bool = _to_bool(args.isForAnotherPersonHint)

    result = predict_action_plan(
        text=args.text,
        context_hint=args.contextHint,
        input_mode_hint=args.inputModeHint,
        is_for_another_person_hint=hint_bool,
    )
    print(pd.Series(result).to_json(force_ascii=False, indent=2))


if __name__ == "__main__":
    main()

