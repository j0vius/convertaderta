from typing import Optional


def parse_duration(value: str) -> Optional[int]:
    trimmed = value.strip()
    if not trimmed:
        return None

    parts = trimmed.split(":")
    try:
        numbers = [int(part) for part in parts]
    except ValueError:
        return None

    if len(numbers) == 2:
        minutes, seconds = numbers
        return minutes * 60 + seconds
    if len(numbers) == 3:
        hours, minutes, seconds = numbers
        return hours * 3600 + minutes * 60 + seconds
    return None
