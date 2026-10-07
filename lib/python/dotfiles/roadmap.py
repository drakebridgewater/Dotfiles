#!/usr/bin/env python3
"""SVG Roadmap Generator — Generates roadmap SVGs from JSON layout definitions.

Usage:
    generate_roadmap.py roadmap.json -o roadmap.svg
    generate_roadmap.py --template > roadmap.json
"""

import argparse
import json
import sys
from abc import ABC, abstractmethod
from pathlib import Path

import svgwrite
from svgwrite import Drawing
from svgwrite.container import Group

# ═══════════════════════════════════════════════════════════════════════════════
# Themes
# ═══════════════════════════════════════════════════════════════════════════════

SIEMENS_THEME = {
    "primary_dark": "#004B50",
    "primary": "#007A82",
    "primary_medium": "#00847C",
    "primary_light": "#00A19A",
    "text_dark": "#2D3436",
    "text_heading": "#1A1A2E",
    "text_muted": "#6B7C80",
    "text_secondary": "#8C9EA3",
    "text_complete": "#2D7A75",
    "text_body": "#4A5568",
    "background": "#F7F9FA",
    "card_bg": "#FFFFFF",
    "border": "#DFE6E9",
    "divider": "#E4EAEC",
    "track": "#D5DDE0",
    "upcoming_fill": "#F0F4F5",
    "upcoming_stroke": "#C8D3D6",
    "warning_bg": "#F59E0B",
    "warning_text": "#B45309",
    "withdrawn_stroke": "#B0B8BC",
    "text_withdrawn": "#9CA3AF",
    "font_family": "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif",
}

THEMES = {"siemens": SIEMENS_THEME}


def get_theme(name="siemens", overrides=None):
    theme = dict(THEMES.get(name, SIEMENS_THEME))
    if overrides:
        theme.update(overrides)
    return theme


# ═══════════════════════════════════════════════════════════════════════════════
# Entity Base
# ═══════════════════════════════════════════════════════════════════════════════


class Entity(ABC):
    """Base class for all renderable entities."""

    def __init__(self, data):
        self.data = data

    @abstractmethod
    def render(self, dwg: Drawing, group: Group, x: float, y: float, width: float, theme: dict) -> float:
        """Render this entity and return height consumed."""

    def estimate_height(self, width: float, theme: dict) -> float:
        """Estimate height without rendering (for layout calculations)."""
        return 0


# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════


def add_text(group, x, y, text, font_size=12, fill="#000", font_weight="normal",
             text_anchor="start", letter_spacing=None, font_family=None):
    """Add a text element with common styling."""
    extra = {"style": "white-space: pre;"}
    if letter_spacing:
        extra["letter-spacing"] = str(letter_spacing)
    t = group.add(svgwrite.text.Text(
        text, insert=(x, y),
        fill=fill, font_size=f"{font_size}px", font_weight=str(font_weight),
        text_anchor=text_anchor,
        font_family=font_family,
        **extra
    ))
    return t


def add_checkmark(group, cx, cy, r=6.5, fill="#00847C", check_color="#FFF"):
    """Add a filled circle with a checkmark."""
    group.add(svgwrite.shapes.Circle(center=(cx, cy), r=r, fill=fill))
    # Checkmark path
    x1, y1 = cx - 3.5, cy
    x2, y2 = cx - 1, cy + 2.5
    x3, y3 = cx + 3.5, cy - 2.5
    group.add(svgwrite.path.Path(
        d=f"M {x1} {y1} L {x2} {y2} L {x3} {y3}",
        stroke=check_color, stroke_width=1.6, fill="none",
        stroke_linecap="round", stroke_linejoin="round"
    ))


def add_open_checkmark(group, cx, cy, r=6.5, stroke="#00847C", stroke_width=1.5, check_color=None):
    """Add an unfilled circle with a checkmark (in-review state)."""
    group.add(svgwrite.shapes.Circle(center=(cx, cy), r=r, fill="none",
                                     stroke=stroke, stroke_width=stroke_width))
    check_color = check_color or stroke
    x1, y1 = cx - 3.5, cy
    x2, y2 = cx - 1, cy + 2.5
    x3, y3 = cx + 3.5, cy - 2.5
    group.add(svgwrite.path.Path(
        d=f"M {x1} {y1} L {x2} {y2} L {x3} {y3}",
        stroke=check_color, stroke_width=1.6, fill="none",
        stroke_linecap="round", stroke_linejoin="round"
    ))


def add_empty_circle(group, cx, cy, r=6.5, stroke="#C8D3D6", stroke_width=1.5):
    """Add an empty circle indicator."""
    group.add(svgwrite.shapes.Circle(center=(cx, cy), r=r, fill="none",
                                     stroke=stroke, stroke_width=stroke_width))


