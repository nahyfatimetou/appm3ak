from __future__ import annotations

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

try:
    from src.predict import infer_priority, map_post_to_legacy, predict_action_plan
except ModuleNotFoundError:
    from predict import infer_priority, map_post_to_legacy, predict_action_plan


class ActionPlanRequest(BaseModel):
    text: str = Field(..., min_length=2, description="User free text")
    contextHint: str | None = Field(default=None, description="post | help | community")
    inputModeHint: str | None = Field(default=None)
    isForAnotherPersonHint: bool | None = Field(default=None)


app = FastAPI(
    title="Community Action Planner API",
    version="0.1.0",
    description="Predict create_post/create_help_request payload hints from free text.",
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/ai/community/action-plan")
def action_plan(payload: ActionPlanRequest) -> dict:
    try:
        prediction = predict_action_plan(
            text=payload.text,
            context_hint=payload.contextHint,
            input_mode_hint=payload.inputModeHint,
            is_for_another_person_hint=payload.isForAnotherPersonHint,
        )
        if prediction.get("action") == "create_post" and prediction.get("legacyType") is None:
            prediction["legacyType"] = map_post_to_legacy(
                prediction.get("postNature"),
                prediction.get("targetAudience"),
            )
        if prediction.get("predictedPriority") is None:
            prediction["predictedPriority"] = infer_priority(payload.text)
        return prediction
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=f"Prediction failed: {exc}") from exc

