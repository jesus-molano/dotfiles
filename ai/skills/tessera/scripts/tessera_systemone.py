"""Shared System One wire contract; no provider selection or credentials here."""
import json
import math
import urllib.error
import urllib.request



def require(condition, message):
    if not condition:
        raise ValueError(message)


def build_request(context, model):
    options = context["options"]
    require(len(options) <= 255,
            "Límite oficial: 255 opciones Choice. No se ha recortado el catálogo")
    return {"model": model,
            "state": {key: context[key] for key in ("task", "catalog", "evidence")},
            "questions": {"decision": {"type": "choice", "instructions": context["instructions"],
                "criteria": {key: option["description"] for key, option in options.items()}}}}


def validate_response(request, response):
    require(isinstance(response, dict) and response.get("model") == request["model"],
            "Modelo inesperado")
    require(isinstance(response.get("answers"), dict)
            and set(response["answers"]) == {"decision"}, "Respuestas incompletas o inesperadas")
    answer = response["answers"]["decision"]
    options = request["questions"]["decision"]["criteria"]
    require(isinstance(answer, dict) and answer.get("type") == "choice"
            and isinstance(answer.get("choice"), str) and answer["choice"] in options, "Choice inválida")
    probabilities = answer.get("probabilities")
    require(isinstance(probabilities, dict) and set(probabilities) == set(options),
            "Distribución incompleta")
    for value in [answer.get("confidence"), *probabilities.values()]:
        require(type(value) in (int, float) and math.isfinite(value) and 0 <= value <= 1,
                "Probabilidad/confianza inválida")
    # The official SDK documents approximate sums. Kev serializes to four
    # decimals and documents a 0.02 wire tolerance. Preserve raw values.
    total = sum(probabilities.values())
    require(abs(total - 1) < 0.02, "Distribución no normalizada")
    require(probabilities[answer["choice"]] >= max(probabilities.values()) - 1e-6,
            "Choice no coincide con la distribución")
    usage = response.get("usage")
    require(isinstance(usage, dict) and all(type(usage.get(k)) is int and usage[k] >= 0
                                          for k in ("input_tokens", "output_tokens")), "Uso inválido")
    return {"choice": answer["choice"], "probabilities": probabilities,
            "confidence": answer["confidence"], "probability_sum": total,
            "model": response["model"], "usage": usage}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Redirección rechazada; no se reenvía la credencial")


class HTTPFailure(ValueError):
    def __init__(self, status, body, label):
        super().__init__(f"{label} HTTP {status}; intento conservado, sin fallback")
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
        raise ValueError("Fallo de transporte; resultado desconocido, sin reintento automático") from None


def parse_response(raw):
    return json.loads(raw)
