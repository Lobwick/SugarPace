//! Centralized layout constants and screen proportions for the main view.
//! Fixed pixel values live here (named, not scattered as magic numbers) and
//! screen-relative values are expressed as fractions of the device size, so the
//! UI scales across every Edge screen (246x322 up to 480x800).
module Layout {

    // CGM readings arrive roughly every 5 minutes; maps a time window (minutes)
    // to a number of history points to show.
    const MIN_PER_POINT = 5;

    // How often the main view re-fetches glucose + profile (ms). 5 minutes,
    // matching the CGM cadence.
    const REFRESH_INTERVAL_MS = 300000;

    // --- Glucose card (header) ---
    const CARD_TOP = 6;             // top inset of the card
    const CARD_MARGIN = 8;          // left/right inset for header content
    const HEADER_CHART_GAP = 12;    // gap between the big number and the chart
    const CARD_BOTTOM_PAD = 8;      // gap below the axis labels
    const VALUE_UNIT_GAP = 8;       // gap between number, unit and arrow
    const UNIT_BASELINE_LIFT = 6;   // raise the unit slightly off the number baseline
    const CARD_GRID_GAP = 16;       // gap between the card and the food grid
    const NODATA_TEXT_OFFSET = 20;  // "check config" text offset below the chart top

    // The trend chart takes this fraction of the screen height (keeps it
    // proportionate instead of a fixed pixel height that overflows small screens).
    const CHART_HEIGHT_PCT = 0.18;
    // On short screens (Edge 540/840, 322px tall) the header is squeezed: use a
    // smaller number font and a shorter chart so the food grid gets more room.
    const COMPACT_HEIGHT_THRESHOLD = 400;
    const CHART_HEIGHT_PCT_COMPACT = 0.15;

    // --- Trend chart internals ---
    const CHART_BAR_GAP = 3;             // px between bars (0 for a single bar)
    const CHART_AXIS_GAP = 4;            // gap between the bars and the axis labels
    const CHART_MIN_RANGE = 50;          // min mg/dl span so a flat line isn't amplified
    const CHART_TOP_HEADROOM_PCT = 0.12; // headroom above the peak
    const CHART_BOTTOM_PAD_PCT = 0.25;   // padding below the trough
    const CHART_BAR_MIN_H = 2;           // never draw a zero-height bar

    // --- Active-profile chip (dot + name) ---
    const PROFILE_DOT_RADIUS = 4;
    const PROFILE_DOT_GAP = 7;      // gap between the dot and the profile name
    const PROFILE_SIDE_GAP = 10;    // min free space on each side of the chip

    // --- Food grid ---
    const GRID_MARGIN = 12;
    const GRID_GAP = 10;
    const GRID_COLUMNS = 2;
    const GRID_CELL_HEIGHT = 150;     // preferred cell height (large screens)
    const GRID_CELL_MIN_HEIGHT = 124; // floor so an ~84px image + name still fits
    const GRID_NAME_BAND = 30;        // reserved height at the cell bottom for the name
    const GRID_IMAGE_TOP_PAD = 8;   // gap above the image inside the cell
    const GRID_NAME_LIFT = 24;      // name baseline, measured up from the cell bottom
    const GRID_EMPTY_TITLE_OFFSET = 20;
    const GRID_EMPTY_SUBTITLE_OFFSET = 50;

    // --- Scrolling ---
    const SCROLL_STEP = 150;        // px moved per swipe / key press
}
