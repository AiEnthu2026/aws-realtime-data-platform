import json
import pathlib

import pytest

EVENTS = pathlib.Path(__file__).parent / "events"


def load_event(name):
    return json.loads((EVENTS / name).read_text())


class FakeAthena:
    def __init__(self):
        self.started = []

    def start_query_execution(self, **kwargs):
        self.started.append(kwargs)
        return {"QueryExecutionId": "q1"}

    def get_query_execution(self, QueryExecutionId):
        return {"QueryExecution": {"Status": {"State": "SUCCEEDED"}}}

    def get_query_results(self, QueryExecutionId):
        return {"ResultSet": {"Rows": [
            {"Data": [{"VarCharValue": "vehicle_id"}, {"VarCharValue": "route_id"}, {"VarCharValue": "metres"}]},
            {"Data": [{"VarCharValue": "v1"}, {"VarCharValue": "r1"}, {"VarCharValue": "74.0"}]},
        ]}}


@pytest.fixture
def fake_athena(api, monkeypatch):
    fake = FakeAthena()
    monkeypatch.setattr(api, "athena", fake)
    return fake


def test_near_valid_returns_buses_with_int_metres(api, fake_athena):
    result = api.lambda_handler(load_event("near_valid.json"), None)

    assert result["statusCode"] == 200
    assert json.loads(result["body"]) == {"buses": [{"vehicle_id": "v1", "route_id": "r1", "metres": 74}]}
    assert fake_athena.started[0]["ExecutionParameters"] == ["-33.8732", "151.2069", "-33.8732", "151.2069", "300"]


def test_outside_sydney_is_400_and_never_queries(api, fake_athena):
    result = api.lambda_handler(load_event("near_outside_sydney.json"), None)

    assert result["statusCode"] == 400
    assert fake_athena.started == []


def test_unknown_route_is_404(api, fake_athena):
    result = api.lambda_handler(load_event("no_route.json"), None)

    assert result["statusCode"] == 404
    assert fake_athena.started == []


def test_timeout_stops_query_and_returns_504(api, fake_athena, monkeypatch):
    stopped = []
    monkeypatch.setattr(api, "POLL_SECONDS", 0)
    fake_athena.stop_query_execution = lambda QueryExecutionId: stopped.append(QueryExecutionId)

    result = api.lambda_handler({"routeKey": "GET /buses/cbd"}, None)

    assert result["statusCode"] == 504
    assert stopped == ["q1"]


@pytest.mark.parametrize("qs", [
    {"lat": "-33.87"},
    {"lat": "abc", "lon": "151.2"},
    {"lat": "-33.87", "lon": "151.2", "radius_m": "5000"},
])
def test_near_params_rejects_bad_input(api, qs):
    with pytest.raises(ValueError):
        api.near_params(qs)