def add_withdrawn_x(group, cx, cy, r=6.5, stroke="#B0B8BC", stroke_width=1.5):
    """Add a circle with an × inside (withdrawn state)."""
    group.add(svgwrite.shapes.Circle(center=(cx, cy), r=r, fill="none",
                                     stroke=stroke, stroke_width=stroke_width))
    d = r * 0.42
    group.add(svgwrite.shapes.Line(
        start=(cx - d, cy - d), end=(cx + d, cy + d),
        stroke=stroke, stroke_width=1.4, stroke_linecap="round"
    ))
    group.add(svgwrite.shapes.Line(
        start=(cx + d, cy - d), end=(cx - d, cy + d),
        stroke=stroke, stroke_width=1.4, stroke_linecap="round"
    ))


def add_badge(group, x, y, text, style="review", theme=None):
    """Add a status badge (pill shape with text)."""
    theme = theme or SIEMENS_THEME
    width = max(50, len(text) * 7 + 16)
    height = 16
    rx = 8

    if style == "review":
        bg_fill = theme["primary_light"]
        bg_opacity = 0.15
        text_fill = theme["primary_medium"]
    elif style == "closed":
        bg_fill = theme["primary_dark"]
        bg_opacity = 0.15
        text_fill = theme["primary_medium"]
    elif style == "opened":
        bg_fill = theme["warning_bg"]
        bg_opacity = 0.15
        text_fill = theme["warning_text"]
    elif style == "withdrawn":
        bg_fill = theme["withdrawn_stroke"]
        bg_opacity = 0.15
        text_fill = theme["text_withdrawn"]
    else:
        bg_fill = theme["upcoming_stroke"]
        bg_opacity = 0.15
        text_fill = theme["text_muted"]

    group.add(svgwrite.shapes.Rect(
        insert=(x, y), size=(width, height), rx=rx, ry=rx,
        fill=bg_fill, opacity=bg_opacity
    ))
    add_text(group, x + width / 2, y + 11, text,
             font_size=9, fill=text_fill, font_weight="600", text_anchor="middle")


def add_legend_arrow(group, x, y, direction="right", length=16, stroke="#8C9EA3", stroke_width=1.4):
    """Add a horizontal arrow connector for legend entries."""
    if direction not in {"left", "right"}:
        direction = "right"

    half = length / 2
    start_x = x - half
    end_x = x + half
    head = min(4.0, length / 3)

    group.add(svgwrite.shapes.Line(
        start=(start_x, y), end=(end_x, y),
        stroke=stroke, stroke_width=stroke_width, stroke_linecap="round"
    ))

    if direction == "right":
        tip_x = end_x
        wing_x = tip_x - head
    else:
        tip_x = start_x
        wing_x = tip_x + head

    group.add(svgwrite.shapes.Line(
        start=(wing_x, y - head), end=(tip_x, y),
        stroke=stroke, stroke_width=stroke_width, stroke_linecap="round"
    ))
    group.add(svgwrite.shapes.Line(
        start=(wing_x, y + head), end=(tip_x, y),
        stroke=stroke, stroke_width=stroke_width, stroke_linecap="round"
    ))


def estimate_legend_text_width(text, char_width=6.0, space_width=3.2):
    """Estimate legend text width with tighter spacing than len(text) * 7."""
    spaces = text.count(" ")
    letters = len(text) - spaces
    return letters * char_width + spaces * space_width


# ═══════════════════════════════════════════════════════════════════════════════
# Entity Implementations
# ═══════════════════════════════════════════════════════════════════════════════


class Header(Entity):
    def estimate_height(self, width, theme):
        return 52

    def render(self, dwg, group, x, y, width, theme):
        h = 52
        # Gradient rect
        grad = dwg.linearGradient((0, 0), (1, 0), id="headerGrad_gen")
        grad.add_stop_color(0, theme["primary_dark"])
        grad.add_stop_color(1, theme["primary"])
        dwg.defs.add(grad)

        group.add(svgwrite.shapes.Rect(
            insert=(x, y), size=(width, h), rx=3, ry=3,
            fill=grad.get_funciri()
        ))
        add_text(group, x + 17, y + 34, self.data["title"],
                 font_size=22, fill="#FFFFFF", font_weight="600",
                 font_family=theme["font_family"])
        return h


class ProgressBar(Entity):
    def estimate_height(self, width, theme):
        return 35

    def render(self, dwg, group, x, y, width, theme):
        label = self.data["label"]
        subtitle = self.data.get("subtitle")
        completed = self.data["completed"]
        total = self.data["total"]
        pct = int(completed / total * 100) if total > 0 else 0

        # Auto-generate subtitle if not provided
        if not subtitle:
            subtitle = f"{completed} of {total} phases complete"

        # Label
        add_text(group, x, y + 12, label,
                 font_size=13, fill=theme["text_dark"], font_weight="600",
                 font_family=theme["font_family"])
        # Subtitle
        add_text(group, x, y + 27, subtitle,
                 font_size=10.5, fill=theme["text_muted"],
                 font_family=theme["font_family"])

        # Track position — offset from label
        track_x = x + 125
        track_w = width - 155
        track_y = y + 4
        track_h = 20

        # Track background
        group.add(svgwrite.shapes.Rect(
            insert=(track_x, track_y), size=(track_w, track_h), rx=10, ry=10,
            fill=theme["divider"]
        ))

        # Fill
        if pct > 0:
            grad_id = f"progressGrad_{id(self)}"
            grad = dwg.linearGradient((0, 0), (1, 0), id=grad_id)
            grad.add_stop_color(0, theme["primary_medium"])
            grad.add_stop_color(1, theme["primary_light"])
            dwg.defs.add(grad)

            fill_w = track_w * pct / 100
            group.add(svgwrite.shapes.Rect(
                insert=(track_x, track_y), size=(fill_w, track_h), rx=10, ry=10,
                fill=grad.get_funciri()
            ))

        # Percentage text
        add_text(group, x + width - 10, y + 19, f"{pct}%",
                 font_size=13, fill=theme["text_dark"], font_weight="700",
                 text_anchor="end", font_family=theme["font_family"])

        return 35


