"""TypeSafe adapter, verified against docs.typesafe.ai/api on 2026-09-27."""
import os
import tessera_systemone as wire

ID = "typesafe"
ENDPOINT = "https://api.typesafe.ai/v1/systemone"
MODEL = "jev-1.13.0"
parse_response = wire.parse_response
validate_response = wire.validate_response


def endpoint():
    return ENDPOINT


def build_request(context):
    return wire.build_request(context, MODEL)


def check_credentials():
    wire.require(bool(os.environ.get("TYPESAFE_API_KEY")),
                 "Falta TYPESAFE_API_KEY en este proceso; no se llamó a Jev")


def invoke(body):
    check_credentials()
    return wire.invoke(body, endpoint=endpoint(), api_key=os.environ["TYPESAFE_API_KEY"], label="TypeSafe")
