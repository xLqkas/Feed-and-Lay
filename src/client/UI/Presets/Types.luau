--!strict
-- Shape shared by every UI style preset (docs/ai/ui-presets/*.md). Data only.
-- Same fields as Theme.luau (Colors, Rarity, RarityOrder, Buttons, Fonts, TextSize, Space, Radius, Stroke,
-- ButtonDepth) plus Gradients, Layout and a Motion table of named tween presets.
-- Sizes are reference pixels at 1080 px screen height; Layout values are fractions of screen height (H)
-- or width (W) as measured in the studies.

export type ButtonColors = { face: Color3, base: Color3, text: Color3, stroke: Color3 }

-- A vertical (Rotation 90) or horizontal (Rotation 0) two- or three-stop colour gradient.
export type Gradient = { stops: { Color3 }, rotation: number }

-- Values a tween animates. Offsets are fractions of screen height; Rotation in degrees.
-- Scale is a UIScale value; Transparency is GroupTransparency or the element's own transparency.
export type MotionProps = {
    Scale: number?,
    OffsetX: number?,
    OffsetY: number?,
    Rotation: number?,
    Transparency: number?,
}

export type Tween = {
    Time: number, -- seconds
    EasingStyle: Enum.EasingStyle,
    EasingDirection: Enum.EasingDirection,
    Delay: number, -- seconds before start
    From: MotionProps,
    To: MotionProps,
    Overshoot: number?, -- observed peak past To, as a fraction (0.03 = 3 %), when the style adds one
    Stagger: number?, -- seconds between sibling elements
    Loop: boolean?, -- repeats forever (RepeatCount -1, Reverses true unless noted)
    Estimate: boolean, -- true when not measured frame by frame
}

export type Preset = {
    Colors: { [string]: Color3 },
    Rarity: { [string]: Color3 },
    RarityOrder: { string },
    Buttons: { [string]: ButtonColors },
    Gradients: { [string]: Gradient },
    Fonts: { title: Font, body: Font },
    TextSize: { [string]: number },
    Space: { [string]: number },
    Radius: { [string]: number },
    Stroke: { [string]: number },
    ButtonDepth: number,
    Layout: { [string]: number },
    Motion: { [string]: Tween },
}

return {}
