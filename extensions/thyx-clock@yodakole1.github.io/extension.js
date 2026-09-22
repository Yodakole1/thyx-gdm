// Thyx: the greeter's display clock.
//
// GDM gives the login screen exactly one clock -- the date menu in the top bar
// -- and no way to put anything beside the sign-in form. With FormPosition set
// to left or right, the other half of the screen is empty. This fills it.
//
// What this file does NOT do is decide how the clock looks. That lives in the
// theme's gdm.css, generated from theme.conf like everything else, for a
// reason worth writing down: Yaru's greeter sheet ends with
//
//     * { font-weight: normal !important; }
//
// and an author !important declaration outranks inline style, so a weight set
// from here with set_style() would be thrown away. The stylesheet can beat it
// with a class selector and its own !important; this file cannot. So the
// extension owns behaviour and placement, the stylesheet owns appearance, and
// the two meet at the style classes below.
//
// Loaded only in greeter mode: metadata.json declares session-modes ["gdm"],
// and scripts/install lists the uuid in enabled-extensions inside GDM's own
// dconf profile, so it never touches a logged-in session.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// Mirrors the defaults in theme.conf. They only come into play if config.json
// is missing or unreadable, which should not happen through scripts/install --
// but a greeter that throws on startup is a machine you cannot log into, so
// every path here has to end somewhere sane.
const DEFAULTS = {
    position: 'right',
    offset: 480,
    hourFormat: '24h',
    seconds: false,
    showDate: true,
    dateFormat: '%A, %-e %B',
};

export default class ThyxClockExtension extends Extension {
    enable() {
        this._config = this._loadConfig();
        this._timeoutId = 0;
        this._monitorsId = 0;

        this._box = new St.BoxLayout({
            style_class: 'thyx-clock',
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: false,
            y_expand: false,
            reactive: false,
        });

        this._time = new St.Label({
            style_class: 'thyx-clock-time',
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._box.add_child(this._time);

        if (this._config.showDate) {
            this._date = new St.Label({
                style_class: 'thyx-clock-date',
                x_align: Clutter.ActorAlign.CENTER,
            });
            this._box.add_child(this._date);
        }

        // screenShieldGroup is public, spans every monitor, and lays its
        // children out with a BinLayout. Adding last puts the clock above the
        // login dialog; the top bar and the session menus are separate chrome
        // added after the shield, so they still draw over it.
        Main.layoutManager.screenShieldGroup.add_child(this._box);

        this._monitorsId = Main.layoutManager.connect('monitors-changed',
            () => this._reposition());

        this._reposition();
        this._update();
        this._scheduleTick();
    }

    disable() {
        if (this._timeoutId) {
            GLib.source_remove(this._timeoutId);
            this._timeoutId = 0;
        }

        if (this._monitorsId) {
            Main.layoutManager.disconnect(this._monitorsId);
            this._monitorsId = 0;
        }

        this._box?.destroy();
        this._box = null;
        this._time = null;
        this._date = null;
        this._config = null;
    }

    // scripts/build renders this next to the extension from theme.conf, so the
    // clock and the stylesheet are always describing the same settings.
    _loadConfig() {
        const config = {...DEFAULTS};
        const path = GLib.build_filenamev([this.path, 'config.json']);

        let parsed;
        try {
            const [ok, bytes] = Gio.File.new_for_path(path).load_contents(null);
            if (!ok)
                return config;
            parsed = JSON.parse(new TextDecoder().decode(bytes));
        } catch (e) {
            console.warn(`thyx-clock: using defaults, could not read ${path}: ${e}`);
            return config;
        }

        // Taken key by key and coerced, rather than merged wholesale: a
        // hand-edited config should not be able to put a string where the
        // placement arithmetic expects a number.
        if (['left', 'right', 'center'].includes(parsed.position))
            config.position = parsed.position;

        if (Number.isFinite(parsed.offset))
            config.offset = Math.trunc(parsed.offset);

        if (parsed.hourFormat === '12h' || parsed.hourFormat === '24h')
            config.hourFormat = parsed.hourFormat;

        if (typeof parsed.seconds === 'boolean')
            config.seconds = parsed.seconds;

        if (typeof parsed.showDate === 'boolean')
            config.showDate = parsed.showDate;

        if (typeof parsed.dateFormat === 'string' && parsed.dateFormat !== '')
            config.dateFormat = parsed.dateFormat;

        return config;
    }

    _update() {
        const now = GLib.DateTime.new_now_local();

        let format;
        if (this._config.hourFormat === '12h')
            format = this._config.seconds ? '%-l:%M:%S %p' : '%-l:%M %p';
        else
            format = this._config.seconds ? '%H:%M:%S' : '%H:%M';

        this._time?.set_text(now.format(format));
        this._date?.set_text(now.format(this._config.dateFormat));
    }

    // Wakes on the boundary rather than once a second. A greeter can sit on
    // screen for hours, and without seconds showing there is nothing to draw
    // 59 times out of 60. Re-deriving the delay from the clock each time also
    // means a suspend, a timezone change or an NTP step is corrected on the
    // next tick instead of drifting.
    _scheduleTick() {
        const now = GLib.DateTime.new_now_local();
        const seconds = now.get_seconds();
        const intoSecond = seconds - Math.floor(seconds);

        let delay = this._config.seconds
            ? 1 - intoSecond
            : 60 - seconds;

        // Never schedule zero, or a fast loop takes the greeter with it.
        delay = Math.max(Math.round(delay * 1000), 50);

        this._timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, delay, () => {
            this._timeoutId = 0;
            this._update();
            this._scheduleTick();
            return GLib.SOURCE_REMOVE;
        });
    }

    // Placement, and why it is a translation rather than a margin.
    //
    // The shield group spans every monitor and lays its children out with a
    // BinLayout, so a CENTER-aligned child lands in the middle of the whole
    // desk -- on two monitors, in the gap between them. Margins look like the
    // way to move it and are not: St re-applies an StWidget's margins from its
    // CSS theme node on every style change, so anything set here is quietly
    // reset to the stylesheet's 0. (Measured, not assumed: the margins read
    // back as zero while the allocation stayed dead centre.)
    //
    // translation_x/y is a paint-time transform that St never touches. The box
    // is still centred on the stage, so translating by the distance from the
    // stage centre to the wanted centre puts it exactly where it belongs, and
    // costs no relayout -- which is also why nothing here has to run again
    // when the clock's own text changes width.
    _reposition() {
        if (!this._box)
            return;

        const monitor = Main.layoutManager.primaryMonitor;
        if (!monitor)
            return;

        const sign = {left: -1, right: 1, center: 0}[this._config.position] ?? 1;

        const centerX = monitor.x + monitor.width / 2 + sign * this._config.offset;
        const centerY = monitor.y + monitor.height / 2;

        this._box.translation_x = Math.round(centerX - global.stage.width / 2);
        this._box.translation_y = Math.round(centerY - global.stage.height / 2);
    }
}
