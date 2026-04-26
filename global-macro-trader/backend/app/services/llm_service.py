import json
import logging
from typing import Optional

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

CURRENCIES = ["USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF"]

SYSTEM_PROMPT = """You are a macro FX analyst. Given a list of recent financial news headlines,
determine:
1) The risk regime: RISK_ON (markets bullish, AUD/NZD/GBP strong, JPY/CHF weak),
   RISK_OFF (markets bearish, JPY/CHF/USD strong, AUD/NZD weak), or NEUTRAL.
2) Currency strength scores from -1.0 (very weak) to +1.0 (very strong) for:
   USD, EUR, GBP, JPY, AUD, NZD, CAD, CHF.
3) A one-sentence summary of the macro environment.
4) The single most important driver (e.g., "Fed rate expectations", "China growth fears").

Respond ONLY with valid JSON matching exactly this schema:
{
  "risk_regime": "RISK_ON" | "RISK_OFF" | "NEUTRAL",
  "currency_scores": {"USD": float, "EUR": float, "GBP": float, "JPY": float, "AUD": float, "NZD": float, "CAD": float, "CHF": float},
  "summary": "string",
  "driver": "string"
}"""


class LLMService:
    def _fallback_analysis(self, reason: str = "LLM unavailable") -> dict:
        return {
            "risk_regime": "NEUTRAL",
            "currency_scores": {c: 0.0 for c in CURRENCIES},
            "summary": f"Neutral analysis applied — {reason}",
            "driver": reason,
        }

    def analyze(self, news_items: list[dict]) -> dict:
        if not settings.llm_api_key:
            return self._fallback_analysis("No LLM API key configured")

        headlines = "\n".join(
            f"- {item['title']} ({item.get('source', 'unknown')})"
            for item in news_items[:50]
        )
        user_message = f"Analyze these headlines:\n{headlines}"

        try:
            if settings.llm_provider == "openai":
                return self._call_openai(user_message)
            elif settings.llm_provider == "anthropic":
                return self._call_anthropic(user_message)
            else:
                return self._fallback_analysis(f"Unknown provider: {settings.llm_provider}")
        except Exception as exc:
            logger.error("LLM analysis failed: %s", exc)
            return self._fallback_analysis(f"LLM error: {type(exc).__name__}")

    def _call_openai(self, user_message: str) -> dict:
        with httpx.Client(timeout=30.0) as client:
            resp = client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {settings.llm_api_key}"},
                json={
                    "model": settings.llm_model,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": user_message},
                    ],
                    "temperature": 0.3,
                    "response_format": {"type": "json_object"},
                },
            )
            resp.raise_for_status()
            content = resp.json()["choices"][0]["message"]["content"]
            return self._parse_response(content)

    def _call_anthropic(self, user_message: str) -> dict:
        with httpx.Client(timeout=30.0) as client:
            resp = client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": settings.llm_api_key,
                    "anthropic-version": "2023-06-01",
                },
                json={
                    "model": settings.llm_model,
                    "max_tokens": 1024,
                    "system": SYSTEM_PROMPT,
                    "messages": [{"role": "user", "content": user_message}],
                },
            )
            resp.raise_for_status()
            content = resp.json()["content"][0]["text"]
            return self._parse_response(content)

    def _parse_response(self, content: str) -> dict:
        data = json.loads(content)
        regime = data.get("risk_regime", "NEUTRAL")
        if regime not in ("RISK_ON", "RISK_OFF", "NEUTRAL"):
            regime = "NEUTRAL"
        scores = data.get("currency_scores", {})
        # Ensure all currencies present, clamp to [-1, 1]
        for c in CURRENCIES:
            scores[c] = max(-1.0, min(1.0, float(scores.get(c, 0.0))))
        return {
            "risk_regime": regime,
            "currency_scores": scores,
            "summary": str(data.get("summary", "")),
            "driver": str(data.get("driver", "")),
        }


llm_service = LLMService()