class Spacer(Entity):
    def estimate_height(self, width, theme):
        return self.data.get("height", 10)

    def render(self, dwg, group, x, y, width, theme):
        return self.data.get("height", 10)


class Timeline(Entity):
    def estimate_height(self, width, theme):
        return 65

    def render(self, dwg, group, x, y, width, theme):
        phases = self.data["phases"]
        n = len(phases)
        if n == 0:
            return 0

        margin = 55
        line_y = y + 20
        spacing = (width - 2 * margin) / (n - 1) if n > 1 else 0

        # Background line
        x_start = x + margin
        x_end = x + width - margin
        group.add(svgwrite.shapes.Line(
            start=(x_start, line_y), end=(x_end, line_y),
            stroke=theme["track"], stroke_width=3, stroke_linecap="round"
        ))

        # Progress line (up to last complete phase)
        last_complete_idx = -1
        for i, p in enumerate(phases):
            if p["status"] == "complete":
                last_complete_idx = i

        if last_complete_idx >= 0:
            progress_end = x_start + spacing * last_complete_idx
            group.add(svgwrite.shapes.Line(
                start=(x_start, line_y), end=(progress_end, line_y),
                stroke=theme["primary_medium"], stroke_width=3, stroke_linecap="round"
            ))

        # Phase circles
        for i, phase in enumerate(phases):
            cx = x_start + spacing * i
            cy = line_y
            status = phase["status"]
            number = str(phase["number"])
            phase_group = phase.get("group", "")
            labels = phase.get("label", [])

            if status == "complete":
                group.add(svgwrite.shapes.Circle(center=(cx, cy), r=20, fill=theme["primary_medium"]))
                add_text(group, cx, cy - 5, phase_group,
                         font_size=9, fill="#fff", font_weight="600", text_anchor="middle")
                add_text(group, cx, cy + 7, number,
                         font_size=14, fill="#FFF", font_weight="700", text_anchor="middle")

            elif status == "in_progress":
                # Animated ring
                anim_circle = svgwrite.shapes.Circle(
                    center=(cx, cy), r=26, fill="none",
                    stroke=theme["primary_light"], stroke_width=1.5, opacity=0.3
                )
                anim_circle.add(svgwrite.animate.Animate(
                    attributeName="r", values="24;28;24", dur="2s", repeatCount="indefinite"
                ))
                anim_circle.add(svgwrite.animate.Animate(
                    attributeName="opacity", values="0.3;0.1;0.3", dur="2s", repeatCount="indefinite"
                ))
                group.add(anim_circle)

                group.add(svgwrite.shapes.Circle(
                    center=(cx, cy), r=20, fill="#FFFFFF",
                    stroke=theme["primary_light"], stroke_width=2.5
                ))
                add_text(group, cx, cy - 5, phase_group,
                         font_size=9, fill=theme["primary_medium"], font_weight="600", text_anchor="middle")
                add_text(group, cx, cy + 7, number,
                         font_size=14, fill=theme["primary_medium"], font_weight="700", text_anchor="middle")

            else:  # upcoming
                group.add(svgwrite.shapes.Circle(
                    center=(cx, cy), r=20, fill=theme["upcoming_fill"],
                    stroke=theme["upcoming_stroke"], stroke_width=1.5
                ))
                add_text(group, cx, cy - 5, phase_group,
                         font_size=9, fill=theme["text_secondary"], font_weight="600", text_anchor="middle")
                add_text(group, cx, cy + 7, number,
                         font_size=14, fill=theme["text_secondary"], font_weight="700", text_anchor="middle")

            # Labels below
            for j, lbl in enumerate(labels):
                add_text(group, cx, cy + 36 + j * 12, lbl,
                         font_size=10.5, fill=theme["text_dark"], font_weight="500", text_anchor="middle")

        return 65


def normalize_children(children):
    """Normalize children to list-of-dicts format.

    Accepts either:
      - [{"text": "...", "status": "..."}, ...]   (already normalized)
      - ["status", "text1", "text2", ...]           (shorthand: first element is status)
    """
    if not children:
        return []
    if isinstance(children[0], dict):
        return children
    # Shorthand: first element is the status, rest are text labels
    status = children[0]
    return [{"text": t, "status": status} for t in children[1:]]


