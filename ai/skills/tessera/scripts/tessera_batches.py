"""Exhaustive, bounded Choice rounds. No retrieval, ranking or network here."""
from copy import deepcopy

# Conservative serialized-byte budget, NOT a tokenizer or claimed token count.
# Both the first pass and every reduction must fit; the provider enforces tokens.
REQUEST_BYTES = 24000
MAX_CALLS = 128
GLOBAL = ("create", "insufficient_evidence")


def subset(context, choices, *, reduction=False, uncertain=False):
    ids = {context["options"][key]["primary"] for key in choices}
    entries = sorted((entry for entry in context["catalog"]["entries"] if entry["id"] in ids), key=lambda entry: entry["id"])
    result = {**context, "catalog": {**context["catalog"],
        "schema": 1, "project": context["catalog"]["project"],
        "scope": [entry["source"] for entry in entries], "entries": entries,
        "coverage": "Complete cards in this partition; other partitions are evaluated separately."},
        "options": {key: deepcopy(context["options"][key]) for key in [*choices, *GLOBAL]},
        "evidence": {**context["evidence"], "selection": {
            "method": "exhaustive-batches-v1", "total_entries": len(context["catalog"]["entries"]),
            "phase": "reduction" if reduction else "partition", "unresolved_partition": uncertain}}}
    result["options"]["create"]["description"] = (
        "None of the implementation proposals in this comparison can meet the task; create is provisional until every partition is evaluated.")
    result["instructions"] = context["instructions"] + (
        " This is a reduction of proposals already selected by the provider. Compare their full contracts; "
        "the offered action is fixed for each proposal. Do not infer confidence from other rounds."
        if reduction else
        " This is one exhaustive partition, not the whole project. Consider every offered action/card pair. "
        "A create answer means no implementation in THIS partition fits, not that none exists elsewhere.")
    if uncertain:
        result["instructions"] += (
            " At least one earlier partition had insufficient evidence. You may select a supported concrete "
            "implementation, but cannot establish that creation is necessary; choose insufficient_evidence instead of create.")
    return result


def pack(context, groups, provider, encoded, *, reduction=False, uncertain=False):
    requests, pending = [], []
    def request(keys):
        return provider.build_request(subset(context, keys, reduction=reduction, uncertain=uncertain))
    for group in groups:
        candidate = pending + group
        if len(candidate) + 2 > 255 or len(encoded(request(candidate))) > REQUEST_BYTES:
            if pending:
                requests.append(request(pending))
                pending = []
            if len(group) + 2 > 255 or len(encoded(request(group))) > REQUEST_BYTES:
                raise ValueError("Una ficha/propuesta excede el presupuesto de petición; no se ha truncado")
        pending += group
    if pending or not requests:
        value = request(pending)
        if len(encoded(value)) > REQUEST_BYTES:
            raise ValueError("Tarea o instrucciones exceden el presupuesto de petición")
        requests.append(value)
    return requests


def plan(context, provider, encoded):
    if len(context["options"]) <= 255:
        direct = provider.build_request(context)
        if len(encoded(direct)) <= REQUEST_BYTES:
            return direct
    groups = [[key for key, option in context["options"].items() if option["primary"] == entry["id"]]
              for entry in sorted(context["catalog"]["entries"], key=lambda entry: entry["id"])]
    requests = pack(context, groups, provider, encoded)
    remaining, bound = len(requests), len(requests)
    while remaining > 1:
        remaining = (remaining + 1) // 2
        bound += remaining
    if bound > MAX_CALLS:
        raise ValueError("Plan excede el máximo de 128 llamadas; no se ha omitido ninguna ficha")
    # Any two finalists must fit together, otherwise a later round could stall.
    # Check the two largest complete proposals with the longest action description.
    def size(key):
        return len(encoded(provider.build_request(subset(context, [key], reduction=True, uncertain=True))))
    largest = sorted((max(group, key=size)
                      for group in groups),
                     key=size, reverse=True)[:2]
    if len(largest) == 2 and len(pack(context, [[key] for key in largest], provider, encoded,
                                     reduction=True, uncertain=True)) != 1:
        raise ValueError("Dos finalistas no caben juntos; no se puede reducir sin truncar contratos")
    return {"schema": 1, "mode": "exhaustive-batches-v1", "request_byte_limit": REQUEST_BYTES,
            "max_calls": bound, "entry_ids": sorted(entry["id"] for entry in context["catalog"]["entries"]),
            "requests": requests}


def run(context, plan, provider, encoded, invoke):
    requests = plan["requests"]
    winners, uncertain, count = [], False, 0
    while True:
        winners = []
        for request in requests:
            if count >= plan["max_calls"]:
                raise ValueError("Plan agotado; decisión incompleta")
            raw, answer = invoke(request, count)
            count += 1
            choice = answer["choice"]
            if choice == "insufficient_evidence":
                uncertain = True
            elif choice != "create":
                winners.append(choice)
        if len(requests) == 1:
            if uncertain and answer["choice"] == "create":
                raise ValueError("Creación global sin evidencia suficiente en todos los lotes")
            return raw, answer, count
        requests = pack(context, [[key] for key in winners], provider, encoded,
                        reduction=True, uncertain=uncertain)
