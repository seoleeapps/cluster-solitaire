class_name FaHttp
extends Node
## 어댑터의 HTTP 요청을 보낸다. 요청마다 HTTPRequest 하나를 만들어 쓰고 끝나면 지운다.
## 주소에 비밀값이 들어갈 수 있으므로 주소와 응답을 출력하지 않는다.
##
## 요청: {"method": "GET" 또는 "POST", "url", "body"(POST만), "timeout"(초), "max_bytes"(응답 크기 상한)}
## 결과: {"ok": 응답을 받았는지, "status": HTTP 상태(받지 못했으면 0), "text": 응답 본문}

const DEFAULT_TIMEOUT_SECONDS := 10.0
const DEFAULT_MAX_BYTES := 64 * 1024


func send(request: Dictionary, on_done: Callable) -> void:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = float(request.get("timeout", DEFAULT_TIMEOUT_SECONDS))
	http.body_size_limit = int(request.get("max_bytes", DEFAULT_MAX_BYTES))
	add_child(http)
	http.request_completed.connect(
		func(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			var ok: bool = result == HTTPRequest.RESULT_SUCCESS
			on_done.call({"ok": ok, "status": status if ok else 0, "text": body.get_string_from_utf8() if ok else ""}),
		CONNECT_ONE_SHOT)
	var post: bool = str(request.get("method", "GET")) == "POST"
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"]) if post else PackedStringArray()
	var error: Error = http.request(
		str(request.get("url", "")), headers,
		HTTPClient.METHOD_POST if post else HTTPClient.METHOD_GET,
		str(request.get("body", "")) if post else "")
	if error != OK:
		http.queue_free()
		on_done.call({"ok": false, "status": 0, "text": ""})