class Card(Entity):
    def _calc_height(self, theme):
        items = self.data.get("items", [])
        footer = self.data.get("footer", [])

        # Base: status label + title + divider = 60
        h = 60
        # Items
        for item in items:
            h += 22
            if item.get("reason"):
                h += 14
            children = normalize_children(item.get("children", []))
            h += 18 * len(children)
        # Footer
        h += 14 * len(footer)
        # Bottom padding tuned to keep short cards balanced while reducing large-card tail gaps.
        h += 14
        return h

    def estimate_height(self, width, theme):
        return self._calc_height(theme)

    def render(self, dwg, group, x, y, width, theme):
        data = self.data
        status = data.get("status", "upcoming")
        status_label = data.get("status_label", "")
        title = data.get("title", "")
        items = data.get("items", [])
        footer = data.get("footer", [])
        height = getattr(self, '_override_height', None) or self._calc_height(theme)

        # Determine accent color
        if status == "complete":
            accent = theme["primary_medium"]
        elif status == "in_progress":
            accent = theme["primary_light"]
        else:
            accent = theme["upcoming_stroke"]

        # Card background with shadow
        filter_id = "shadow_gen"
        # Register shadow filter once
        if not hasattr(dwg, '_shadow_registered'):
            f = dwg.defs.add(svgwrite.filters.Filter(id=filter_id, x="-5%", y="-5%", width="110%", height="120%"))
            f.feGaussianBlur(in_="SourceAlpha", stdDeviation=4, result="blur")
            f.feOffset(in_="blur", dx=0, dy=2, result="offsetBlur")
            f.feMerge(["offsetBlur", "SourceGraphic"])
            dwg._shadow_registered = True

        group.add(svgwrite.shapes.Rect(
            insert=(x, y), size=(width, height), rx=8, ry=8,
            fill=theme["card_bg"], filter=f"url(#{filter_id})"
        ))

        # Tinted background for in_progress
        if status == "in_progress":
            group.add(svgwrite.shapes.Rect(
                insert=(x + 5, y), size=(width - 5, height), rx=6, ry=6,
                fill=accent, opacity=0.03
            ))

        # Accent bar
        group.add(svgwrite.shapes.Rect(
            insert=(x, y), size=(5, height), rx=2.5, ry=2.5, fill=accent
        ))

        # Status label
        label_fill = theme["primary_medium"] if status == "in_progress" else theme["text_muted"]
        add_text(group, x + 20, y + 26, status_label,
                 font_size=10.5, fill=label_fill, font_weight="600",
                 letter_spacing=0.5, font_family=theme["font_family"])

        # Title
        add_text(group, x + 20, y + 48, title,
                 font_size=14, fill=theme["text_heading"], font_weight="600",
                 font_family=theme["font_family"])

        # Divider
        group.add(svgwrite.shapes.Line(
            start=(x + 20, y + 60), end=(x + width - 20, y + 60),
            stroke=theme["divider"], stroke_width=1
        ))

        # Items
        item_y = y + 60
        for item in items:
            item_y += 22
            item_status = item.get("status", "upcoming")
            text = item.get("text", "")
            link = item.get("link")
            tooltip = item.get("tooltip")
            badge = item.get("badge")
            children = item.get("children", [])
            bold = item.get("bold", False)

            cx = x + 30
            cy = item_y

            # Draw indicator
            if item_status == "complete":
                add_checkmark(group, cx, cy, r=6.5, fill=theme["primary_medium"])
                text_fill = theme["text_complete"]
            elif item_status == "in_review":
                add_open_checkmark(group, cx, cy, r=6.5,
                                   stroke=theme["primary_medium"], stroke_width=1.5)
                text_fill = theme["text_complete"]
            elif item_status == "in_progress":
                add_empty_circle(group, cx, cy, r=6.5,
                                 stroke=theme["primary_light"], stroke_width=1.5)
                text_fill = theme["text_body"]
            elif item_status == "withdrawn":
                add_withdrawn_x(group, cx, cy, r=6.5,
                                stroke=theme["withdrawn_stroke"], stroke_width=1.5)
                text_fill = theme["text_withdrawn"]
            else:
                add_empty_circle(group, cx, cy, r=6.5,
                                 stroke=theme["upcoming_stroke"], stroke_width=1.5)
                text_fill = theme["text_body"]

            # Text (with optional link)
            tx = x + 44
            fw = "600" if bold else "normal"
            fs = 12 if not children else 12
            text_decoration = "line-through" if item_status == "withdrawn" else "none"

            if link:
                a = group.add(svgwrite.container.Hyperlink(href=link, target="_blank"))
                if tooltip:
                    a.add(svgwrite.base.Title(tooltip))
                t = add_text(a, tx, cy + 4, text,
                             font_size=11.5, fill=text_fill, font_weight=fw,
                             font_family=theme["font_family"])
                if text_decoration != "none":
                    t.attribs["text-decoration"] = text_decoration
            else:
                t = add_text(group, tx, cy + 4, text,
                             font_size=fs, fill=text_fill, font_weight=fw,
                             font_family=theme["font_family"])
                if text_decoration != "none":
                    t.attribs["text-decoration"] = text_decoration

            # Reason (shown below withdrawn items)
            reason = item.get("reason")
            if reason:
                item_y += 14
                add_text(group, tx, item_y + 4, f"↳ {reason}",
                         font_size=10, fill=theme["text_secondary"],
                         font_family=theme["font_family"])

            # Badge
            if badge:
                badge_w = max(50, len(badge["text"]) * 7 + 16)
                badge_x = x + width - badge_w - 15
                add_badge(group, badge_x, cy - 8, badge["text"], badge.get("style", "review"), theme)

            # Children (sub-items with tree connectors)
            children = normalize_children(children)
            if children:
                tree_x = x + 38
                child_start_y = item_y + 8
                child_end_y = item_y + 8 + 18 * len(children)

                # Vertical line
                group.add(svgwrite.shapes.Line(
                    start=(tree_x, child_start_y), end=(tree_x, child_end_y),
                    stroke=theme["primary_medium"], stroke_width=1, opacity=0.25
                ))

                for ci, child in enumerate(children):
                    child_y = child_start_y + 18 * (ci + 1) - 8
                    item_y += 18

                    # Horizontal tick
                    group.add(svgwrite.shapes.Line(
                        start=(tree_x, child_y), end=(tree_x + 5, child_y),
                        stroke=theme["primary_medium"], stroke_width=1, opacity=0.25
                    ))

                    # Child circle + text
                    child_cx = tree_x + 10
                    child_status = child.get("status", "complete")
                    child_text = child.get("text", "")

                    if child_status == "complete":
                        group.add(svgwrite.shapes.Circle(
                            center=(child_cx, child_y), r=5, fill=theme["primary_medium"]
                        ))
                        # Small checkmark
                        group.add(svgwrite.path.Path(
                            d=f"M {child_cx-3} {child_y} L {child_cx-1} {child_y+2} L {child_cx+3} {child_y-2.5}",
                            stroke="#FFF", stroke_width=1.4, fill="none",
                            stroke_linecap="round", stroke_linejoin="round"
                        ))
                        child_fill = theme["text_complete"]
                    elif child_status == "in_review":
                        add_open_checkmark(group, child_cx, child_y, r=5,
                                           stroke=theme["primary_medium"], stroke_width=1.5)
                        child_fill = theme["text_complete"]
                    elif child_status == "withdrawn":
                        add_withdrawn_x(group, child_cx, child_y, r=5,
                                        stroke=theme["withdrawn_stroke"], stroke_width=1.5)
                        child_fill = theme["text_withdrawn"]
                    else:
                        add_empty_circle(group, child_cx, child_y, r=5,
                                         stroke=theme["upcoming_stroke"], stroke_width=1.5)
                        child_fill = theme["text_body"]

                    t = add_text(group, tree_x + 20, child_y + 4, child_text,
                                 font_size=11, fill=child_fill,
                                 font_family=theme["font_family"])
                    if child_status == "withdrawn":
                        t.attribs["text-decoration"] = "line-through"

        # Footer
        footer_y = item_y + 30
        for fi, line in enumerate(footer):
            add_text(group, x + 20, footer_y + fi * 14, line,
                     font_size=10, fill=theme["text_secondary"],
                     font_family=theme["font_family"])

        return height


