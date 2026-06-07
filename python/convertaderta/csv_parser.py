from __future__ import annotations

from .models import DjayTrack


class CsvParserError(Exception):
    pass


class DjayCsvParser:
    def parse_file(self, path: str) -> list[DjayTrack]:
        with open(path, encoding="utf-8-sig") as handle:
            return self.parse_content(handle.read())

    def parse_content(self, content: str) -> list[DjayTrack]:
        if content.startswith("\ufeff"):
            content = content[1:]

        rows = self._parse_rows(content)
        if not rows:
            raise CsvParserError("The CSV file is empty.")

        header = [cell.strip() for cell in rows[0]]
        if len(header) < 7 or header[0].lower() != "title" or header[6].lower() != "url":
            raise CsvParserError("The CSV header does not match the expected djay Pro format.")

        tracks: list[DjayTrack] = []
        for row in rows[1:]:
            if len(row) < 7:
                continue
            title = row[0].strip()
            artist = row[1].strip()
            if not title and not artist:
                continue
            tracks.append(
                DjayTrack(
                    title=title,
                    artist=artist,
                    album=row[2].strip(),
                    time=row[3].strip(),
                    bpm=row[4].strip(),
                    key=row[5].strip(),
                    url=row[6].strip(),
                )
            )

        if not tracks:
            raise CsvParserError("No tracks were found in the CSV file.")
        return tracks

    def _parse_rows(self, content: str) -> list[list[str]]:
        rows: list[list[str]] = []
        current_row: list[str] = []
        current_field: list[str] = []
        in_quotes = False
        index = 0

        while index < len(content):
            char = content[index]

            if in_quotes:
                if char == '"':
                    if index + 1 < len(content) and content[index + 1] == '"':
                        current_field.append('"')
                        index += 2
                        continue
                    in_quotes = False
                else:
                    current_field.append(char)
            elif char == '"':
                in_quotes = True
            elif char == ",":
                current_row.append("".join(current_field))
                current_field = []
            elif char == "\n":
                current_row.append("".join(current_field))
                current_field = []
                if any(cell for cell in current_row):
                    rows.append(current_row)
                current_row = []
            elif char != "\r":
                current_field.append(char)

            index += 1

        if current_field or current_row:
            current_row.append("".join(current_field))
            if any(cell for cell in current_row):
                rows.append(current_row)

        return rows
