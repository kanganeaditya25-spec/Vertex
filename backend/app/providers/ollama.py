from dataclasses import dataclass
import json
from urllib.error import URLError
from urllib.request import Request, urlopen


class LocalAIUnavailable(RuntimeError):
    """Raised when the local Ollama runtime cannot be reached."""


@dataclass(frozen=True)
class OllamaProvider:
    base_url: str = "http://127.0.0.1:11434"
    model: str = "gemma3"
    timeout_seconds: float = 3.0

    def is_available(self) -> bool:
        request = Request(f"{self.base_url.rstrip('/')}/api/tags", method="GET")
        try:
            with urlopen(request, timeout=self.timeout_seconds) as response:
                return response.status == 200
        except (OSError, URLError):
            return False

    def generate(self, prompt: str) -> str:
        if not self.is_available():
            raise LocalAIUnavailable(
                "Ollama is not running. Start the local Ollama runtime or use the non-AI fallback."
            )

        payload = json.dumps({"model": self.model, "prompt": prompt, "stream": False}).encode()
        request = Request(
            f"{self.base_url.rstrip('/')}/api/generate",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urlopen(request, timeout=60) as response:
                body = json.loads(response.read().decode())
                return str(body.get("response", "")).strip()
        except (OSError, URLError, json.JSONDecodeError) as error:
            raise LocalAIUnavailable("The local Ollama request failed.") from error