class InfoBox(Entity):
    def _calc_height(self, theme):
        items = self.data.get("items", [])
        footer = self.data.get("footer", [])
        h = 40  # title + divider
        h += 20 * len(items)
        h += 14 * len(footer)
        h += 15  # padding
        return h

    def estimate_height(self, width, theme):
        return self._calc_height(theme)

    def render(self, dwg, group, x, y, width, theme):
        data = self.data
        title = data.get("title", "KEY REQUIREMENTS")
        items = data.get("items", [])
        footer = data.get("footer", [])
        height = getattr(self, '_override_height', None) or self._calc_height(theme)
        accent = theme["primary_dark"]

        # Shadow filter (reuses same filter registered by Card)
        filter_id = "shadow_gen"

        # Background
        group.add(svgwrite.shapes.Rect(
            insert=(x, y), size=(width, height), rx=8, ry=8,
            fill=theme["card_bg"], filter=f"url(#{filter_id})"
        ))
        # Tinted overlay
        group.add(svgwrite.shapes.Rect(
            insert=(x, y), size=(width - 2, height), rx=8, ry=8,
            fill=accent, opacity=0.03
        ))
        # Accent bar
        group.add(svgwrite.shapes.Rect(
            insert=(x, y), size=(5, height), rx=2.5, ry=2.5, fill=accent
        ))

        # Title
        add_text(group, x + 20, y + 28, title,
                 font_size=11, fill=accent, font_weight="600",
                 letter_spacing=0.5, font_family=theme["font_family"])

        # Divider
        group.add(svgwrite.shapes.Line(
            start=(x + 20, y + 40), end=(x + width - 20, y + 40),
            stroke=theme["divider"], stroke_width=1
        ))

        # Items
        for i, item in enumerate(items):
            add_text(group, x + 20, y + 60 + i * 20, f"• {item}",
                     font_size=11.5, fill=theme["text_dark"],
                     font_family=theme["font_family"])

        # Footer
        footer_start = y + 60 + len(items) * 20
        for i, line in enumerate(footer):
            add_text(group, x + 20, footer_start + i * 14, line,
                     font_size=10, fill=theme["text_secondary"],
                     font_family=theme["font_family"])

        return height


