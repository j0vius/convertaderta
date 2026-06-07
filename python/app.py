from __future__ import annotations

import os
import subprocess
import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from convertaderta.models import ConversionProgress, ConversionResult, DjayTrack
from convertaderta.music_import import MusicImportError, MusicPlaylistBuilder
from convertaderta.playlist_converter import PlaylistConverter


class ConvertadertaApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("convertaderta")
        self.geometry("820x620")
        self.minsize(720, 520)

        self.converter = PlaylistConverter()
        self.music_builder = MusicPlaylistBuilder()
        self.csv_path: str | None = None
        self.tracks: list[DjayTrack] = []
        self.conversion_result: ConversionResult | None = None
        self.is_busy = False

        self._build_ui()

    def _build_ui(self) -> None:
        root = ttk.Frame(self, padding=16)
        root.pack(fill=tk.BOTH, expand=True)

        header = ttk.Frame(root)
        header.pack(fill=tk.X, pady=(0, 12))

        ttk.Label(header, text="convertaderta", font=("Helvetica", 24, "bold")).pack(anchor=tk.W)
        ttk.Label(
            header,
            text="Convert djay Pro CSV playlists to M3U8 for local music files.",
        ).pack(anchor=tk.W)

        actions = ttk.Frame(root)
        actions.pack(fill=tk.X, pady=(0, 12))

        self.open_button = ttk.Button(actions, text="Open CSV…", command=self.open_csv)
        self.open_button.pack(side=tk.LEFT)

        self.convert_button = ttk.Button(actions, text="Convert", command=self.convert, state=tk.DISABLED)
        self.convert_button.pack(side=tk.LEFT, padx=(8, 0))

        self.file_label = ttk.Label(root, text="No CSV loaded")
        self.file_label.pack(anchor=tk.W)

        self.progress_frame = ttk.LabelFrame(root, text="Progress", padding=10)
        self.progress_var = tk.DoubleVar(value=0.0)
        self.progress_bar = ttk.Progressbar(
            self.progress_frame,
            variable=self.progress_var,
            maximum=100,
            mode="determinate",
        )
        self.progress_phase = ttk.Label(self.progress_frame, text="")
        self.progress_detail = ttk.Label(self.progress_frame, text="", wraplength=760)

        self.table = ttk.Treeview(
            root,
            columns=("title", "artist", "status"),
            show="headings",
            height=12,
        )
        self.table.heading("title", text="Title")
        self.table.heading("artist", text="Artist")
        self.table.heading("status", text="Status")
        self.table.column("title", width=280)
        self.table.column("artist", width=220)
        self.table.column("status", width=100)
        self.table.pack(fill=tk.BOTH, expand=True, pady=(12, 12))

        self.results_frame = ttk.LabelFrame(root, text="Conversion complete", padding=10)
        self.results_summary = ttk.Label(self.results_frame, text="")
        self.results_path = ttk.Label(self.results_frame, text="", wraplength=760)
        self.results_buttons = ttk.Frame(self.results_frame)

        self.reveal_button = ttk.Button(
            self.results_buttons,
            text="Reveal in Explorer" if sys.platform == "win32" else "Reveal in Finder",
            command=self.reveal_output,
            state=tk.DISABLED,
        )
        self.import_button = ttk.Button(
            self.results_buttons,
            text="Import to Apple Music",
            command=self.import_to_music,
            state=tk.DISABLED,
        )
        self.reveal_button.pack(side=tk.LEFT)
        self.import_button.pack(side=tk.LEFT, padx=(8, 0))

        self.error_label = ttk.Label(root, text="", foreground="red", wraplength=760)
        self.error_label.pack(anchor=tk.W, pady=(8, 0))

        ttk.Label(
            root,
            text="Matches playlist tracks against your Music library.",
            font=("Helvetica", 10),
        ).pack(anchor=tk.W, pady=(8, 0))

    def open_csv(self) -> None:
        path = filedialog.askopenfilename(
            title="Open djay Pro CSV",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")],
        )
        if not path:
            return
        self.load_csv(path)

    def load_csv(self, path: str) -> None:
        self.error_label.config(text="")
        self._hide_results()
        self._hide_progress()
        self.csv_path = path

        try:
            self.tracks = self.converter.parse_tracks(path)
        except Exception as exc:
            self.tracks = []
            self.error_label.config(text=str(exc))
            self._refresh_table()
            self.convert_button.config(state=tk.DISABLED)
            return

        self.file_label.config(text=f"{Path(path).name} — {len(self.tracks)} tracks loaded")
        self.convert_button.config(state=tk.NORMAL if self.tracks else tk.DISABLED)
        self._refresh_table()

    def convert(self) -> None:
        if not self.csv_path or self.is_busy:
            return

        self.is_busy = True
        self.error_label.config(text="")
        self._hide_results()
        self._show_progress("Starting conversion…", 0)
        self.convert_button.config(state=tk.DISABLED)
        self.open_button.config(state=tk.DISABLED)

        def worker() -> None:
            try:
                result = self.converter.convert(
                    self.csv_path,
                    on_progress=lambda progress: self.after(0, lambda: self._update_progress(progress)),
                )
                warning = self.converter.last_warning
                self.after(0, lambda: self._finish_convert(result, warning))
            except Exception as exc:
                self.after(0, lambda: self._finish_error(str(exc)))

        threading.Thread(target=worker, daemon=True).start()

    def import_to_music(self) -> None:
        if not self.conversion_result or self.is_busy:
            return

        self.is_busy = True
        self._show_progress("Adding tracks to a new playlist in Music…", 50)
        output_path = self.conversion_result.output_path

        def worker() -> None:
            try:
                self.music_builder.import_playlist(output_path)
                self.after(0, self._finish_import)
            except Exception as exc:
                self.after(0, lambda: self._finish_error(str(exc)))

        threading.Thread(target=worker, daemon=True).start()

    def reveal_output(self) -> None:
        if not self.conversion_result:
            return
        path = self.conversion_result.output_path
        folder = str(Path(path).parent)
        if sys.platform == "darwin":
            subprocess.run(["open", "-R", path], check=False)
        elif sys.platform == "win32":
            subprocess.run(["explorer", "/select,", os.path.normpath(path)], check=False)
        else:
            subprocess.run(["xdg-open", folder], check=False)

    def _refresh_table(self) -> None:
        for item in self.table.get_children():
            self.table.delete(item)
        for track in self.tracks:
            self.table.insert("", tk.END, values=(track.title, track.artist, track.status_label))

    def _show_progress(self, detail: str, percent: float) -> None:
        self.progress_frame.pack(fill=tk.X, pady=(0, 12), before=self.table)
        self.progress_bar.pack(fill=tk.X)
        self.progress_phase.pack(anchor=tk.W, pady=(8, 4))
        self.progress_detail.pack(anchor=tk.W)
        self.progress_var.set(percent)
        self.progress_detail.config(text=detail)

    def _update_progress(self, progress: ConversionProgress) -> None:
        self.progress_phase.config(
            text=f"{progress.phase_title} — {progress.percent_label}"
        )
        self.progress_detail.config(text=progress.detail)
        self.progress_var.set(progress.overall_fraction * 100)

    def _hide_progress(self) -> None:
        self.progress_frame.pack_forget()

    def _hide_results(self) -> None:
        self.results_frame.pack_forget()
        self.reveal_button.config(state=tk.DISABLED)
        self.import_button.config(state=tk.DISABLED)

    def _show_results(self, result: ConversionResult) -> None:
        self.conversion_result = result
        self.tracks = result.tracks
        self._refresh_table()
        self.results_summary.config(text=result.summary)
        self.results_path.config(text=f"Saved to {result.output_path}")
        self.results_frame.pack(fill=tk.X, pady=(0, 12))
        self.results_summary.pack(anchor=tk.W)
        self.results_path.pack(anchor=tk.W, pady=(4, 8))
        self.results_buttons.pack(anchor=tk.W)
        self.reveal_button.config(state=tk.NORMAL)
        self.import_button.config(state=tk.NORMAL)

    def _finish_convert(self, result: ConversionResult, warning: str | None) -> None:
        self.is_busy = False
        self._hide_progress()
        self.open_button.config(state=tk.NORMAL)
        self.convert_button.config(state=tk.NORMAL)
        self._show_results(result)
        if warning:
            self.error_label.config(text=warning)

    def _finish_import(self) -> None:
        self.is_busy = False
        self._hide_progress()
        self.open_button.config(state=tk.NORMAL)
        self.convert_button.config(state=tk.NORMAL)

    def _finish_error(self, message: str) -> None:
        self.is_busy = False
        self._hide_progress()
        self.open_button.config(state=tk.NORMAL)
        self.convert_button.config(state=tk.NORMAL)
        self.error_label.config(text=message)


def main() -> None:
    app = ConvertadertaApp()
    app.mainloop()


if __name__ == "__main__":
    main()
