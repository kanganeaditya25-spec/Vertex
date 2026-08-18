from dataclasses import dataclass
import re

from app.notes.models import NoteModel


@dataclass(frozen=True)
class NoteMetadata:
    plain_text: str
    markdown: str
    word_count: int
    reading_time_minutes: int
    knowledge_score: float


class NoteIntelligenceService:
    """Offline-safe note projections used before optional local AI integrations."""

    def project(self, title: str, blocks: list[dict]) -> NoteMetadata:
        markdown_lines: list[str] = []
        plain_lines: list[str] = []
        for block in sorted(blocks, key=lambda item: item.get("position", 0)):
            content = str(block.get("content", "")).strip()
            block_type = str(block.get("block_type", "paragraph"))
            if block_type == "heading1":
                markdown_lines.append(f"# {content}")
            elif block_type == "heading2":
                markdown_lines.append(f"## {content}")
            elif block_type == "heading3":
                markdown_lines.append(f"### {content}")
            elif block_type == "bullet":
                markdown_lines.append(f"- {content}")
            elif block_type == "numbered":
                markdown_lines.append(f"1. {content}")
            elif block_type == "checklist":
                markdown_lines.append(f"- [{'x' if block.get('checked') else ' '}] {content}")
            elif block_type == "quote":
                markdown_lines.append(f"> {content}")
            elif block_type == "code":
                markdown_lines.extend(["```", content, "```"])
            elif block_type == "divider":
                markdown_lines.append("---")
            else:
                markdown_lines.append(content)
            if content:
                plain_lines.append(content)
        plain_text = "\n".join(plain_lines)
        markdown = "\n\n".join(line for line in markdown_lines if line)
        word_count = len(re.findall(r"\b[\w'-]+\b", f"{title} {plain_text}"))
        reading_time = max(1, round(word_count / 220)) if word_count else 0
        structure_score = min(25, sum(block.get("block_type") in {"heading1", "heading2", "heading3", "checklist", "code"} for block in blocks) * 5)
        content_score = min(50, word_count / 10)
        link_score = min(25, len(blocks) * 1.5)
        return NoteMetadata(plain_text, markdown, word_count, reading_time, round(content_score + structure_score + link_score, 2))

    def search_match(self, note: NoteModel, query: str) -> bool:
        normalized_query = query.casefold().strip()
        haystack = f"{note.title} {note.plain_text} {note.markdown_content} {note.summary}".casefold()
        return bool(normalized_query) and normalized_query in haystack


note_intelligence = NoteIntelligenceService()