class Legend(Entity):
    def estimate_height(self, width, theme):
        return 20

    def render(self, dwg, group, x, y, width, theme):
        items = self.data.get("items", [])
        default_gap = self.data.get("gap", 14)
        arrow_gap = self.data.get("arrow_gap", 6)
        cx = x
        cy = y + 6

        for i, item in enumerate(items):
            item_type = item.get("type", "circle")
            label = item.get("label", "")
            style = item.get("style", "upcoming")
            next_item = items[i + 1] if i + 1 < len(items) else None
            next_item_type = next_item.get("type") if isinstance(next_item, dict) else None
            item_width = 0

            if item_type == "circle":
                if style == "complete":
                    group.add(svgwrite.shapes.Circle(center=(cx + 8, cy), r=6, fill=theme["primary_medium"]))
                elif style == "in_progress":
                    group.add(svgwrite.shapes.Circle(
                        center=(cx + 8, cy), r=6, fill="#FFFFFF",
                        stroke=theme["primary_light"], stroke_width=2
                    ))
                else:
                    group.add(svgwrite.shapes.Circle(
                        center=(cx + 8, cy), r=6, fill=theme["upcoming_fill"],
                        stroke=theme["upcoming_stroke"], stroke_width=1.5
                    ))
                add_text(group, cx + 22, cy + 4, label,
                         font_size=11, fill=theme["text_muted"],
                         font_family=theme["font_family"])
                label_width = estimate_legend_text_width(label)
                content_width = 22 + label_width
                gap_after = arrow_gap if next_item_type == "arrow" else default_gap
                item_width = content_width + gap_after

            elif item_type == "badge":
                badge_style = item.get("badge_style", "review")
                badge_width = max(50, len(label) * 7 + 16)
                add_badge(group, cx, cy - 7, label, badge_style, theme)
                gap_after = arrow_gap if next_item_type == "arrow" else default_gap
                item_width = badge_width + gap_after

            elif item_type == "arrow":
                direction = item.get("direction", "right")
                arrow_length = max(8, float(item.get("length", 16)))
                arrow_color = item.get("color", theme["text_secondary"])
                add_legend_arrow(
                    group,
                    x=cx + arrow_length / 2,
                    y=cy,
                    direction=direction,
                    length=arrow_length,
                    stroke=arrow_color,
                )
                gap_after = arrow_gap if next_item_type else 0
                item_width = arrow_length + gap_after

            if item_width > 0:
                cx += item_width

        return 20


# ═══════════════════════════════════════════════════════════════════════════════
# Layout Containers
# ═══════════════════════════════════════════════════════════════════════════════


class HorizontalLayout(Entity):
    def estimate_height(self, width, theme):
        children = [entity_factory(c) for c in self.data.get("children", [])]
        gap = self.data.get("gap", 20)
        weights = self.data.get("weights")
        n = len(children)
        if n == 0:
            return 0

        available = width - gap * (n - 1)
        if weights:
            total_w = sum(weights)
            widths = [available * w / total_w for w in weights]
        else:
            widths = [available / n] * n

        return max(c.estimate_height(w, theme) for c, w in zip(children, widths))

    def render(self, dwg, group, x, y, width, theme):
        children_data = self.data.get("children", [])
        gap = self.data.get("gap", 20)
        weights = self.data.get("weights")
        n = len(children_data)
        if n == 0:
            return 0

        available = width - gap * (n - 1)
        if weights:
            total_w = sum(weights)
            widths = [available * w / total_w for w in weights]
        else:
            widths = [available / n] * n

        max_h = 0
        cx = x
        for i, child_data in enumerate(children_data):
            entity = entity_factory(child_data)
            h = entity.render(dwg, group, cx, y, widths[i], theme)
            max_h = max(max_h, h)
            cx += widths[i] + gap

        return max_h


