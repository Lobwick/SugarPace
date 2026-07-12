module Constants {
    const TIME_STEP_SEC = 30;
    const DEFAULT_OVERRIDE_PROFIL = "Default";

    // Glucose zone thresholds (mg/dl) used to color-code the trend badge
    // and history chart bars: green when inside target range, orange when
    // slightly out of range, red when far out of range.
    const GLUCOSE_TARGET_LOW = 70;
    const GLUCOSE_TARGET_HIGH = 180;
    const GLUCOSE_NEAR_LOW = 55;
    const GLUCOSE_NEAR_HIGH = 250;
    //TODO les déplacer dans les properties de l'application
}