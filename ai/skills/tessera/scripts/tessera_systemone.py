"""Shared System One wire contract; no provider selection or credentials here."""
import json
import math
import urllib.error
import urllib.request



def require(condition, message):
    if not condition:
        raise ValueError(message)


PROVIDER_USAGES = 3


def provider_card(entry):
    """Card on the wire: every curated field, at most three usage references.

    Usage paths are references the provider cannot open, so a long list only
    costs bytes; `usage_count` keeps how widely the piece is used. The local
    context keeps the complete card.
    """
    card = dict(entry)
    usages = entry.get("usages", [])
    if len(usages) > PROVIDER_USAGES:
        card["usages"] = usages[:PROVIDER_USAGES]
    card["usage_count"] = len(usages)
    return card


def build_request(context, model):
    options = context["options"]
    require(len(options) <= 255,
            "Official limit: 255 Choice options. The catalog was not trimmed")
    return {"model": model,
            "state": {"task": context["task"], "evidence": context["evidence"],
                      "catalog": {**context["catalog"],
                                  "entries": [provider_card(e) for e in context["catalog"]["entries"]]}},
            "questions": {"decision": {"type": "choice", "instructions": context["instructions"],
                "criteria": {key: option["description"] for key, option in options.items()}}}}


def validate_response(request, response):
    require(isinstance(response, dict) and response.get("model") == request["model"],
            "Unexpected model")
    require(isinstance(response.get("answers"), dict)
            and set(response["answers"]) == {"decision"}, "Incomplete or unexpected answers")
    answer = response["answers"]["decision"]
    options = request["questions"]["decision"]["criteria"]
    require(isinstance(answer, dict) and answer.get("type") == "choice"
            and isinstance(answer.get("choice"), str) and answer["choice"] in options, "Invalid choice")
    probabilities = answer.get("probabilities")
    require(isinstance(probabilities, dict) and set(probabilities) == set(options),
            "Incomplete distribution")
    for value in [answer.get("confidence"), *probabilities.values()]:
        require(type(value) in (int, float) and math.isfinite(value) and 0 <= value <= 1,
                "Invalid probability/confidence")
    # The official SDK documents approximate sums. Kev serializes to four
    # decimals and documents a 0.02 wire tolerance. Preserve raw values.
    total = sum(probabilities.values())
    require(abs(total - 1) < 0.02, "Distribution not normalized")
    require(probabilities[answer["choice"]] >= max(probabilities.values()) - 1e-6,
            "Choice does not match the distribution")
    usage = response.get("usage")
    require(isinstance(usage, dict) and all(type(usage.get(k)) is int and usage[k] >= 0
                                          for k in ("input_tokens", "output_tokens")), "Invalid usage")
    return {"choice": answer["choice"], "probabilities": probabilities,
            "confidence": answer["confidence"], "probability_sum": total,
            "model": response["model"], "usage": usage}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Redirect rejected; the credential is not forwarded")


class HTTPFailure(ValueError):
    def __init__(self, status, body, label):
        super().__init__(f"{label} HTTP {status}; attempt kept, no fallback")
        self.response_bytes = body
        self.http_status = status


def invoke(body, *, endpoint, api_key, label):
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    req = urllib.request.Request(endpoint, data=body, headers=headers, method="POST")
    try:
        with urllib.request.build_opener(NoRedirect).open(req, timeout=30) as stream:
            return stream.read()
    except urllib.error.HTTPError as error:
        raise HTTPFailure(error.code, error.read() if error.fp is not None else b"", label) from None
    except (urllib.error.URLError, TimeoutError):
        raise ValueError("Transport failure; unknown result, no automatic retry") from None


def parse_response(raw):
    return json.loads(raw)