class ColumnsLayout(Entity):
    def estimate_height(self, width, theme):
        columns = self.data.get("children", [])
        gap = self.data.get("gap", 20)
        col_gap = self.data.get("col_gap", 10)
        weights = self.data.get("weights")
        n = len(columns)
        if n == 0:
            return 0

        available = width - gap * (n - 1)
        if weights:
            total_w = sum(weights)
            widths = [available * w / total_w for w in weights]
        else:
            widths = [available / n] * n

        max_col_h = 0
        for col_idx, col_entities in enumerate(columns):
            col_h = 0
            for entity_data in col_entities:
                entity = entity_factory(entity_data)
                col_h += entity.estimate_height(widths[col_idx], theme) + col_gap
            max_col_h = max(max_col_h, col_h)

        return max_col_h

    def render(self, dwg, group, x, y, width, theme):
        columns = self.data.get("children", [])
        gap = self.data.get("gap", 20)
        col_gap = self.data.get("col_gap", 10)
        weights = self.data.get("weights")
        equal_height = self.data.get("equal_height", False)
        n = len(columns)
        if n == 0:
            return 0

        available = width - gap * (n - 1)
        if weights:
            total_w = sum(weights)
            widths = [available * w / total_w for w in weights]
        else:
            widths = [available / n] * n

        # Pre-compute row heights when equal_height is enabled
        row_heights = None
        if equal_height:
            max_rows = max(len(col) for col in columns)
            row_heights = [0] * max_rows
            for col_idx, col_entities in enumerate(columns):
                for row_idx, entity_data in enumerate(col_entities):
                    entity = entity_factory(entity_data)
                    h = entity.estimate_height(widths[col_idx], theme)
                    row_heights[row_idx] = max(row_heights[row_idx], h)

        max_col_h = 0
        col_x = x
        for col_idx, col_entities in enumerate(columns):
            col_y = y
            for row_idx, entity_data in enumerate(col_entities):
                entity = entity_factory(entity_data)
                if row_heights and row_idx < len(row_heights):
                    entity._override_height = row_heights[row_idx]
                h = entity.render(dwg, group, col_x, col_y, widths[col_idx], theme)
                col_y += h + col_gap
            max_col_h = max(max_col_h, col_y - y)
            col_x += widths[col_idx] + gap

        return max_col_h


# ═══════════════════════════════════════════════════════════════════════════════
# Factory
# ═══════════════════════════════════════════════════════════════════════════════

ENTITY_MAP = {
    "header": Header,
    "progress_bar": ProgressBar,
    "timeline": Timeline,
    "card": Card,
    "info_box": InfoBox,
    "legend": Legend,
    "spacer": Spacer,
    "horizontal": HorizontalLayout,
    "columns": ColumnsLayout,
}


def entity_factory(data):
    entity_type = data.get("type", "spacer")
    cls = ENTITY_MAP.get(entity_type)
    if not cls:
        raise ValueError(f"Unknown entity type: {entity_type}")
    return cls(data)


# ═══════════════════════════════════════════════════════════════════════════════
# Renderer
# ═══════════════════════════════════════════════════════════════════════════════


def render_roadmap(data, output_path):
    """Render a roadmap from JSON data to SVG file."""
    size = data.get("size", {})
    width = size.get("width", 1100)
    padding = data.get("padding", {"top": 0, "left": 20, "right": 20, "bottom": 25})
    theme_name = data.get("theme", "siemens")
    theme_overrides = data.get("theme_overrides", {})
    theme = get_theme(theme_name, theme_overrides)

    layout = data.get("layout", [])

    # First pass: estimate height
    content_width = width - padding.get("left", 0) - padding.get("right", 0)
    total_height = padding.get("top", 0)
    entity_gap = data.get("entity_gap", 5)

    for entity_data in layout:
        entity = entity_factory(entity_data)
        # Header spans full width
        if entity_data.get("type") == "header":
            total_height += entity.estimate_height(width, theme) + entity_gap
        else:
            total_height += entity.estimate_height(content_width, theme) + entity_gap

    total_height += padding.get("bottom", 0)
    total_height -= 4 * entity_gap  # Remove gap after last entity
    min_height = size.get("height", 0)
    total_height = max(total_height, min_height)

    # Create SVG
    dwg = Drawing(
        str(output_path),
        size=(f"{width}px", f"{total_height}px"),
        viewBox=f"0 0 {width} {total_height}",
    )
    dwg.attribs["font-family"] = theme["font_family"]

    # Background
    root = dwg.add(Group())
    root.add(svgwrite.shapes.Rect(
        insert=(0, 0), size=(width, total_height), rx=6, ry=6,
        fill=theme["background"]
    ))
    root.add(svgwrite.shapes.Rect(
        insert=(0.5, 0.5), size=(width - 1, total_height - 1), rx=6, ry=6,
        fill="none", stroke=theme["border"], stroke_width=1
    ))

    # Render entities
    y = padding.get("top", 0)
    left = padding.get("left", 0)

    for entity_data in layout:
        entity = entity_factory(entity_data)
        if entity_data.get("type") == "header":
            h = entity.render(dwg, root, 0, y, width, theme)
        else:
            h = entity.render(dwg, root, left, y, content_width, theme)
        y += h + entity_gap

    dwg.save(pretty=True)
    return output_path


# ═══════════════════════════════════════════════════════════════════════════════
# Template Generation
# ═══════════════════════════════════════════════════════════════════════════════


