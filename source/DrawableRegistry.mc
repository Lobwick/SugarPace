import Toybox.Lang;
import Toybox.WatchUi;

//! Single source of truth for food picture → drawable mapping.
//! When adding a new food:
//!   1. Add PNG to resources/drawables/brands/  (84×84, black background)
//!   2. Declare it in resources/drawables/drawables.xml
//!   3. Add one entry in the dictionary below
//! SugarPaceView never needs to be modified.
class DrawableRegistry {

    private static var _map as Lang.Dictionary? = null;

    static function get(pictureId as Lang.String) as Lang.ResourceId? {
        if (_map == null) {
            _map = {
                "gel_decathlon_energygelplus_redfruit"      => Rez.Drawables.gel_decathlon_energygelplus_redfruit,
                "gel_decathlon_energygel_redfruit_minus3h"  => Rez.Drawables.gel_decathlon_energygel_redfruit_minus3h,
                "gel_decathlon_108_cola"                    => Rez.Drawables.gel_decathlon_108_cola,
                "jelly_red_fruit"                           => Rez.Drawables.jelly_red_fruit,
                "bar_energy_dates_nuts"                     => Rez.Drawables.bar_energy_dates_nuts,
                "gel_maurten_160"                           => Rez.Drawables.gel_maurten_160,
                "226ers_isotonic_gel_68g"                   => Rez.Drawables.226ers_isotonic_gel_68g,
            } as Lang.Dictionary;
        }
        return (_map as Lang.Dictionary).get(pictureId) as Lang.ResourceId?;
    }
}