def generate_template():
    """Generate a template JSON matching the current roadmap."""
    return {
        "size": {"width": 1100},
        "theme": "siemens",
        "theme_overrides": {},
        "padding": {"top": 0, "left": 20, "right": 20, "bottom": 25},
        "entity_gap": 5,
        "layout": [
            {
                "type": "header",
                "title": "Project Roadmap"
            },
            {
                "type": "horizontal",
                "gap": 30,
                "children": [
                    {
                        "type": "progress_bar",
                        "label": "Phase A Progress",
                        "completed": 2,
                        "total": 3
                    },
                    {
                        "type": "progress_bar",
                        "label": "Phase B Progress",
                        "completed": 0,
                        "total": 4
                    }
                ]
            },
            {
                "type": "spacer",
                "height": 5
            },
            {
                "type": "timeline",
                "phases": [
                    {"number": "0", "group": "A", "label": ["Setup"], "status": "complete"},
                    {"number": "1", "group": "A", "label": ["Build"], "status": "complete"},
                    {"number": "2", "group": "A", "label": ["Deploy"], "status": "in_progress"},
                    {"number": "3", "group": "B", "label": ["Test"], "status": "upcoming"},
                    {"number": "4", "group": "B", "label": ["Release"], "status": "upcoming"},
                    {"number": "5", "group": "B", "label": ["Monitor"], "status": "upcoming"},
                    {"number": "6", "group": "B", "label": ["Unify"], "status": "upcoming"}
                ]
            },
            {
                "type": "spacer",
                "height": 5
            },
            {
                "type": "columns",
                "gap": 20,
                "col_gap": 10,
                "weights": [300, 360, 340],
                "children": [
                    [
                        {
                            "type": "card",
                            "status": "complete",
                            "status_label": "PHASE 0 — COMPLETE",
                            "title": "Setup (Baseline)",
                            "items": [
                                {"text": "Initial setup complete", "status": "complete"},
                                {"text": "Tests passing", "status": "complete"}
                            ],
                            "footer": ["Completed Q1 2026"]
                        },
                        {
                            "type": "info_box",
                            "title": "KEY REQUIREMENTS",
                            "items": [
                                "Requirement one",
                                "Requirement two",
                                "Requirement three"
                            ],
                            "footer": ["Trajectory: Phase A → Phase B → Done"]
                        }
                    ],
                    [
                        {
                            "type": "card",
                            "status": "complete",
                            "status_label": "PHASE 1 — COMPLETE",
                            "title": "Build System",
                            "items": [
                                {
                                    "text": "Build script",
                                    "status": "complete",
                                    "bold": True,
                                    "children": [
                                        {"text": "Sub-task A", "status": "complete"},
                                        {"text": "Sub-task B", "status": "complete"}
                                    ]
                                }
                            ],
                            "footer": ["QA approved"]
                        },
                        {
                            "type": "card",
                            "status": "in_progress",
                            "status_label": "PHASE 2 — IN PROGRESS",
                            "title": "Dependencies",
                            "items": [
                                {
                                    "text": "Package migration",
                                    "status": "in_progress",
                                    "link": "https://example.com/ticket-1",
                                    "tooltip": "TICKET-1: Migrate packages",
                                    "badge": {"text": "Review", "style": "review"}
                                }
                            ],
                            "footer": ["In review"]
                        }
                    ],
                    [
                        {
                            "type": "card",
                            "status": "upcoming",
                            "status_label": "PHASE 4 — UPCOMING",
                            "title": "Automation",
                            "items": [
                                {"text": "Nightly builds", "status": "upcoming"},
                                {"text": "Validation", "status": "upcoming"}
                            ],
                            "footer": []
                        }
                    ]
                ]
            },
            {
                "type": "legend",
                "items": [
                    {"type": "circle", "style": "complete", "label": "Complete"},
                    {"type": "circle", "style": "in_progress", "label": "In Progress"},
                    {"type": "circle", "style": "upcoming", "label": "Upcoming"},
                    {"type": "badge", "badge_style": "closed", "label": "Closed"},
                    {"type": "badge", "badge_style": "review", "label": "Review"},
                    {"type": "badge", "badge_style": "opened", "label": "Opened"}
                ]
            }
        ]
    }


# ═══════════════════════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════════════════════


def main():
    parser = argparse.ArgumentParser(
        description="Generate SVG roadmaps from JSON layout definitions."
    )
    parser.add_argument("input", nargs="?", help="Input JSON file")
    parser.add_argument("-o", "--output", default="roadmap.svg", help="Output SVG path")
    parser.add_argument("--template", action="store_true",
                        help="Output a template JSON to stdout")

    args = parser.parse_args()

    if args.template:
        json.dump(generate_template(), sys.stdout, indent=2)
        sys.stdout.write("\n")
        return

    if not args.input:
        parser.error("Input JSON file is required (or use --template)")

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: {input_path} not found", file=sys.stderr)
        sys.exit(1)

    with open(input_path) as f:
        data = json.load(f)

    output_path = Path(args.output)
    render_roadmap(data, output_path)
    print(f"Generated: {output_path}")


if __name__ == "__main__":
    main()
